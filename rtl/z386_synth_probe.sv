// CPU-only z386 integration probe for the ULX3S 85F.
//
// This is deliberately not a PC system yet. It instantiates the complete z386
// CPU with 1 KiB instruction/data caches and a small synthetic bus target.
//
// FIRE1 (btn[1]) is a dedicated active-high CPU reset. Hold FIRE1 while loading
// the bitstream, then release it. Reset asserts asynchronously and deasserts
// synchronously after 16 clocks, so CPU startup does not depend on FPGA register
// initialization or the ULX3S power button.
//
// Before the CPU performs its first output, the LEDs display sticky bring-up
// status and an FPGA heartbeat. The reset-vector program immediately writes
// 0xFF to port 0x0080, then jumps to a larger ROM loop that alternates 0x55 and
// 0xAA slowly enough to see.

module z386_synth_probe #(
    parameter integer DCACHE_SET_BITS = 4,
    parameter integer ICACHE_SET_BITS = 4
) (
    input  logic       clk_25mhz,
    input  logic [6:0] btn,
    output logic [7:0] led,
    output wire        wifi_gpio0
);

localparam logic [15:0] LED_IO_PORT = 16'h0080;

// FIRE1 is a normal active-high user button with an LPF pull-down. Unlike
// BTN_PWRn, it does not invoke the board power-control function.
logic [15:0] reset_pipe = '1;
always_ff @(posedge clk_25mhz or posedge btn[1]) begin
    if (btn[1])
        reset_pipe <= '1;
    else
        reset_pipe <= {reset_pipe[14:0], 1'b0};
end

wire cpu_reset_n = ~|reset_pipe;

wire [31:2] cpu_addr;
wire  [3:0] cpu_be;
wire  [7:0] cpu_burstcount;
logic [31:0] cpu_din = 32'h9090_9090;
wire [31:0] cpu_dout;
wire        cpu_valid;
logic       cpu_ready = 1'b0;
wire        cpu_write;
wire        cpu_io;
logic       cpu_resp_valid = 1'b0;
wire        cpu_inta;
wire [15:0] dbg_cs;
wire [31:0] dbg_eip;
wire [31:0] dbg_cs_base;
wire        dbg_pe;
wire        dbg_vm;
wire        triple_fault_reset;

logic        read_active = 1'b0;
logic [31:0] read_address = 32'd0;
logic  [7:0] read_remaining = 8'd0;
logic  [7:0] led_output = 8'h00;

// These signals remain visible only until the first successful port-0x80 write.
logic [24:0] heartbeat;
logic        request_seen = 1'b0;
logic        response_seen = 1'b0;
logic        reset_vector_seen = 1'b0;
logic        demo_rom_seen = 1'b0;
logic        io_write_seen = 1'b0;
logic        triple_fault_seen = 1'b0;

always_ff @(posedge clk_25mhz)
    heartbeat <= heartbeat + 25'd1;

wire [31:0] cpu_byte_address = {cpu_addr, 2'b00};
wire [15:0] cpu_io_port = cpu_byte_address[15:0];
wire  [7:0] cpu_read_length = cpu_io ? 8'd1 :
                               ((cpu_burstcount == 0) ? 8'd1 :
                                                            cpu_burstcount);

// Reset-vector code at physical FFFFFFF0:
//
//     mov al, 0xff
//     out 0x80, al
//     jmp 0xf000:0x0000
//
// The immediate all-LED write happens before the far jump. If the CPU starts
// but the second ROM region is not reached, the LEDs remain at 0xFF.
//
// Slow demo code at physical 000F0000:
//
//     cli
//     mov al, 0x55
// blink:
//     out 0x80, al
//     mov dx, 0x0020
// outer:
//     mov cx, 0xffff
// inner:
//     loop inner
//     dec dx
//     jnz outer
//     xor al, 0xff
//     jmp blink
function automatic [31:0] probe_read_data(input logic [31:0] address);
    begin
        case (address)
            // B0 FF E6 80 EA 00 00 00 F0 90 90 90 90 90 90 90
            32'hffff_fff0: probe_read_data = 32'h80e6_ffb0;
            32'hffff_fff4: probe_read_data = 32'h0000_00ea;
            32'hffff_fff8: probe_read_data = 32'h9090_90f0;
            32'hffff_fffc: probe_read_data = 32'h9090_9090;

            // FA B0 55 E6 80 BA 20 00 B9 FF FF E2 FE 4A 75 F8
            // 34 FF EB EF 90 90 90 90
            32'h000f_0000: probe_read_data = 32'he655_b0fa;
            32'h000f_0004: probe_read_data = 32'h0020_ba80;
            32'h000f_0008: probe_read_data = 32'he2ff_ffb9;
            32'h000f_000c: probe_read_data = 32'hf875_4afe;
            32'h000f_0010: probe_read_data = 32'hefeb_ff34;
            32'h000f_0014: probe_read_data = 32'h9090_9090;

            // Unimplemented memory reads return NOP instructions.
            default:       probe_read_data = 32'h9090_9090;
        endcase
    end
endfunction

// Registered ready/valid responder matching the z386 testbench contract:
// ready is high while idle, the first read DWORD is returned when the request
// is accepted, and remaining burst DWORDs follow one per clock cycle.
always_ff @(posedge clk_25mhz) begin
    cpu_resp_valid <= 1'b0;

    if (!cpu_reset_n) begin
        cpu_din           <= 32'h9090_9090;
        cpu_ready         <= 1'b0;
        read_active       <= 1'b0;
        read_address      <= 32'd0;
        read_remaining    <= 8'd0;
        led_output        <= 8'h00;
        request_seen      <= 1'b0;
        response_seen     <= 1'b0;
        reset_vector_seen <= 1'b0;
        demo_rom_seen     <= 1'b0;
        io_write_seen     <= 1'b0;
        triple_fault_seen <= 1'b0;
    end else begin
        cpu_ready <= !read_active;

        if (cpu_resp_valid)
            response_seen <= 1'b1;

        if (triple_fault_reset)
            triple_fault_seen <= 1'b1;

        if (read_active) begin
            cpu_din        <= probe_read_data(read_address);
            cpu_resp_valid <= 1'b1;
            response_seen  <= 1'b1;
            read_address   <= read_address + 32'd4;
            read_remaining <= read_remaining - 8'd1;

            if (read_remaining == 8'd1)
                read_active <= 1'b0;
        end

        if (cpu_valid && cpu_ready && !read_active) begin
            request_seen <= 1'b1;

            if (cpu_write) begin
                if (cpu_io &&
                    (cpu_io_port == LED_IO_PORT) &&
                    cpu_be[0]) begin
                    led_output    <= cpu_dout[7:0];
                    io_write_seen <= 1'b1;
                end
            end else begin
                cpu_din        <= probe_read_data(cpu_byte_address);
                cpu_resp_valid <= 1'b1;
                response_seen  <= 1'b1;

                if (!cpu_io && (cpu_byte_address == 32'hffff_fff0))
                    reset_vector_seen <= 1'b1;

                if (!cpu_io && (cpu_byte_address == 32'h000f_0000))
                    demo_rom_seen <= 1'b1;

                if (cpu_read_length > 8'd1) begin
                    cpu_ready      <= 1'b0;
                    read_active    <= 1'b1;
                    read_address   <= cpu_byte_address + 32'd4;
                    read_remaining <= cpu_read_length - 8'd1;
                end
            end
        end
    end
end

(* keep_hierarchy = "yes" *)
z386 #(
    .PROTECT_UMA_ROM (1),
    .DCACHE_SET_BITS(DCACHE_SET_BITS),
    .ICACHE_SET_BITS(ICACHE_SET_BITS)
) cpu (
    .clk               (clk_25mhz),
    .reset_n           (cpu_reset_n),
    .addr              (cpu_addr),
    .be                (cpu_be),
    .burstcount        (cpu_burstcount),
    .din               (cpu_din),
    .dout              (cpu_dout),
    .valid             (cpu_valid),
    .ready             (cpu_ready),
    .write             (cpu_write),
    .io                (cpu_io),
    .resp_valid        (cpu_resp_valid),
    .intr              (1'b0),
    .nmi               (1'b0),
    .inta              (cpu_inta),
    .snoop_addr        (32'd0),
    .snoop_valid       (1'b0),
    .a20_enable        (1'b1),
    .single_step       (1'b0),
    .dbg_CS            (dbg_cs),
    .dbg_EIP           (dbg_eip),
    .dbg_CS_base       (dbg_cs_base),
    .dbg_pe            (dbg_pe),
    .dbg_vm            (dbg_vm),
    .triple_fault_reset(triple_fault_reset)
);

// Keep the onboard ESP32 from rebooting/reconfiguring the FPGA after JTAG load.
assign wifi_gpio0 = 1'b1;

// Before the first successful CPU output, expose enough state to prevent
// another ambiguous all-dark result:
//   D7 heartbeat, D6 reset released, D5 triple fault, D4 demo ROM fetched,
//   D3 reset vector fetched, D2 response returned, D1 request accepted,
//   D0 FIRE1 held.
// After the first successful output, all eight LEDs show the x86 port value.
assign led = io_write_seen ? led_output :
             {heartbeat[24], cpu_reset_n, triple_fault_seen, demo_rom_seen,
              reset_vector_seen, response_seen, request_seen, btn[1]};

endmodule
