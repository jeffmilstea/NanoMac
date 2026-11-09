`timescale 1ns/1ps
// tb_cache_flash.sv
//
// Deterministic hardware-timing unit test for:
//   1. flash_dspi.v + bram_cache.sv ROM fill timing in Stock (phase==1 -> 6)
//      and Turbo (phase==2 -> 7) modes at the exact 5:1 clk_pixel_x5 : clk_sys ratio.
//      Proves that sampling at busPhase==4 in Stock mode latches half-shifted
//      SPI flash garbage, while sampling at busPhase==6 (Stock) and busPhase==7
//      (Turbo) latches the exact 16-bit ROM word.
//   2. bram_cache.sv write-invalidation guard (_cpuRW gating + rd_valid_r / rd_idx_r):
//      Proves that a CPU RAM write to a cached address never asserts cache_hit
//      during the write cycle and invalidates the line for subsequent reads, and
//      that changing cpu_addr[10:1] within the same 2KB page never asserts a
//      combinational false hit before posedge clk_sys.

module tb_cache_flash;

  // 5:1 clock tree: clk_x5 (5 ticks per clk_sys period)
  reg clk_x5  = 0;
  reg clk_sys = 0;
  reg resetn  = 0;

  integer sub = 0;
  always #1 clk_x5 = ~clk_x5; // 2ns period for clk_x5

  always @(posedge clk_x5) begin
    if (sub == 4) sub <= 0;
    else          sub <= sub + 1;
    // clk_sys rises at sub==0, falls at sub==2 (10ns period = 5x clk_x5)
    if (sub == 0) clk_sys <= 1'b1;
    if (sub == 2) clk_sys <= 1'b0;
  end

  // 8-phase bus grid on clk_sys
  reg [2:0] busPhase = 3'd0;
  always @(posedge clk_sys) begin
    if (!resetn) busPhase <= 3'd0;
    else         busPhase <= busPhase + 3'd1;
  end

  // Flash controller under test
  reg         turbo_mode = 1'b0;
  reg  [17:0] rom_addr   = 18'h00000;
  wire [15:0] rom_data;
  wire        flash_ready, flash_busy, mspi_cs, mspi_di, mspi_hold, mspi_wp, mspi_do;

  // Emulate W25Q64 dual-SPI output for a deterministic word per rom_addr:
  // expected_word(addr) = 16'hA500 ^ addr[15:0]
  wire [15:0] expected_rom_word = 16'hA500 ^ rom_addr[15:0];
  wire [5:0]  fl_state = u_flash.state;
  wire [1:0]  mspi_din =
      (fl_state == 6'd24) ? expected_rom_word[15:14] :
      (fl_state == 6'd25) ? expected_rom_word[13:12] :
      (fl_state == 6'd26) ? expected_rom_word[11:10] :
      (fl_state == 6'd27) ? expected_rom_word[9:8]   :
      (fl_state == 6'd28) ? expected_rom_word[7:6]   :
      (fl_state == 6'd29) ? expected_rom_word[5:4]   :
      (fl_state == 6'd30) ? expected_rom_word[3:2]   :
      (fl_state == 6'd31) ? expected_rom_word[1:0]   : 2'b00;

  flash u_flash (
    .clk      ( clk_x5 ),
    .resetn   ( resetn ),
    .ready    ( flash_ready ),
    .address  ( {4'b1001, rom_addr} ),
    .cs       ( turbo_mode ? (busPhase == 3'd2) : (busPhase == 3'd1) ),
    .dout     ( rom_data ),
    .mspi_cs  ( mspi_cs ),
    .mspi_di  ( mspi_di ),
    .mspi_hold( mspi_hold ),
    .mspi_wp  ( mspi_wp ),
    .mspi_do  ( mspi_do ),
    .mspi_din ( mspi_din ),
    .busy     ( flash_busy )
  );

  // BRAM cache under test
  reg         inv_all      = 1'b0;
  reg  [23:1] cpu_addr     = 23'h200000; // $400000 >> 1
  reg         _cpuAS       = 1'b1;
  reg         _cpuRW       = 1'b1;
  reg         rom_req      = 1'b0;
  reg         ram_req      = 1'b0;
  reg         fill_pulse   = 1'b0;
  reg  [23:1] fill_addr    = 23'd0;
  reg  [15:0] fill_data    = 16'd0;
  wire        cache_hit;
  wire [15:0] cache_data;

  wire        cacheable_in = !_cpuAS && _cpuRW && !inv_all;
  wire        wr_pulse     = !_cpuRW && !_cpuAS;

  bram_cache u_cache (
    .clk_sys       ( clk_sys      ),
    .reset_n       ( resetn       ),
    .invalidate_all( inv_all      ),
    .cpu_addr      ( cpu_addr     ),
    .cacheable     ( cacheable_in ),
    .rom_req       ( rom_req      ),
    .ram_req       ( ram_req      ),
    .cpu_wr_pulse  ( wr_pulse     ),
    .cpu_wr_addr   ( cpu_addr     ),
    .fill_pulse    ( fill_pulse   ),
    .fill_addr     ( fill_addr    ),
    .fill_data     ( fill_data    ),
    .cache_hit     ( cache_hit    ),
    .cache_data    ( cache_data   )
  );

  integer fails = 0;
  reg [15:0] phase4_sample;

  initial begin
    resetn = 0;
    repeat (4) @(posedge clk_sys);
    resetn = 1;

    // Sweep cache invalidation (1024 cycles) and wait for flash_ready
    inv_all = 1;
    repeat (1026) @(posedge clk_sys);
    inv_all = 0;
    wait (flash_ready && !flash_busy);

    // ------------------------------------------------------------------
    // TEST 1: Stock mode ROM read + fill at busPhase==6 (vs busPhase==4)
    // ------------------------------------------------------------------
    turbo_mode = 1'b0;
    @(posedge clk_sys iff (busPhase == 3'd0));
    rom_addr <= 18'h00123;
    cpu_addr <= 23'h200123;
    _cpuRW   <= 1'b1;
    // S1 (busPhase==1): address valid, flash_dspi starts on phase==1
    @(posedge clk_sys iff (busPhase == 3'd1));
    _cpuAS   <= 1'b0; // S2 (busPhase==2)
    @(posedge clk_sys iff (busPhase == 3'd2));
    rom_req  <= 1'b1;

    // At posedge 4->5 (end of busPhase==4), check what the OLD bug latched:
    @(posedge clk_sys iff (busPhase == 3'd4));
    phase4_sample = rom_data;
    if (phase4_sample == expected_rom_word) begin
      $display("FAIL: expected busPhase==4 sample to be incomplete, got %04h", phase4_sample);
      fails = fails + 1;
    end else begin
      $display("INFO: Confirmed Stock busPhase==4 SPI flash data is still shifting (%04h != %04h)",
               phase4_sample, expected_rom_word);
    end

    // At posedge 6->7 (end of busPhase==6, new rom_fill_evt timing):
    @(posedge clk_sys iff (busPhase == 3'd6));
    if (rom_data !== expected_rom_word) begin
      $display("FAIL: Stock busPhase==6 rom_data=%04h expected=%04h", rom_data, expected_rom_word);
      fails = fails + 1;
    end
    fill_pulse <= 1'b1;
    fill_addr  <= cpu_addr;
    fill_data  <= rom_data;
    @(posedge clk_sys);
    fill_pulse <= 1'b0;
    _cpuAS     <= 1'b1;
    rom_req    <= 1'b0;

    // Verify subsequent Stock read to same ROM address hits with exact data
    @(posedge clk_sys iff (busPhase == 3'd1));
    _cpuAS <= 1'b0;
    @(posedge clk_sys iff (busPhase == 3'd3));
    if (!cache_hit || cache_data !== expected_rom_word) begin
      $display("FAIL: Stock ROM cache hit failed: hit=%b data=%04h expected=%04h",
               cache_hit, cache_data, expected_rom_word);
      fails = fails + 1;
    end
    _cpuAS <= 1'b1;

    // ------------------------------------------------------------------
    // TEST 2: Turbo mode ROM read + fill at busPhase==7
    // ------------------------------------------------------------------
    turbo_mode = 1'b1;
    @(posedge clk_sys iff (busPhase == 3'd1));
    rom_addr <= 18'h00456;
    cpu_addr <= 23'h200456;
    _cpuAS   <= 1'b0;
    @(posedge clk_sys iff (busPhase == 3'd2));
    rom_req  <= 1'b1;
    // At posedge 7->0 (end of busPhase==7 in Turbo mode):
    @(posedge clk_sys iff (busPhase == 3'd7));
    if (rom_data !== expected_rom_word) begin
      $display("FAIL: Turbo busPhase==7 rom_data=%04h expected=%04h", rom_data, expected_rom_word);
      fails = fails + 1;
    end
    fill_pulse <= 1'b1;
    fill_addr  <= cpu_addr;
    fill_data  <= rom_data;
    @(posedge clk_sys);
    fill_pulse <= 1'b0;
    _cpuAS     <= 1'b1;
    rom_req    <= 1'b0;

    // ------------------------------------------------------------------
    // TEST 3: Synchronous index guard (same tag, different index before posedge)
    // ------------------------------------------------------------------
    @(posedge clk_sys);
    _cpuAS <= 1'b0;
    cpu_addr <= 23'h200456; // cached line
    @(posedge clk_sys);
    #1;
    if (!cache_hit) begin
      $display("FAIL: expected hit on cached line 200456");
      fails = fails + 1;
    end
    // Change index within same 2KB page (tag unchanged) BETWEEN clk_sys edges:
    cpu_addr = 23'h200457;
    #1;
    if (cache_hit) begin
      $display("FAIL: false combinational cache_hit before posedge clk_sys on index change!");
      fails = fails + 1;
    end

    // ------------------------------------------------------------------
    // TEST 4: Write cycle never asserts cache_hit and invalidates line
    // ------------------------------------------------------------------
    cpu_addr <= 23'h200456;
    @(posedge clk_sys);
    _cpuRW <= 1'b0; // CPU write to cached address
    #1;
    if (cache_hit) begin
      $display("FAIL: cache_hit asserted during CPU write cycle!");
      fails = fails + 1;
    end
    @(posedge clk_sys); // wr_pulse invalidates line at this posedge
    _cpuRW <= 1'b1;     // switch back to read immediately
    #1;
    if (cache_hit) begin
      $display("FAIL: cache_hit asserted immediately after write invalidation!");
      fails = fails + 1;
    end
    @(posedge clk_sys);
    #1;
    if (cache_hit) begin
      $display("FAIL: line remained valid after write invalidation!");
      fails = fails + 1;
    end

    if (fails == 0)
      $display("RESULT: PASS - All 4 flash_dspi + bram_cache hardware timing invariants verified!");
    else
      $display("RESULT: FAIL (%0d errors)", fails);
    $finish;
  end

endmodule
