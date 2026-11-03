// Behavioral test for the ILA mode-4 (CPU-bus-silence / hang) trigger.
// Drives the real ila module:
//   1. set trigger config mode=4 via SPI CMD1 (deterministic byte strobes),
//   2. arm via SPI CMD3,
//   3. run a "healthy desktop" pattern (AS gaps up to 180 < HANG_THRESH=192)
//      -> must NOT fire,
//   4. drive a "hang" (AS stuck high for 260 samples) -> MUST fire with
//      non-zero trigger_pos.
// Uses SPI (not UART) so the test does not depend on UART framing/timing.
//
// SPI protocol (ila.sv): strobe=1 marks a byte. First byte has start=1 and
// loads cmd. Following bytes (start=0) increment byte_cnt and are decoded per
// cmd. For CMD1 (0x01) the data bytes map to byte_cnt 0..7:
//   0 sample_clk_sel, 1 trig_mode, 2-4 trig_addr, 5-7 trig_mask.
// For CMD3 (0x03) data byte0: 0=disarm,1=arm,2=force.
//
// Build/run: use the --timing --binary flags, top module ila_hang_tb, sources
//   ../src/companion/ila.sv ../src/companion/ila_uart.sv ila_hang_tb.sv
// then execute ./obj_dir/Vila_hang_tb
`timescale 1ns/1ps
module ila_hang_tb;
  reg         clk = 0, reset = 1;
  reg         enPhi1_in = 1, enPhi2_in = 1;
  reg  [63:0] probes = 0;
  reg         _cpuAS = 1;
  // SPI
  reg         strobe = 0, start = 0;
  reg  [7:0]  din = 0;
  wire [7:0]  dout;
  // UART (idle)
  reg         uart_rx = 1;
  wire        uart_tx;
  // poke/peek
  wire        ice_poke_valid;
  wire [2:0]  ice_poke_idx;
  wire [15:0] ice_poke_data;
  wire        ice_peek_req;
  wire [2:0]  ice_peek_idx;
  reg  [15:0] ice_peek_data = 0;
  wire        enPhi1_out, enPhi2_out, cpu_reset_override;

  ila dut (
    .clk(clk), .reset(reset),
    .enPhi1_in(enPhi1_in), .enPhi2_in(enPhi2_in),
    .enPhi1_out(enPhi1_out), .enPhi2_out(enPhi2_out),
    .cpu_reset_override(cpu_reset_override),
    .probes(probes), ._cpuAS(_cpuAS),
    .strobe(strobe), .start(start), .din(din), .dout(dout),
    .uart_rx(uart_rx), .uart_tx(uart_tx),
    .ice_poke_valid(ice_poke_valid), .ice_poke_idx(ice_poke_idx),
    .ice_poke_data(ice_poke_data), .ice_peek_req(ice_peek_req),
    .ice_peek_idx(ice_peek_idx), .ice_peek_data(ice_peek_data)
  );

  always #5 clk = ~clk; // 100 MHz sim clock; logic samples every clk

  // One SPI byte: strobe high for one clock with start/din set.
  task spi_byte(input [7:0] b, input s);
    begin
      @(negedge clk) begin
        strobe = 1'b1;
        start  = s;
        din    = b;
      end
      @(negedge clk) strobe = 1'b0;
    end
  endtask

  // n samples with AS low (a live CPU cycle) at 24-bit address a.
  // In the real design probes[7] IS _cpuAS, so both must move together.
  task active(input [23:0] a, input integer n);
    integer k;
    begin
      probes = {8'h00, a, 21'b0, 3'b0, 1'b0, 7'b0};
      _cpuAS = 1'b0;
      for (k = 0; k < n; k = k + 1) @(negedge clk);
    end
  endtask

  // n samples with AS high (bus silent), keeping the last address
  task quiet(input integer n);
    integer k;
    begin
      probes = {8'h00, probes[55:32], 21'b0, 3'b0, 1'b1, 7'b0}; // AS high in both
      _cpuAS = 1'b1;
      for (k = 0; k < n; k = k + 1) @(negedge clk);
    end
  endtask

  integer t, fails;
  initial begin
    fails = 0;
    repeat (5) @(negedge clk);
    reset = 0;
    repeat (5) @(negedge clk);

    // CMD1 config: start byte 0x01, then 8 data bytes
    //   data0=0 (clk sel), data1=4 (mode 4), data2-4=0 (addr), data5-7=0 (mask)
    spi_byte(8'h01, 1'b1);
    spi_byte(8'h00, 1'b0);
    spi_byte(8'h04, 1'b0); // trig_mode = 4
    spi_byte(8'h00, 1'b0);
    spi_byte(8'h00, 1'b0);
    spi_byte(8'h00, 1'b0);
    spi_byte(8'h00, 1'b0);
    spi_byte(8'h00, 1'b0);
    spi_byte(8'h00, 1'b0);
    repeat (3) @(negedge clk);
    $display("CFG: ila.trig_mode=%0d (expect 4)", dut.trig_mode);
    if (dut.trig_mode != 3'd4) begin
      $display("*** FAIL: SPI CMD1 did not set trig_mode=4 ***"); fails = fails + 1;
    end

    // CMD3 arm: start byte 0x03, data byte0 = 1 (arm)
    spi_byte(8'h03, 1'b1);
    spi_byte(8'h01, 1'b0);
    repeat (3) @(negedge clk);
    $display("ARM: state=%0d trig_mode=%0d (expect state=1..2, mode copied)",
             dut.ila_state, dut.trig_mode);
    if (dut.trig_mode != 3'd4) begin
      $display("*** FAIL: arm did not copy trig_mode 4 into ila FSM ***"); fails = fails + 1;
    end

    // ---- PHASE 1: healthy desktop with LIVE-BOARD-RANGE gaps.
    // The real desktop has /AS-silent gaps up to ~12-13us (>= 192 samples),
    // so each 195-sample gap enters the mode-4 CANDIDATE state (ring freeze)
    // and MUST be ABORTED by the next active CPU burst (back to ARMED).
    // A false fire (POST_FILL/DONE) here would be a real bug.
    for (t = 0; t < 20; t = t + 1) begin
      active(24'h400000 + t, 6);   // AS low ~6 samples (a fetch)
      quiet(195);                    // AS high gap (195 >= HANG_CAND=192 -> candidate)
      active(24'h400000 + t, 6);   // CPU returns -> candidate must abort
    end
    $display("HEALTHY: after 20 gap-195 cycles, state=%0d pos=%0d quiet=%0d (expect state=2 ARMED, pos=0)",
             dut.ila_state, dut.trigger_pos, dut.quiet_cnt);
    if (dut.ila_state == 4 || dut.ila_state == 3) begin
      $display("*** FAIL: mode-4 false-fired on healthy desktop ***"); fails = fails + 1;
    end else if (dut.ila_state != 2) begin
      $display("*** FAIL: state stuck at %0d (expect ARMED=2) ***", dut.ila_state); fails = fails + 1;
    end else if (dut.trigger_pos != 8'd0) begin
      $display("*** FAIL: stale trigger_pos=%0d after aborted candidates (dump would misreport) ***",
               dut.trigger_pos); fails = fails + 1;
    end else begin
      $display("*** PASS: 195-sample healthy gaps made candidates but all aborted (state=ARMED, pos=0) ***");
    end

    // ---- PHASE 2: hard hang. Last CPU cycle, then silence:
    //   192 samples -> candidate (ring freeze), 60000 -> confirm (DONE).
    active(24'hBE003E, 2);          // last CPU cycle before the hang
    quiet(61000);                   // > HANG_CONF=60000
    $display("HANG: after 61000 silent samples, state=%0d pos=%0d quiet=%0d (expect state=4 DONE, pos!=0)",
             dut.ila_state, dut.trigger_pos, dut.quiet_cnt);
    if (dut.ila_state == 4 && dut.trigger_pos != 8'd0)
      $display("*** PASS: mode-4 confirmed hang, trigger_pos=%0d ***", dut.trigger_pos);
    else begin
      $display("*** FAIL: mode-4 did not confirm hang (state=%0d pos=%0d) ***",
               dut.ila_state, dut.trigger_pos);
      fails = fails + 1;
    end

    $display(fails ? "RESULT: %0d FAILURES" : "RESULT: ALL PASS", fails);
    $finish;
  end
endmodule
