// CPU-only z386 integration probe for the ULX3S 85F.
//
// This is deliberately not a PC system yet. It instantiates the complete z386
// CPU with small instruction/data caches and a tiny synthetic bus target. The
// reset vector contains an endless x86 short jump (EB FE), allowing the core to
// fetch and execute while the board LEDs expose basic bus/debug activity.

module z386_synth_probe #(
    // Slang compatibility probe: 16 sets x 4 ways x 16 bytes = 1 KiB each.
    // The staged cache arrays are logic-backed until ECP5 RAM wrappers are added.
    parameter integer DCACHE_SET_BITS = 4,
    parameter integer ICACHE_SET_BITS = 4
) (
    input  logic       clk_25mhz,
    input  logic [6:0] btn,
    output logic [7:0] led
);

logic [6:0] btn_meta = '0;
logic [6:0] btn_sync = '0;
logic [7:0] reset_pipe = '1;

always_ff @(posedge clk_25mhz) begin
    btn_meta <= btn;
    btn_sync <= btn_meta;

    if (!btn[0])
        reset_pipe <= '1;
    else
        reset_pipe <= {reset_pipe[6:0], 1'b0};
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

logic [7:0]  read_words_left = '0;
logic [31:0] read_address = '0;
logic [31:0] activity_counter = '0;

wire [31:0] cpu_byte_address = {cpu_addr, 2'b00};

function automatic [31:0] probe_read_data(input [31:0] address);
    begin
        case (address)
            // Little-endian bytes: EB FE 90 90. The reset vector loops forever.
            32'hffff_fff0: probe_read_data = 32'h9090_feeb;
            default:       probe_read_data = 32'h9090_9090;
        endcase
    end
endfunction

// One accepted request at a time. Read bursts return one DWORD per cycle after
// acceptance. This is enough to exercise the z386 prefetch/cache-fill interface
// without inferring a large memory array in the first ECP5 fit experiment.
always_ff @(posedge clk_25mhz) begin
    cpu_ready      <= 1'b0;
    cpu_resp_valid <= 1'b0;

    if (!cpu_reset_n) begin
        cpu_din          <= 32'h9090_9090;
        read_words_left  <= 8'd0;
        read_address     <= 32'd0;
        activity_counter <= 32'd0;
    end else begin
        if (read_words_left != 0) begin
            cpu_din          <= probe_read_data(read_address);
            cpu_resp_valid   <= 1'b1;
            read_address     <= read_address + 32'd4;
            read_words_left  <= read_words_left - 8'd1;
        end

        if (cpu_valid && !cpu_ready && (read_words_left == 0)) begin
            cpu_ready      <= 1'b1;
            activity_counter <= activity_counter + 32'd1;

            if (!cpu_write) begin
                read_address    <= cpu_byte_address;
                read_words_left <= (cpu_burstcount == 0) ? 8'd1 : cpu_burstcount;
            end
        end
    end
end

// Keep the CPU as a visible hierarchy during the initial resource probe. The
// generic ALU and inferred block-ROM paths are selected by leaving the
// Quartus-only Z386_* macros undefined.
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
    .intr              (btn_sync[1]),
    .nmi               (btn_sync[2]),
    .inta              (cpu_inta),
    .snoop_addr        ({activity_counter[29:0], 2'b00}),
    .snoop_valid       (btn_sync[5]),
    .a20_enable        (!btn_sync[4]),
    .single_step       (btn_sync[3]),
    .dbg_CS            (dbg_cs),
    .dbg_EIP           (dbg_eip),
    .dbg_CS_base       (dbg_cs_base),
    .dbg_pe            (dbg_pe),
    .dbg_vm            (dbg_vm),
    .triple_fault_reset(triple_fault_reset)
);

// LED map:
//   0 reset released      4 I/O request
//   1 request valid       5 write request
//   2 request accepted    6 triple-fault reset request
//   3 read response       7 accepted-request heartbeat
always_comb begin
    led[0] = cpu_reset_n;
    led[1] = cpu_valid;
    led[2] = cpu_ready;
    led[3] = cpu_resp_valid;
    led[4] = cpu_io;
    led[5] = cpu_write;
    led[6] = triple_fault_reset;
    led[7] = activity_counter[20] ^ btn_sync[6];
end

endmodule
