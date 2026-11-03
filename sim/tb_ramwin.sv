// tb_ramwin.sv
//
// Deterministic test for the phase-2 SDRAM fetch-slot collision between a
// CPU RAM access and the video/audio DMA, using the REAL board modules:
//   clocks + addrController (contains addrDecoder + videoTimer) + sdram FSM.
//
// Root cause under test (board-only, 2026-11-03 hang.vcd decode):
//   The SDRAM FSM (sdram.v) accepts EXACTLY ONE oe/we request per phase-2 tick
//   (sdram.v:153-165). addrController's addrMux (line 108) gives video/audio
//   priority over the CPU, and _ramOE/_ramWE follow that mux. So when a CPU
//   RAM access is address-valid at a phase-2 tick that falls in a video half
//   (videoBusControl=1, loadPixels=1), the FSM fetches the VIDEO framebuffer
//   word, not the CPU's word. The CPU read is never serviced with its own
//   data -> poisoned read (the $00003E vector read in hang.vcd).
//
// Method:
//   A fake 68k holds a continuous word READ of $00003E (word addr $00001F),
//   /AS low, for the first half of the run; /AS deasserts for the second half
//   (CPU idle, video keeps fetching). For every phase-2 tick on which the FSM
//   issues a fetch, the test checks the latched rd_addr (valid one cycle
//   later) against the expected owner:
//     - CPU access pending (selectRAM && !_cpuAS)      -> expect CPU word
//     - else video pixel (raw loadPixels)              -> expect video word
//     - else audio (raw loadSound)                     -> expect audio word
//
//   UNFIXED code: video-half collision ticks fetch the VIDEO word -> FAILs.
//   FIXED code (Option A, CPU wins the slot): all fetches match -> PASS,
//   including the video-only ticks in the second half (video not broken).
//
// Build/run (from sim/): see the Makefile target below, or:
//   <verilator> -j 4 --timing --binary -Wno-lint -Wno-fatal -top-module tb_ramwin \
//     ../src/macplus/clocks.v ../src/macplus/addrDecoder.v \
//     ../src/macplus/videoTimer.v ../src/macplus/addrController.v \
//     ../src/tang/nano20k/sdram.v tb_ramwin.sv
//   ./obj_dir/Vtb_ramwin

`timescale 1ns/1ps
module tb_ramwin;

  localparam [20:0] CPU_WORD = 21'h00001F; // $00003E >> 1  (vector-15 area)
  localparam RUN_TICKS  = 4000;             // 500 E-cycles ~= 1.4 video lines
  localparam CPU_OFF    = 2000;             // /AS deasserts here (CPU idle)

  reg clk = 0, reset = 1;
  always #5 clk = ~clk; // period 10ns; synchronous logic, period irrelevant

  // clocks
  wire [2:0] phase;
  wire clk8_en_p, clk8_en_n, cycleReady, videoBusControl, cpuBusControl;
  clocks clk_i (
    .clk(clk),
    .clk8_en_p(clk8_en_p),
    .clk8_en_n(clk8_en_n),
    .busPhase(phase),
    .cycleReady(cycleReady),
    .videoBusControl(videoBusControl),
    .cpuBusControl(cpuBusControl)
  );

  // addrController (contains addrDecoder + videoTimer)
  wire [23:1] cpuAddr = CPU_WORD;  // fake 68k: continuous read of $00003E
  reg _cpuAS = 0;                  // read active; toggled by the initial block
  wire _cpuRW  = 1;                // 1 = READ (fx68k eRWn is active-low)
  wire _cpuUDS = 0, _cpuLDS = 0;   // word access

  wire [17:0] romAddr;
  wire [20:0] ramAddr;
  wire _memoryUDS, _memoryLDS, _romOE, _ramOE, _ramWE;
  wire selectSCSI, selectSCC, selectIWM, selectVIA, selectRAM,
        selectROM, selectSEOverlay, selectHardwareRegs;
  wire hsync, vsync, _hblank, _vblank, loadPixels, loadSound, refresh;

  addrController ac (
    .clk(clk),
    .clk8_en_p(clk8_en_p),
    .clk8_en_n(clk8_en_n),
    .videoBusControl(videoBusControl),
    .cpuBusControl(cpuBusControl),
    .cycleReady(cycleReady),
    .configROMSize(2'b01),
    .configRAMSize(2'b11),      // 4MB -> identity ramAddr mapping (no A19/A20 mask)
    .cpuAddr(cpuAddr),
    ._cpuUDS(_cpuUDS),
    ._cpuLDS(_cpuLDS),
    ._cpuRW(_cpuRW),
    ._cpuAS(_cpuAS),
    .romAddr(romAddr),
    .ramAddr(ramAddr),
    ._memoryUDS(_memoryUDS),
    ._memoryLDS(_memoryLDS),
    ._romOE(_romOE),
    ._ramOE(_ramOE),
    ._ramWE(_ramWE),
    .selectSCSI(selectSCSI),
    .selectSCC(selectSCC),
    .selectIWM(selectIWM),
    .selectVIA(selectVIA),
    .selectRAM(selectRAM),
    .selectROM(selectROM),
    .selectSEOverlay(selectSEOverlay),
    .selectHardwareRegs(selectHardwareRegs),
    .hsync(hsync),
    .vsync(vsync),
    ._hblank(_hblank),
    ._vblank(_vblank),
    .loadPixels(loadPixels),
    .vid_alt(1'b0),
    .snd_alt(1'b0),
    .loadSound(loadSound),
    .memoryOverlayOn(1'b0),
    .refresh(refresh)
  );

  // raw (pre-arbitration) DMA demands, to classify each phase-2 tick
  wire raw_loadPixels = ac.vt.loadPixels;
  wire [20:0] videoAddr = ac.vt.videoAddr;
  wire [20:0] audioAddr = ac.audioAddr;
  wire raw_loadSound = videoBusControl & ac.sndReqCycle;

  // sdram FSM (real board module), identity address mapping like nanomac_tb.v
  wire        sd_clk, sd_cke, sd_cs, sd_we, sd_ras, sd_cas, ready;
  wire [31:0] sd_data;
  wire [31:0] sd_data_in = 32'hBEEF0000;
  wire [10:0] sd_addr;
  wire [3:0]  sd_dqm;
  wire [1:0]  sd_ba;
  wire [15:0] sdram_dout;
  wire        rd_done;
  wire [21:0] rd_addr;
  wire [1:0]  sd_ds = { !_memoryUDS, !_memoryLDS };

  sdram sd (
    .clk(clk),
    .reset_n(!reset),
    .sd_clk(sd_clk), .sd_cke(sd_cke),
    .sd_data(sd_data), .sd_data_in(sd_data_in),
    .sd_addr(sd_addr), .sd_dqm(sd_dqm), .sd_ba(sd_ba),
    .sd_cs(sd_cs), .sd_we(sd_we), .sd_ras(sd_ras), .sd_cas(sd_cas),
    .ready(ready),
    .phase(phase),            // the 8-phase bus grid the FSM syncs to
    .din(16'h0000),
    .dout(sdram_dout),
    .rd_done(rd_done),
    .rd_addr(rd_addr),
    .addr({1'b0, ramAddr}),
    .ds(sd_ds),
    .oe(!_ramOE),             // active-high (macplus.sv: sdram_oe = !_ramOE)
    .we(!_ramWE)
  );

  // ------------------------------------------------------------------------
  // Fetch owner check.
  // The FSM latches rd_addr_r at the posedge ending the phase-2 tick in which
  // it accepted a request (sdram.v:161). So a check taken at the FOLLOWING
  // posedge (phase 3) sees the fetched word address.
  // ------------------------------------------------------------------------
  reg         chk_pending = 0;
  reg [20:0]  chk_expect;
  reg [1:0]   chk_owner;   // 0=cpu 1=video 2=audio

  integer ticks = 0;
  integer fails = 0, cpu_fetches = 0, cpu_ok = 0, vid_fetches = 0, vid_ok = 0,
          snd_fetches = 0, snd_ok = 0;

  always @(posedge clk) begin
    if (!reset) begin
      // ---- check the word latched by the previous phase-2 tick ----
      if (chk_pending) begin
        if (rd_addr[20:0] == chk_expect) begin
          case (chk_owner)
            2'd0: cpu_ok = cpu_ok + 1;
            2'd1: vid_ok = vid_ok + 1;
            2'd2: snd_ok = snd_ok + 1;
            default: ;
          endcase
        end else begin
          fails = fails + 1;
          if (fails <= 12)
            $display("*** MISMATCH @tick %0d: rd_addr=%06h expect=%06h owner=%b lp=%b ls=%b vbm=%b",
                     ticks, rd_addr[20:0], chk_expect, chk_owner,
                     raw_loadPixels, raw_loadSound, videoBusControl);
        end
        chk_pending = 1'b0;
      end

      // ---- classify the phase-2 tick ending NOW (FSM decides here too) ----
      if (ready && (phase == 3'd2)) begin
        if (_ramOE == 1'b0 || _ramWE == 1'b0) begin // a fetch is issued
          chk_pending = 1'b1;
          if (selectRAM && !_cpuAS) begin
            // CPU RAM access is address-valid: it must own the slot
            chk_expect = cpuAddr[21:1];
            chk_owner  = 2'd0;
            cpu_fetches = cpu_fetches + 1;
          end else if (raw_loadPixels) begin
            chk_expect = videoAddr;
            chk_owner  = 2'd1;
            vid_fetches = vid_fetches + 1;
          end else if (raw_loadSound) begin
            chk_expect = audioAddr;
            chk_owner  = 2'd2;
            snd_fetches = snd_fetches + 1;
          end else begin
            chk_pending = 1'b0; // no recognizable owner - skip check
          end
        end
      end

      ticks = ticks + 1;
      if (ticks == RUN_TICKS) begin
        $display("===================================================");
        $display("ticks=%0d  cpu-fetches=%0d ok=%0d  video-fetches=%0d ok=%0d  audio-fetches=%0d ok=%0d",
                 ticks, cpu_fetches, cpu_ok, vid_fetches, vid_ok, snd_fetches, snd_ok);
        $display("MISMATCHES: %0d", fails);
        if (fails == 0 && cpu_fetches > 0)
          $display("RESULT: PASS - every CPU RAM access wins its phase-2 SDRAM slot");
        else if (fails > 0)
          $display("RESULT: FAIL - %0d fetch(es) not serviced for the requesting owner", fails);
        else
          $display("RESULT: INCONCLUSIVE - no CPU fetches observed");
        $display("===================================================");
        $finish;
      end
    end
  end

  initial begin
    reset = 1;
    repeat (10) @(posedge clk);
    reset = 0;
    wait (ready);            // sdram init done (31 cycles)
    repeat (4) @(posedge clk);
    // deassert the fake CPU read after the first half (CPU idle; video only).
    // Off-set from clock edges to avoid decode races.
    #(5*CPU_OFF + 2);
    _cpuAS = 1'b1;
  end

endmodule
