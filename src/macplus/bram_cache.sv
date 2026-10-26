// bram_cache.sv — NanoMac 2KB Direct-Mapped Write-Through BRAM Cache
//
// Mirrors the on-chip cache approach of the Motorola 68030, which is what
// most historical Mac Plus accelerator cards (Novy, MicroMac, etc.) provided.
//
// Organization:
//   Size:   2KB = 1024 x 16-bit words
//   Lines:  1 word per line (simplest; can widen to multi-word later)
//   Index:  cpu_addr[10:1]  (10 bits -> 1024 lines)
//   Tag:    cpu_addr[23:11] (13 bits)
//   Valid:  1 bit
//
// BRAM usage: 2 x SDPB blocks on GW2AR-18
//   data_ram: 1024 x 16b = 16 Kbits  (1 SDPB)
//   tag_ram:  1024 x 16b = 16 Kbits  (1 SDPB, 14 bits used: {valid, tag[12:0]})
//
// Cacheable address space (caller-gated):
//   ROM: $400000-$4FFFFF (and overlay disabled via cacheable gate)
//   RAM: $000000-$3FFFFF, $600000-$7FFFFF
//
// Timing:
//   Phase 2: cpu_addr stable, BRAM address already being registered
//   Phase 3: BRAM output valid, tag comparison done, cache_hit asserted
//   Phase 3: DTACK fires on hit  (vs Phase 4 stock / Phase 7 turbo without cache)
//
// Write policy: write-through, no-write-allocate
//   CPU RAM writes always go to SDRAM via existing path.
//   The cache line for the written address is invalidated (full-word write to
//   tag_ram so BRAM inference is correct -- no bit-select partial writes).
//
// Fill: on a read miss, the returned word is written to cache via fill_pulse.

`default_nettype none

module bram_cache (
    input  wire        clk_sys,
    input  wire        reset_n,        // system reset (deasserted after power-on)
    input  wire        invalidate_all, // 0..LINES-1 cycles: clear all tags

    // CPU address (stable after _cpuAS asserts)
    input  wire [23:1] cpu_addr,

    // Cacheable qualifier: (selectROM || selectRAM) && !memoryOverlayOn && cache_en
    input  wire        cacheable,

    // Active bus cycle type (set at busPhase 2, cleared by req_rst)
    input  wire        rom_req,
    input  wire        ram_req,

    // Write-through invalidation: 1-cycle pulse at busPhase==2 on CPU RAM write
    input  wire        cpu_wr_pulse,
    input  wire [23:1] cpu_wr_addr,

    // Fill on miss: 1-cycle pulse at DTACK time when !cache_hit
    input  wire        fill_pulse,
    input  wire [23:1] fill_addr,
    input  wire [15:0] fill_data,

    // Outputs
    output wire        cache_hit,
    output wire [15:0] cache_data
);

    localparam LINES    = 1024;
    localparam IDX_BITS = 10;    // log2(LINES)
    localparam TAG_BITS = 13;    // cpu_addr[23:11]

    // BRAM arrays — inferred as SDPB by Gowin synthesizer (2 SDPB blocks total)
    // IMPORTANT: Gowin BRAM inference requires full-word writes.
    // Do NOT use bit-selects on the left-hand side of an assignment to these
    // arrays — it prevents BRAM inference and silently falls back to LUT RAM
    // with potentially incorrect behavior.
    reg [15:0]       data_ram [0:LINES-1];
    reg [TAG_BITS:0] tag_ram  [0:LINES-1];
    // tag_ram[i] = {valid[13], tag[12:0]}

    // -----------------------------------------------------------------------
    // Read port: address registered each cycle; output valid 1 cycle later
    // -----------------------------------------------------------------------
    reg [15:0]       data_out_r;
    reg [TAG_BITS:0] tag_out_r;

    wire [IDX_BITS-1:0] rd_idx = cpu_addr[IDX_BITS:1]; // cpu_addr[10:1]

    always @(posedge clk_sys) begin
        data_out_r <= data_ram[rd_idx];
        tag_out_r  <= tag_ram[rd_idx];
    end

    // -----------------------------------------------------------------------
    // Hit detection (combinatorial from registered BRAM output)
    // Valid at Phase 3 when BRAM was indexed at Phase 2 (or earlier)
    // -----------------------------------------------------------------------
    wire [TAG_BITS-1:0] cur_tag      = cpu_addr[23:11];
    wire                stored_valid = tag_out_r[TAG_BITS];
    wire [TAG_BITS-1:0] stored_tag   = tag_out_r[TAG_BITS-1:0];

    assign cache_hit  = cacheable && stored_valid && (stored_tag == cur_tag);
    assign cache_data = data_out_r;

    // -----------------------------------------------------------------------
    // Write port: fills (on miss) and invalidations (on CPU RAM write)
    //
    // CRITICAL: Both writes must use FULL-WORD assignments to tag_ram/data_ram.
    // Bit-select writes (tag_ram[i][13] <= 0) are not synthesizable as BRAM
    // on Gowin and get silently dropped or converted to LUT RAM.
    //
    // Invalidation: write {valid=0, tag=0} = 14'b0 (entire word) to tag_ram.
    //   This correctly marks the line as invalid without touching data_ram.
    //   The data_ram entry is stale but harmless — it won't be served because
    //   valid=0 means cache_hit will always be 0 for that index until refilled.
    //
    // fill_pulse and cpu_wr_pulse never coincide: fills happen at Phase 4/7
    // of a read cycle; wr_pulse fires at Phase 2 of a write cycle.
    // -----------------------------------------------------------------------
    wire [IDX_BITS-1:0] fill_idx = fill_addr[IDX_BITS:1];   // fill_addr[10:1]
    wire [IDX_BITS-1:0] inv_idx  = cpu_wr_addr[IDX_BITS:1]; // cpu_wr_addr[10:1]
    wire [TAG_BITS-1:0] fill_tag = fill_addr[23:11];

    // Power-on / enable-rise invalidation sweep: SRAM starts with
    // uninitialized contents on the FPGA, so a garbage valid+tag could
    // alias a real address and serve wrong data. On invalidate_all the
    // whole tag array is swept to 0 (LINES posedge cycles).
    reg [IDX_BITS:0] sweep_idx; // LINES bits: LINES = all done
    always @(posedge clk_sys or negedge reset_n) begin
        if (!reset_n)
            sweep_idx <= 0;
        else if (invalidate_all)
            sweep_idx <= sweep_idx + 1'b1;
        else
            sweep_idx <= 0;
    end

    always @(posedge clk_sys) begin
        if (invalidate_all) begin
            tag_ram[sweep_idx[IDX_BITS-1:0]] <= {(TAG_BITS+1){1'b0}};
        end else if (fill_pulse) begin
            // Miss resolved: store returned word in cache
            data_ram[fill_idx] <= fill_data;
            tag_ram[fill_idx]  <= {1'b1, fill_tag}; // valid = 1
        end else if (cpu_wr_pulse) begin
            // CPU writes RAM: invalidate the cache line (full-word write — BRAM safe)
            // valid=0, tag=0: entire entry cleared so any subsequent read will miss.
            tag_ram[inv_idx]   <= {(TAG_BITS+1){1'b0}};
        end
    end

endmodule

`default_nettype wire
