// CPU-only z386 focused shifter regression for the ULX3S 85F.
//
// This instantiates the complete z386 CPU with 1 KiB instruction/data caches
// and a synthetic ROM/I/O target. FIRE1 (btn[1]) is a dedicated active-high
// CPU reset: hold it while loading, then release it.
//
// The 16-bit real-mode ROM tests SHL, SHR, SAR, ROL, ROR, RCL, RCR, SHLD,
// and SHRD with immediate counts 0, 1, 16, and 17. BSR has no count operand,
// so it is tested with zero input and highest-set-bit positions 0, 1, 16,
// and 17. Defined results and flags are checked; SHLD/SHRD count 17 is
// architecturally undefined, so those cases verify execution and an unrelated
// canary register only.
//
// Before each case, its failure/progress code is written to port 0x0080. If a
// check fails or an instruction hangs, that code remains on the LEDs. Complete
// success alternates 0xA5 and 0x5A. The ROM is generated from
// rom/shift_regression.asm by scripts/build-asm-rom.sh.
`default_nettype none

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

// These signals remain visible only until the regression writes its first
// progress code to port 0x80.
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

// The generated ROM maps the reset vector to physical FFFFFFF0 and the focused
// regression program to physical 000F0000. Only one ROM lookup is required per
// cycle: an active burst response has priority over a newly accepted request.
wire [31:0] probe_rom_address = read_active ? read_address : cpu_byte_address;
wire [31:0] probe_rom_data;

shift_regression_probe_rom probe_rom (
    .address(probe_rom_address),
    .data   (probe_rom_data)
);

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
            cpu_din        <= probe_rom_data;
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
                cpu_din        <= probe_rom_data;
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

// Before the first regression progress write, expose enough state to prevent
// another ambiguous all-dark result:
//   D7 heartbeat, D6 reset released, D5 triple fault, D4 demo ROM fetched,
//   D3 reset vector fetched, D2 response returned, D1 request accepted,
//   D0 FIRE1 held.
// After the first progress write, all eight LEDs show the current test code.
// A static 0x01..0x29 identifies the failing/hung case; alternating A5/5A passes.
assign led = io_write_seen ? led_output :
             {heartbeat[24], cpu_reset_n, triple_fault_seen, demo_rom_seen,
              reset_vector_seen, response_seen, request_seen, btn[1]};

endmodule

`default_nettype wire
