// tb_mirror.sv
//
// Oracle for the Mac Plus A23-RAM mirror ($800000-$BFFFFF) and the
// vector-table mirror ($FFFFF0-$FFFFFE = first 8 RAM words) in the
// NanoMac address decode.
//
// Background (board evidence, /tmp/hang3_freeze_trig.vcd, 2026-11-04):
//   The genuine System ROM crash handler (reached after a first
//   exception ~1 min after cache enable) uses both windows:
//     - long read at $8FF000 (crash-log scratch in the A23 mirror)
//     - read-modify-write pairs at $FFFFF6/$FFFFF8/$FFFFFA/$FFFFFC/
//       $FFFFFE (vector installs through the vector mirror)
//   NanoMac's addrDecoder (since the initial commit) decodes both
//   windows as "select nothing": reads return stale SDRAM bus data
//   (often video words), writes vanish -> the handler runs blind ->
//   corrupted jump -> hard park (the cache-on freeze).
//
// Expected decode (real Mac Plus map):
//   $800000-$BFFFFF      -> RAM, word = cpuAddr[21:1] (A23 alias; the
//                           addrMux term cpuAddr[21:1] already drops
//                           A23/A22, so no remap is needed)
//   $FFFFE0-$FFFFFF      -> RAM, word = cpuAddr[4:1]  (words 0..15, the
//                           32-byte interrupt vector table, vector n at
//                           $FFFFE0+4n)
//   everything else      -> unchanged (ROM/SCC/VIA/IWM/HW-reg windows)
//
// The test drives a fake 68k that holds each test address with /AS low
// for 96 grid ticks (12 E-cycles), then /AS high. While /AS is low the
// checker verifies:
//   - the expected select* (and no DOUBLE select of a second window)
//   - for RAM: ramAddr == expected word (checked on grid ticks where
//     the video/audio DMA is not using the mux, i.e. !loadPixels &&
//     !loadSound, so the mux shows the CPU word), and _ramOE/_ramWE
//     polarity (read: _ramOE low; write: _ramWE low).
//   Each RAM case must see >=4 valid samples (guarantees the check is
//   not vacuous given the drifting video grid).
//
// Build/run (from sim/):
//   run_verilator -j 4 --timing --binary -Wno-lint -Wno-fatal \
//     -top-module tb_mirror \
//     ../src/macplus/clocks.v ../src/macplus/addrDecoder.v \
//     ../src/macplus/videoTimer.v ../src/macplus/addrController.v \
//     tb_mirror.sv -Mdir obj_mirror
//   ./obj_mirror/Vtb_mirror
//
// Expected on UNFIXED RTL: FAIL (all mirror cases: selectRAM never
// asserts; ramAddr stays on the video/audio path or garbage).
// Expected on FIXED RTL: PASS, all cases.

`timescale 1ns/1ps
module tb_mirror;

  localparam ACC_TICKS  = 96;   // /AS-low window per case (12 E-cycles)
  localparam GAP_TICKS  = 16;   // /AS-high gap between cases
  localparam MIN_CHECKS = 4;    // min non-DMA samples required per RAM case

  localparam SEL_RAM = 3'd0, SEL_ROM = 3'd1, SEL_SCC = 3'd2,
               SEL_VIA = 3'd3, SEL_HW  = 3'd4, SEL_NONE = 3'd5;

  reg clk = 0, reset = 1;
  always #5 clk = ~clk;

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

  // fake 68k
  reg [23:1] cpuAddr = 23'h0;
  reg        _cpuAS  = 1'b1;
  reg        _cpuRW  = 1'b1;   // 1 = READ
  reg        _cpuUDS = 1'b1, _cpuLDS = 1'b0;

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
    .configRAMSize(2'b11),      // 4MB: full A23 mirror window $80-$BF
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
    .video_dma_off(1'b0),
    .refresh(refresh)
  );

  // raw (pre-arbitration) DMA demand
  wire raw_lpx  = ac.vt.loadPixels;
  wire raw_lsnd = videoBusControl & ac.sndReqCycle;

  // ------------------------------------------------------------------
  // checker
  // ------------------------------------------------------------------
  integer fails = 0;
  integer case_idx = 0;
  integer case_checks = 0, case_ok = 0;
  reg [2:0]  case_sel = SEL_NONE;
  reg [20:0] case_word;
  reg [23:1] case_addr;
  reg        case_rwl = 1'b1;
  reg        case_active = 0;
  reg        case_warned = 0;

  function [23:1] s23(input [23:0] b);
    s23 = b[23:1];
  endfunction

  always @(posedge clk) begin
    if (!reset && case_active && !_cpuAS) begin
      // ---- never two primary windows at once (incl. new mirror windows)
      if (selectRAM && (selectROM || selectSCC || selectVIA || selectIWM ||
                        selectSCSI || selectHardwareRegs) && !case_warned) begin
        fails = fails + 1;
        case_warned = 1'b1;
        if (fails <= 10)
          $display("*** FAIL case %0d @%06X: DOUBLE SELECT (RAM + other)",
                   case_idx, {cpuAddr[23:1],1'b0});
      end

      // ---- the expected select must be the one (and only) primary
      if (case_sel == SEL_RAM) begin
        if (!selectRAM) begin
          if (!case_warned) begin
            fails = fails + 1;
            case_warned = 1'b1;
            if (fails <= 10)
              $display("*** FAIL case %0d @%06X: selectRAM never asserts",
                       case_idx, {case_addr,1'b0});
          end
        end
        else if ((selectROM || selectSCC || selectVIA || selectIWM ||
                  selectSCSI || selectHardwareRegs) && !case_warned) begin
          fails = fails + 1;
          case_warned = 1'b1;
          if (fails <= 10)
            $display("*** FAIL case %0d @%06X: RAM + other select",
                     case_idx, {cpuAddr[23:1],1'b0});
        end
        // ramAddr + strobe polarity (only when DMA/refresh isn't on the mux)
        if (selectRAM && !raw_lpx && !raw_lsnd && !(videoBusControl && refresh)) begin
          case_checks = case_checks + 1;
          if (ramAddr == case_word &&
              (case_rwl ? (_ramOE === 1'b0 && _ramWE === 1'b1)
                        : (_ramWE === 1'b0 && _ramOE === 1'b1)))
            case_ok = case_ok + 1;
          else if (fails <= 10) begin
            fails = fails + 1;
            $display("*** FAIL case %0d @%06X: ramAddr=%06X expect %06X oe=%b we=%b rw=%b",
                     case_idx, {cpuAddr[23:1],1'b0}, ramAddr, case_word,
                     _ramOE, _ramWE, case_rwl);
          end
        end
      end
      else begin
        // non-RAM cases: only the select identity matters
        case (case_sel)
          SEL_ROM: if ((!selectROM || selectRAM) && !case_warned) begin
            fails = fails + 1;
            case_warned = 1'b1;
            if (fails <= 10) $display("*** FAIL case %0d @%06X: expected ROM", case_idx, {case_addr,1'b0});
          end
          SEL_SCC: if ((!selectSCC || selectRAM) && !case_warned) begin
            fails = fails + 1;
            case_warned = 1'b1;
            if (fails <= 10) $display("*** FAIL case %0d @%06X: expected SCC", case_idx, {case_addr,1'b0});
          end
          SEL_VIA: if ((!selectVIA || selectRAM) && !case_warned) begin
            fails = fails + 1;
            case_warned = 1'b1;
            if (fails <= 10) $display("*** FAIL case %0d @%06X: expected VIA", case_idx, {case_addr,1'b0});
          end
          SEL_HW: if ((!selectHardwareRegs || selectRAM) && !case_warned) begin
            fails = fails + 1;
            case_warned = 1'b1;
            if (fails <= 10) $display("*** FAIL case %0d @%06X: expected HW-regs", case_idx, {case_addr,1'b0});
          end
          SEL_NONE: if ((selectRAM || selectROM || selectSCC || selectVIA || selectIWM ||
                         selectSCSI || selectHardwareRegs) && !case_warned) begin
            fails = fails + 1;
            case_warned = 1'b1;
            if (fails <= 10) $display("*** FAIL case %0d @%06X: expected NO select", case_idx, {case_addr,1'b0});
          end
          default: ;
        endcase
      end
    end
  end

  task run_case(input [23:0] a, input rw, input [2:0] sel, input [20:0] word);
    begin
      case_idx    = case_idx + 1;
      case_checks = 0;
      case_ok     = 0;
      case_warned = 1'b0;
      case_sel    = sel;
      case_word   = word;
      case_addr   = s23(a);
      case_rwl    = rw;
      case_active = 1'b1;
      cpuAddr = s23(a);
      _cpuAS  = 1'b0;
      _cpuRW  = rw;
      _cpuUDS = 1'b1;
      _cpuLDS = 1'b0;
      repeat (ACC_TICKS) @(posedge clk);
      _cpuAS = 1'b1;
      repeat (GAP_TICKS) @(posedge clk);
      case_active = 1'b0;
      if (sel == SEL_RAM) begin
        $display("case %0d A=%06X rw=%b: checks=%0d ok=%0d %s",
                 case_idx, a, rw, case_checks, case_ok,
                 (case_checks >= MIN_CHECKS && case_ok == case_checks) ? "pass" : "FAIL");
        if (case_checks < MIN_CHECKS || case_ok != case_checks)
          fails = fails + 1;
      end else begin
        $display("case %0d A=%06X sel=%0d: %s", case_idx, a, sel,
                 (fails == 0) ? "pass" : "checked");
      end
    end
  endtask

  initial begin
    reset = 1;
    repeat (10) @(posedge clk);
    reset = 0;
    repeat (8) @(posedge clk);

    // ---- low RAM (existing behavior, sanity) ----
    run_case(24'h000000, 1'b1, SEL_RAM, 21'h000000);   // vector 0 area
    run_case(24'h0FF000, 1'b1, SEL_RAM, 21'h007F800);
    run_case(24'h00000C, 1'b0, SEL_RAM, 21'h000006);   // vector 3 write
    // ---- A23 mirror: same word as the low address (RED on unfixed RTL) ----
    run_case(24'h8FF000, 1'b1, SEL_RAM, 21'h007F800);  // == $0FF000
    run_case(24'h8FF002, 1'b1, SEL_RAM, 21'h007F801);  // == $0FF002
    run_case(24'hAFFFFE, 1'b1, SEL_RAM, 21'h017FFFF);  // == $2FFFFE (A23 mirror)
    run_case(24'h8FF000, 1'b0, SEL_RAM, 21'h007F800);  // write (handler scratch)
    // ---- vector mirror $FFFFE0-$FFFFFF (RED on unfixed RTL) ----
    // vector n word = n>>1; vector 6 = A-line, vector 7 = illegal-instr
    run_case(24'hFFFFE0, 1'b1, SEL_RAM, 21'h000000);   // vector 0 (reset)
    run_case(24'hFFFFE6, 1'b1, SEL_RAM, 21'h000003);   // vector 3
    run_case(24'hFFFFEE, 1'b1, SEL_RAM, 21'h000007);   // vector 7
    // the handler's actual observed RMW targets:
    run_case(24'hFFFFF6, 1'b1, SEL_RAM, 21'h00000B);   // vector 6 lo (A-line)
    run_case(24'hFFFFF8, 1'b1, SEL_RAM, 21'h00000C);   // vector 6 hi
    run_case(24'hFFFFFA, 1'b1, SEL_RAM, 21'h00000D);   // vector 7 lo (illegal)
    run_case(24'hFFFFFC, 1'b1, SEL_RAM, 21'h00000E);   // vector 7 hi
    run_case(24'hFFFFFE, 1'b1, SEL_RAM, 21'h00000F);   // vector 8 (sys trap 1)
    run_case(24'hFFFFF8, 1'b0, SEL_RAM, 21'h00000C);   // vector-6 install RMW
    run_case(24'hFFFFFC, 1'b0, SEL_RAM, 21'h00000E);   // vector-7 install RMW
    // ---- just outside the window must NOT be RAM (regression) ----
    run_case(24'hFFFFC0, 1'b1, SEL_NONE, 21'h0);   // A5=0: below the vector window
    run_case(24'hFFFFE0, 1'b0, SEL_RAM, 21'h000000); // window start: write (reset vector)
    // ---- regression: other windows must be untouched ----
    run_case(24'hF80008, 1'b1, SEL_HW,  21'h0);
    run_case(24'h400040, 1'b1, SEL_ROM, 21'h0);
    run_case(24'h9FFFFC, 1'b1, SEL_SCC, 21'h0);        // SCC Read
    run_case(24'hBFFFF8, 1'b0, SEL_SCC, 21'h0);        // SCC Write ($BFFFF9/$BFFFFB mouse IRQ enable!)
    run_case(24'hE80000, 1'b1, SEL_VIA, 21'h0);

    repeat (8) @(posedge clk);
    $display("===================================================");
    $display("MIRROR ORACLE fails=%0d", fails);
    if (fails == 0)
      $display("RESULT: PASS - A23 mirror + vector mirror decode correctly");
    else
      $display("RESULT: FAIL - %0d problem(s)", fails);
    $display("===================================================");
    $finish;
  end

endmodule
