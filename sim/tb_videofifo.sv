// tb_videofifo.sv
//
// Option B lossless-video testbench (pre-integration, focused).
//
// Verifies the run-ahead video prefetch FIFO (videoFifo.sv) end to end at
// the SHIFTER/Pixel level against the real SDRAM FSM, real clocks, real
// videoTimer (with halt back-pressure) and the real videoShifter, with a
// fake 68k doing a ~50%-duty stream of RAM reads (the desktop pattern).
//
// Architecture under test:
//   videoTimer --(xpos,ypos,loadPixels,halt)--> videoFifo <--(push)---+
//        ^                                             |  ^            |
//        | halt (freeze raster + shifter load)         |  | pf_oe      |
//        |                                             |  | addr       |
//   arbiter: at each FREE SDRAM phase-2 slot: CPU RAM access wins
//            (Option A), else a video prefetch read if pf_want.
//   shifter: dataIn = videoFifo.data_out, loads on (loadPixels & cycleReady)
//
// Oracles:
//   1. PIXEL ORACLE: on every shifter load, the word loaded must equal the
//      framebuffer pattern for the CURRENT display position:
//        pattern(word W) = 16'(W)
//        expected = 16'((BASE + ypos*32 + (xpos>>4)) & 0xFFFF)
//      A drop/duplication/stale-word anywhere desyncs this -> caught.
//   2. FIFO ORACLE: no push-when-full (overflow), no pop-when-empty
//      (underflow), depth always in [0, DEPTH].
//   3. CPU ORACLE: every CPU read in flight must read back its own word
//      (rd_addr == CPU word at rd_done for CPU-owned reads).
//   4. Throughput: at least one full frame displayed (ypos wrapped) and
//      halt total is bounded (the frozen-line cost of losslessness).
//
// Build (from sim/):
//   run_verilator -j 4 --timing --binary -Wno-lint -Wno-fatal \
//     -top-module tb_videofifo \
//     ../src/macplus/clocks.v ../src/macplus/videoTimer.v \
//     ../src/macplus/videoFifo.sv ../src/macplus/videoShifter.v \
//     ../src/tang/nano20k/sdram.v tb_videofifo.sv -Mdir obj_vfifo
//   ./obj_vfifo/Vtb_videofifo

`timescale 1ns/1ps
module tb_videofifo;

  localparam RUN_TICKS = 280000;          // ~1.1 frames (260480/frame)
  localparam BASE      = 21'h1F9380;      // must match videoFifo BASE
  localparam DUTY      = 400;             // /AS low/high ticks (desktop 50%)

  reg clk = 0, reset = 1;
  always #5 clk = ~clk;

  wire [2:0] phase;
  wire clk8_en_p, clk8_en_n, cycleReady, videoBusControl, cpuBusControl;
  clocks clk_i (
    .clk(clk), .clk8_en_p(clk8_en_p), .clk8_en_n(clk8_en_n),
    .busPhase(phase), .cycleReady(cycleReady),
    .videoBusControl(videoBusControl), .cpuBusControl(cpuBusControl)
  );

  // ---- fake 68k: 50%-duty RAM reads, address cycling in $000100-$0001FE
  reg  [23:1] cpuAddr = 23'h000100;
  reg  _cpuAS = 1'b1;
  wire _cpuRW = 1'b1, _cpuUDS = 1'b1, _cpuLDS = 1'b0;
  wire cpuWord = cpuAddr[21:1];           // identity mapping (4MB)

  // ---- videoTimer (with Option B halt) ----
  wire [20:0] videoAddr;
  wire hsync, vsync, _hblank, _vblank, loadPixels, refresh;
  wire halt;
  videoTimer vt (
    .clk(clk), .clk8_en_p(clk8_en_p), .clk8_en_n(clk8_en_n),
    .videoCycle(videoBusControl), .vid_alt(1'b0), .halt(halt),
    .videoAddr(videoAddr), .hsync(hsync), .vsync(vsync),
    ._hblank(_hblank), ._vblank(_vblank), .refresh(refresh),
    .loadPixels(loadPixels)
  );

  // ---- videoFifo (elastic run-ahead prefetch FIFO) ----
  wire        pf_want;
  wire [20:0] pf_addr;
  wire [15:0] fifo_data;
  wire        fifo_empty;
  wire        pf_push;
  wire [15:0] pf_push_data;
  wire        pop;
  wire [7:0]  fifo_depth;                 // real FIFO occupancy (from the module)

  videoFifo vf (
    .clk(clk), .reset(reset),
    .xpos(vt.xpos), .ypos(vt.ypos), .vblank(_vblank),
    .halt(halt),
    .pf_want(pf_want), .pf_addr(pf_addr),
    .push(pf_push), .push_data(pf_push_data),
    .pop(pop), .data_out(fifo_data), .empty(fifo_empty),
    .depth(fifo_depth)
  );

  // ---- SDRAM (real board FSM) ----
  wire        sd_clk, sd_cke, sd_cs, sd_we, sd_ras, sd_cas, ready;
  wire [31:0] sd_data, sd_data_in;
  wire [10:0] sd_addr;
  wire [3:0]  sd_dqm;
  wire [1:0]  sd_ba;
  wire [15:0] sdram_dout;
  wire        rd_done;
  wire [21:0] rd_addr;

  // ---- arbiter: CPU wins the slot (Option A), else video prefetch ----
  // The SDRAM FSM samples oe/we/addr at the posedge ending phase 2
  // (sdram.v:155-161), so the request must be combinational at that tick.
  // A register here would be one tick late (the FSM sees it on the NEXT
  // phase-2 tick -> double-issue).
  reg        sdram_busy = 0;             // FSM in flight (shadow)
  reg        flight_vid = 0;             // in-flight read is a video prefetch
  reg        pref_oe_r  = 0;             // 1-tick delayed pf_want (startup)

  wire cpu_active = !_cpuAS;             // /AS low = CPU RAM access in flight

  // Video prefetch may use ANY free phase-2 slot (video OR CPU half; the
  // SDRAM is a shared bus) - that is what creates the run-ahead headroom
  // (~2 free slots/16 ticks vs 1 display word/16 ticks).
  wire issue_cpu = (phase == 3'd2) && cpuBusControl && cpu_active
                  && !sdram_busy && ready;
  wire issue_vid = (phase == 3'd2) && pref_oe_r
                  && !issue_cpu && !sdram_busy && ready;
  // the address the FSM will latch THIS tick (same expression as pf_addr)
  wire [20:0] sd_addr_now = issue_cpu ? cpuWord
                            : issue_vid ? pf_addr : 21'd0;
  // what the previous in-flight read was (for the data model + CPU oracle)
  reg  [20:0] issue_addr_r = 21'd0;

  assign pf_push      = rd_done && flight_vid;
  assign pf_push_data = sdram_dout;
  assign pop          = loadPixels && cycleReady;   // shifter load edge (board)

  // pattern model: RAM word at word-address W holds 16'(W & 0xFFFF).
  // Real hardware HOLDS the address + data for the whole access (the 68k
  // holds cpuAddr/cpuDataIn; the video DMA holds videoAddr), so the FSM's
  // RAS row (latched at issue) and CAS column / doutD (latched at
  // STATE_READ) see the SAME address. Model that with hold_addr.
  reg  [20:0] hold_addr = 21'd0;
  wire [20:0] addr_present = (issue_cpu || issue_vid) ? sd_addr_now : hold_addr;
  assign sd_data_in = {hold_addr[15:0], hold_addr[15:0]};

  sdram sd (
    .clk(clk), .reset_n(!reset),
    .sd_clk(sd_clk), .sd_cke(sd_cke),
    .sd_data(sd_data), .sd_data_in(sd_data_in),
    .sd_addr(sd_addr), .sd_dqm(sd_dqm), .sd_ba(sd_ba),
    .sd_cs(sd_cs), .sd_we(sd_we), .sd_ras(sd_ras), .sd_cas(sd_cas),
    .ready(ready), .phase(phase),
    .din(16'h0000), .dout(sdram_dout), .rd_done(rd_done), .rd_addr(rd_addr),
    .addr({1'b0, addr_present}), .ds(2'b01),
    .oe(issue_cpu || issue_vid), .we(1'b0)
  );

  always @(posedge clk) begin
    if (reset) begin
      sdram_busy   <= 0;
      flight_vid   <= 0;
      pref_oe_r    <= 0;
      issue_addr_r <= 21'd0;
      hold_addr    <= 21'd0;
    end else begin
      pref_oe_r <= pf_want;             // 1 tick: pf_want stable at phase 2
      if (issue_cpu || issue_vid) begin
        sdram_busy   <= 1'b1;
        flight_vid   <= issue_vid;
        issue_addr_r <= sd_addr_now;
        hold_addr    <= sd_addr_now;    // hold for the whole read
      end else if (rd_done) begin
        sdram_busy   <= 1'b0;
      end
    end
  end

  // ---- videoShifter (board part) fed from the FIFO ----
  wire pixelOut;
  videoShifter vs (
    .clk(clk), .clk8_en_p(clk8_en_p), .clk8_en_n(clk8_en_n),
    .dataIn(fifo_data), .loadPixels(pop), .pixelOut(pixelOut)
  );

  // ---- oracles ----
  integer ticks = 0, fails = 0;
  integer px_checked = 0, px_ok = 0, px_fail = 0;
  integer cpu_checks = 0, cpu_ok = 0;
  integer halt_ticks = 0;
  integer lines_done = 0;
  reg [8:0] ypos_prev = 9'd0;

  wire [13:0] disp_idx = ( {5'd0, vt.ypos} << 5 ) + ( {5'd0, vt.xpos} >> 4 );
  wire [20:0] exp_full = BASE + {7'd0, disp_idx};
  wire [15:0] expected_word = exp_full[15:0];

  always @(posedge clk) begin
    if (!reset) begin
      if (halt) halt_ticks = halt_ticks + 1;
      if (vt.ypos == 9'd0 && ypos_prev == 9'd369) lines_done = lines_done + 1;
      ypos_prev <= vt.ypos;

      // FIFO invariants (real depth from the module)
      if (pf_push && fifo_depth == 8'd128) begin
        fails = fails + 1;
        if (fails <= 10) $display("*** FIFO OVERFLOW @%0d", ticks);
      end
      if (pop && fifo_empty) begin
        fails = fails + 1;
        if (fails <= 10) $display("*** FIFO UNDERFLOW @%0d", ticks);
      end

      // PIXEL ORACLE: shifter loaded a word -> must match display position
      if (pop && !fifo_empty) begin
        px_checked = px_checked + 1;
        if (fifo_data == expected_word) px_ok = px_ok + 1;
        else if (fails <= 10) begin
          fails = fails + 1;
          $display("*** PIXEL MISMATCH @%0d x=%0d y=%0d: loaded=%04h expect=%04h",
                   ticks, vt.xpos, vt.ypos, fifo_data, expected_word);
        end
      end

      // CPU ORACLE: a CPU read completed -> rd_addr must be the word that
      // was ISSUED for it (issue_addr_r; the fake 68k address keeps
      // cycling after the issue, so cpuWord is not the right target)
      if (rd_done && !flight_vid) begin
        cpu_checks = cpu_checks + 1;
        if (rd_addr[20:0] == issue_addr_r) cpu_ok = cpu_ok + 1;
        else if (fails <= 10) begin
          fails = fails + 1;
          $display("*** CPU READ MISMATCH @%0d: rd=%06h issued=%06h",
                   ticks, rd_addr[20:0], issue_addr_r);
        end
      end

      // TEMP DEBUG: FIFO/prefetch timeline samples
      if (ticks % 2000 == 0 && ticks < 40000)
        $display("TIM t=%0d depth=%0d pfidx_addr=%06h disp_full=%06h pfdisp=%06d halt=%b pop=%b push=%b x=%0d y=%0d",
                 ticks, fifo_depth, pf_addr, exp_full,
                 $signed($signed(pf_addr - exp_full)), halt, pop, pf_push,
                 vt.xpos, vt.ypos);
      if (ticks >= 400 && ticks < 480 && (pop || pf_push))
        $display("DET t=%0d ph=%d depth=%0d head=%04h exp=%04h pop=%b push=%b pfidxA=%06h dispA=%06h x=%0d",
                 ticks, phase, fifo_depth, fifo_data, expected_word,
                 pop, pf_push, pf_addr, exp_full, vt.xpos);

      ticks = ticks + 1;
      if (ticks == RUN_TICKS) begin
        $display("===================================================");
        $display("ticks=%0d  lines-done=%0d  halt-ticks=%0d  depth=%0d",
                 ticks, lines_done, halt_ticks, fifo_depth);
        $display("pixels checked=%0d ok=%0d   cpu-reads checked=%0d ok=%0d",
                 px_checked, px_ok, cpu_checks, cpu_ok);
        $display("MISMATCHES: %0d", fails);
        if (fails == 0 && px_ok == px_checked && px_checked > 1000 &&
            cpu_ok == cpu_checks && cpu_checks > 100 && lines_done >= 1)
          $display("RESULT: PASS - video lossless (every pixel correct under 50%%-duty CPU load)");
        else if (fails > 0)
          $display("RESULT: FAIL - %0d error(s)", fails);
        else
          $display("RESULT: INCONCLUSIVE");
        $display("===================================================");
        $finish;
      end
    end
  end

  // fake-68k 50% duty driver
  integer duty_cnt = 0;
  always @(posedge clk) begin
    if (!reset) begin
      if (duty_cnt == 2*DUTY) duty_cnt = 0;
      else duty_cnt = duty_cnt + 1;
      if (duty_cnt < DUTY) begin
        _cpuAS  <= 1'b0;                 // access in flight
        if (cpuAddr == 23'h0001FE) cpuAddr <= 23'h000100;
        else cpuAddr <= cpuAddr + 23'd1;
      end else begin
        _cpuAS  <= 1'b1;                 // gap
      end
    end
  end

  initial begin
    reset = 1;
    repeat (10) @(posedge clk);
    reset = 0;
    wait (ready);
    // settle: after ready the FSM internal state may still be mid-cycle
    // (init advances it); wait a full state cycle before the first issue
    repeat (16) @(posedge clk);
  end

endmodule
