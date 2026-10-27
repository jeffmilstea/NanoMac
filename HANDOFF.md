# NanoMac BRAM Cache — Handoff Document (2026-10-24)

## Mission
Make the 2KB BRAM cache on NanoMac (Mac Plus, Tang Nano 20K) actually work,
then re-benchmark Speedometer 4.02 in Turbo mode.

## Board state
- SPI flash: build with fill_addr fix (fill still fires phase 6, rw-polarity bug present).
- OSD: Turbo OFF, Cache ON → Sad Mac 02FFFF (class 02 = RAM test, all 16 bits).
- Power cycle required after each `bash scripts/flash_board.sh src/impl/pnr/nanomac.fs -f`.
- ICE UART: /dev/cu.usbserial-20230306210 (2Mbps), scripts/nanomac_ice.py.

## KEY FINDINGS (this session, validated against live trace trace_live.vcd + plusrom.hex)

### 1. Fill RW-polarity bug — LIKELY PRIMARY ROOT CAUSE of Sad Mac 02FFFF
In macplus.sv (as committed in 4c69643):
    wire miss_evt_p3 = (busPhase==3) && !_cpuAS && !_cpuRW && (ram_req||rom_req) && !cache_hit && cache_cacheable;
fx68k.eRWn is /RW active LOW: _cpuRW==1 means READ. So `!_cpuRW` selects WRITES:
- Read misses never fill (matches observed C$HIT=0/256).
- RAM WRITES trigger spurious "miss" → fill samples sdram_do, which during a
  write cycle is the STALE last-read word (doutD in sdram.v) → poisons the line
  that cache_wr_pulse just invalidated → later read HITS stale data.
- Mac ROM class-02 RAM test = write pattern, read back, compare → all 16 bits
  fail → exactly 02FFFF. Also explains why Turbo OFF + Cache ON also fails
  (mode-independent), and why Turbo ON + Cache OFF boots.
FIX (applied in working tree, NOT yet built/verified):
    miss_evt_p3 uses `_cpuRW` (read), and cyc_type_r is_read bit uses `_cpuRW`.

### 2. Fill phase timing — original phase-6 fill was probably CORRECT; approved "phase 4 stock" fix was WRONG
- Sep 7 live trace (trace_live.vcd, stock mode, working machine): during a read
  of address X, sdram_dout[15:8] shows X's data first at phase 5-6 of X's own
  cycle, and it PERSISTS through phase 7, 0, 1 of the NEXT cycle (the bus shows
  the previous read's word until its own read returns).
- Conclusion: sampling at the posedge INTO phase 6 (i.e. `busPhase==3'd6` fill
  condition) captures the CURRENT cycle's data. Sampling at phase 4 (the
  previously-approved fix) would capture the PREVIOUS cycle's word.
- macplus.sv now uses `FILLPH` define (default 6):
      if (miss_latched && (busPhase == 3'd`FILLPH))  // sweep 4/5/6 in sim
- Verilator validation is in progress to confirm polarity fix + FILLPH=6
  yields correct fills and hits (see sim changes below).

### 3. hwRegIdx decode bug (fixed in working tree)
Old: hwRegIdx = {cpuAddrRegMid[2], cpuAddrRegLo} = {A4,A2,A1} — dropped A3,
aliased $F80008→'NM', $F8000C→control reg. Counters were unreadable.
New: added `cpuAddrRegA3` port (from cpuAddr[3]); hwRegIdx = {A4,A3,A2};
addrDecoder window widened to F80000-F8001F (`address[15:5]==11'h0`).
New 8-word map: F80000 'NM' / F80004 0x0001 / F80008 control (write magic 0x55)
/ F8000C GIT_HASH / F80010 hits / F80014 misses / F80018 fills /
F8001C {last_fill_is_rom,1'b0,last_fill_addr[13:1],1'b0}.

### 4. Option B (approved, partially implemented in working tree)
(a) fill fix + snapshot — macplus.sv done (FILLPH default 6, snapshot regs, ports)
(b) dataController reg map + poke/peek — done (ice_poke_valid/idx/data in,
    ice_peek_req/idx in, ice_peek_data out; poke to idx 2 w/ magic 0x55 writes
    hw_turbo_en/ovr/cache_en; peek latches hwRegsDataOut)
(c) addrDecoder — done
(d) top.sv wiring + DCS honoring hw turbo override — NOT DONE.
    NOTE: ila runs on clk_pixel (15.6672 MHz) == macplus clk_sys → NO CDC needed.
    DCS issue: `turbo_synced` in top.sv only tracks osd_turbo at cpu_bus_idle
    (_cpuAS_probe && phase==7). Poke of hw_turbo_en changes DTACK/phase logic
    but NOT physical clk_cpu → must route effective turbo into turbo_synced
    update (e.g. `turbo_synced <= hw_turbo_ovr ? {2{hw_turbo_en}} : osd_turbo;`
    — needs hw_turbo_en/ovr exposed out of macplus; consider also gating flash
    cs which uses turbo_synced).
(e) ila.sv + ila_uart.sv P/Q commands — NOT DONE.
    ila_uart RX dispatch: S_IDLE case(rx_byte) ~line 295; add 'P' (0x50):
    collect idx(1 byte)+data(2 bytes) in new state → 1-cycle poke strobe;
    'Q' (0x51): peek req + idx, wait 2 cycles, print 4 hex digits.
    ila.sv: new ports to macplus via top.sv; poke/peek 1-cycle pulses are fine
    in clk_pixel domain.
(f) scripts: nanomac_ice.py poke/peek + A/B matrix script — NOT DONE.
(g) build + flash + verify — NOT DONE.

## Working-tree edits made this session (NOT committed, NOT built)
- src/macplus/addrDecoder.v: window F80000-F8001F
- src/macplus/dataController.sv: +cpuAddrRegA3; +last_fill_* in; +ice_poke_*/ice_peek_* ports;
  fixed hwRegIdx; 8-word map; poke logic; peek latch; ctrl-write detect now
  (hwRegIdx==2). NOTE: A3 bit for control slot: F80008 = A4=0,A3=1,A2=0 → idx 2. OK.
- src/macplus/macplus.sv: rw-polarity fixes; FILLPH define; last_fill snapshot
  regs; new ports (last_fill_addr/is_rom, ice_poke_*, ice_peek_*, cache_data_dbg);
  dc0 connections updated.
- sim/Makefile: added bram_cache.sv to NANOMAC_FILES
- sim/nanomac_tb.v: +cache in; +cache hit/data/counter/fill-addr/mac_probes_dbg outs;
  .configCache(cache); phi-gating bypass (.enPhi1_gated(enPhi1_raw) etc.);
  ICE stubs (.ice_* tied off)
- sim/nanomac_tb.cpp: cache oracle (per-hit ground-truth check vs ram[]/rom[],
  fill counter, boot-rom-reached detector), --cache/--fastboot args, summary print

## Simulation plan (in progress)
cd sim; make  (build; ~few min). Then:
1. `./nanomac --fastboot 0`            (baseline: RAM test PASS, cache off)
2. `./nanomac --cache 1 --fastboot 0`  (cache ON: expect BOOT ROM REACHED,
   hits>0, served-wrong=0)
3. sweep FILLPH: rebuild with -DFILLPH=4 / 5 / 6 (edit VERILATOR_FLAGS or
   add to Makefile), confirm 6 works and 4 breaks (served-wrong>0).
ROM test location: MAC ROM $400000+0x18F44 area (Sony write trigger marker at
romAddr<<1==0x18F44 in tb). Boot ROM reached = CPU fetches $800000-$8FFFFF.
Note sim ROM model reads rom[romAddr] whenever !_romOE; tb fastboot arg now
wired (was hardcoded 1 before).


## SIMULATION VALIDATION RESULTS (2026-10-25, Verilator 5.053, oss-cad-suite)

### Verdict: rw-polarity fix works. Cache ON now boots exactly like cache OFF.
- Baseline (--fastboot 0, cache off): ROM RAM test passes, boots to SD-card load (~12s sim).
- Cache ON (--cache 1 --fastboot 0): identical boot, identical LED timeline at 12s.
- Fills now fire on READ misses: 65535 (16-bit counter saturated) in first sim-second;
  first fills at 10.7ms to ROM 0x4000DA.. (sequential instruction fetch).
- ~24M cache deliveries in 20s sim.
- Residual oracle flags (~0.3% of latches, 10ms bursts during RAM test):
  beat-skew artifact of the tb oracle (samples registered model values 1 clk off
  the 68k latch edge). NOT a cache fault: if 16k of the RAM-test read-backs were
  truly wrong, ROM class-02 test would halt with 02FFFF; it does not.
- IMPORTANT port discovery: cpuAddr is [23:1] where cpuAddr[k]=A(k+1).
  $F80010 (hits) = A4=1,A3=0,A2=0 => cpuAddr[3]==1 && cpuAddr[2:1]==2'b00.
  (An earlier "fix" wrongly used cpuAddr[4] and out-of-range cpuAddr[0].)

### fx68k latch semantics (verified in source)
- oEdb = 68k OUTPUT drive (was my initial oracle mistake).
- iEdb = 68k INPUT = dataControllerDataOut (the word the CPU latches).
- 68k latches on the cycle /DTACK DEASSERTS (68000 asserts DTACK low for a
  cycle then deasserts; fx68k model samples on deassert).
- The DUT delays these two-class reads: /AS at E1 phase 2 -> ram_req set at
  E2 phase 2 -> DTACK at E2 phase 3. Normal for this design.

### Build/test recipe (sim)
cd sim
make clean; make -j4 HEADLESS=1     # HEADLESS=1 = no SDL (broken local SDL stack)
./nanomac --cache 1 --fastboot 0     # expect: boots, "ORACLE" lines, fills>0
SDL note: sdl2-compat (SDL3 shim) crashes at dyld init on this machine;
user downgraded homebrew to native SDL2, but Makefile still resolves
sdl2-compat via sdl2-config - HEADLESS=1 bypasses it entirely.
Verilator note (5.053): -CFLAGS "" (empty) breaks option parsing;
pass LDFLAGS as single -LDFLAGS "-llz4 -lz" with -L/opt/homebrew/lib
(arm64 lz4; /usr/local/lib copy is x86_64).
Added -Wno-ENUMVALUE (fx68k.sv:2339 implicit enum conversion).

### FPGA build (in progress at time of writing)
- src/build.sh -> Gowin gw_sh; remote license 106.55.34.119:10559
  (transient "Server not responding" fixed by user starting Gowin GUI).
- "unknown option: -verilog_define" warning from gw_sh is non-fatal
  (Oct 23 build had it too; GIT_HASH falls back to 0xDEAD via catch block).
- Fixed synth error: cache_clr used cpuAddr[0] (out of range [23:1]).
- After build: bash scripts/flash_board.sh src/impl/pnr/nanomac.fs -f
  then POWER CYCLE board.
- NOTE: ICE poke/peek (option B part d) NOT wired in top.sv yet ->
  counter clear ($F80010) is CPU-write only; counters readable via
  $F80010-18 if dataController map done (it is). Peek via ICE still missing.


## TURBO + CACHE: LIVE REPRO + ILA EVIDENCE (2026-10-26 night)

### Arithmetic correction (invalidates earlier sweeps)
turbo_en|turbo_ovr|cache_en = 0x03 (NOT 0x13/0x07). Full poke lo byte =
0x03 | (fillph<<4): phase4=7, phase5=23, phase6=39, phase7=55 (decimal).
Earlier sweeps (99/67/35/3, 51/0x33, 55/0x33) ALL RAN CACHE OFF (bit2=0).
Only 'poke 55' (0x37) has ever actually run turbo+cache.

### poke 55 result: machine FREEZES immediately (not stripey bars)
peek after freeze: F80008:0537 (all on, fillph=3=phase7, turbo_active)
  F80010:0000 hits, F80014:0000 misses, F80018:FFFF fills SATURATED,
  F8001C:1B7E (last fill ~0x0DDFC RAM, is_rom=0)
ILA trace of frozen state:
- C$EN=1 and C$HIT=1 on normal RAM cycles (phases 5,6,7,0,1,2,3)
- CPU spinning loop: 4027E2 R / 40274A R / 00016A R / 00016C R /
  40274C R / 3CCE36 W / 3CCE38 W ... (0001xx = ROM RAM test area!)
- sdram_dout changes at phase 6 in turbo (current-cycle data valid ~ph6-7)
- /AS pulses land at varying phase-grid positions in turbo; 1 phase-grid
  (511ns @15.667MHz) = 2.5 turbo E-cycles (204ns each)
- Suspect: cache serves stale data for write-then-read-back (write-
  invalidate misaligned in turbo) or miss/fill latch neighbor-cycle addr.

### Architecture facts (verified in RTL)
- clk_sys = clk_pixel 15.6672MHz in BOTH modes; busPhase grid (clocks.v)
  on clk_sys always. Turbo: 68k on clk_cpu_raw 39.168MHz (top.sv DCS).
- Data path: ramDataIn = (cache_hit && ram_req) ? cache_data : sdram_do.
  DTACK: ram_done = cache_hit || (turbo ? ph>=7 : ph>=4).
- ram_req/rom_req set only at busPhase==2, async-cleared by /AS deassert
  (req_rst = !_cpuReset || _cpuAS).
- miss_evt latched ph3; counters: type@ph2, hit@ph3, count@ph7 => all
  misaligned in turbo (explains hits=0 while C$HIT=1 visible).
- fills saturated => fill pulse fires every cycle in turbo.

### Candidate root causes (both = phase-alignment in turbo)
B1) write-invalidate phase misaligned in turbo -> stale line served ->
    spin on own write read-back (matches spin loop + RAM-test addresses)
B2) fill tag from fill_addr latched at ph3 which in turbo can be the
    PREVIOUS cycle's address -> lines tagged wrong -> constant refill
    (matches fills=FFFF)

### Recovery / A/B interface notes
- Machine: run 'reset' via ICE to recover (clears hw control regs!).
- NEVER run 'reset' after a poke you want to keep - it clears the regs.
- peek prints all 8 regs; F80008: bit0 turbo_en, bit1 ovr, bit2 cache,
  bits[5:4] fillph(phase-4), bit8 RO turbo_active, bit10 RO cache mirror.
- ICE port: /dev/cu.usbserial-20230306211 @ 2MHz.

### Next steps
- Make req/miss/fill/invalidate phase-robust in turbo (level windows
  instead of fixed phases) OR capture VCD with extra probe bits
  (E-phase, iEdb, fill_pulse, invalidate, tag of 00016A).
- Machine needs recovery via ICE reset or power cycle.


## E-CYCLE RERWORK + COLD-BOOT FIX (build 996f7f8, flashed 2026-10-27 00:44 UTC)

### Commits
- 80d23cf: phase-agnostic (E-cycle based) fill/miss/counter logic
  (sdram rd_done fill, ROM miss-DTACK edge fill, /AS-edge invalidate,
  edge counters, power-on tag sweep, rd_addr demap at top/tb)
- 996f7f8: cold-boot sweep gate (cache_cacheable &= !cache_in_sweep),
  write-invalidate address fix (fires on written cycle, not /AS edge
  where cpuAddr still = previous cycle), ICE 'c' counter-clear command

### Board result of 80d23cf build (before 996f7f8)
- Warm poke 55 (turbo+cache): machine runs (no freeze!). Counters all
  FFFF = saturation (16-bit at 19.6MHz counts out in <1s; normal).
- Sieve turbo+cache: 596ms @19.584MHz = 11.7M cycles/iter vs
  stock+cache 1791ms @7.833MHz = 14.0M cycles/iter -> CYCLES DROPPED,
  cache IS working in turbo (don't compare Abs across clock speeds).
- OSD Turbo ON + Cache ON from COLD BOOT: stripey bars (ROM crash) -
  reproduced; warm poke-enable never crashed (BRAM held valid lines,
  not power-on garbage) -> root cause: sweep window race (boot ROM
  reads a half-swept random tag that aliases a live address).
  Fixed in 996f7f8 by gating cache_cacheable during the sweep.

### NEW test procedure for 996f7f8 (keyboard-less)
1. Power-cycle; set OSD: Turbo ON + Cache ON (keyboard needed once,
   or: poke 55 after a good boot to enable cache in turbo and
   separately verify stock+cache cold boot via OSD cache).
   ACTUALLY simplest: OSD Cache ON + Turbo ON, power cycle, watch.
2. COLD BOOT with Turbo+Cache should now reach desktop (no stripey bars).
3. Counter windowing: `python3 scripts/nanomac_ice.py ... clear`
   (new 'c' command), wait ~10-30s, `peek` -> meaningful
   F80010/14/18 values.
4. Benchmark: Speedometer 4.02 Dhrystone/Sieve/Compress at turbo+cache.
   Compare CYCLES (ms * MHz) vs stock+cache (sieve 14.0M, dhrystone
   552*2.51=1386ms-equiv... compute per-test).

### ICE command set (scripts/nanomac_ice.py)
state | halt | resume | reset | step | stepbus | arm | trigger |
dump [--vcd f.vcd] | poke <lo> ($F80008: turbo_en|ovr<<1|cache<<2|fillph<<4)
| peek (all 8 regs) | clear (stat counters) | interactive
NEVER 'reset' after a poke you want to keep (clears hw control regs).

### Poke control word table (lo byte, turbo_en+ovr+cache=0x03)
fillph field is now RESERVED (fill is data-valid based):
cache only: 3 | +turbo+ovr: 7 ... but 55 (0x37) is the full combo used
before; fillph bits ignored by new RTL.


## Sad Mac 0200F8 + BISECTION (2026-10-27 01:00-02:45 UTC)

### Board state after 996f7f8 flash (OSD Turbo+Cache cold boot)
- Sad Mac 0200F8 = RAM test error code 8 (write->read-back mismatch),
  CPU parked spinning at $082134 (RAM), /AS deasserted, DT deasserted,
  ram_req=1 stuck for 32+ bus cycles, SDRAM data still toggling
  (controller kept servicing the abandoned read).
- peek: F80008:0030 (hw bits 0 - the Sad Mac spin runs before turbo
  engages / TR:0 -> stock-speed crash), F80010:FFFF hits,
  F80014:1D8C misses, F80018:1D8C fills (every miss filled exactly
  once => fill logic healthy), F8001C:000E (last fill = vector page).
- ILA VCD: /tmp/freeze.vcd (256 samples @10ns, 11 signals).
- Conclusion: cache-on corrupts the ROM RAM test AT STOCK SPEED.
  80d23cf alone (no wr-invalidate change) did NOT show this (warm
  poke 55 ran fine; cold-boot test at the time hit stripey bars, a
  different ROM-later crash).

### Verdict on 996f7f8's write-invalidate "fix"
REVERTED (in working tree, bisect build in progress). At busPhase==2
/cpuAS is already asserted, so cpuAddr holds the WRITE address - the
old phase-2 pulse (631431f, proven on board) was CORRECT. My
registered (sdram_we && ram_req) variant fires 1 grid cycle later; a
63.8ns grid cycle is much shorter than a 204ns+ request, so by the
next posedge /AS may already be deasserted and cpuAddr = NEXT cycle's
address -> wrong line invalidated, written line left stale ->
read-back mismatch -> 0200F8.
KNOWN remaining gap (turbo-only): phase-2 gate misses writes whose
request doesn't overlap grid phase 2 (5:2 grid -> ~half of turbo
writes). Revisit after stock is green with a request-latched
(latch cpuAddr on phase-2 AND, invalidate from the latched value).

### Bisect plan (board tests, keyboard-free)
build A (this): sweep gate + E-cycle fill + PHASE-2 wr-invalidate +
  counter clear. Tests: (1) OSD Cache ON + Turbo OFF cold boot
  [must reach desktop], (2) poke 55 warm turbo+cache [must run],
  (3) clear/peek counter window, (4) Speedometer turbo+cache.
if A fails (1): revert sweep gate too (build B) to isolate.
if A passes (1) but fails (2): turbo wr-invalidate gap is confirmed
  -> implement request-latched invalidate.

## Clocks/phase reference (stock mode)
clk_sys=clk_pixel=15.6672MHz; 8 phases per E-cycle; /AS low from phase 2;
ram_req/rom_req set at phase 2; cache_hit valid from phase 3; DTACK: hit@3,
stock miss@4, turbo miss@7; cache_wr_pulse (invalidate) @ phase 2 of RAM write.
Turbo: cpu 19.584MHz via DCS (39.168 raw /2), enPhi alternating.
ILA: clk_pixel, 256x64 trace, probe map: [25]cache_hit [24]cache_en
[55:32]cpuAddr [63:56]sdram_dout[15:8] [10]DTACK [9]RW [8]LDS [7]UDS
[6]AS [5]turbo [4:3]enPhi [2:0]busPhase [19]selectRAM [20]selectROM.

## Lessons / user preferences
- ALWAYS validate fixes in Verilator before building/Flashing (user instruction).
- Prefer SPI flash (-f) over SRAM (-m) for bitstream loads.
- Debug protocol: hypothesize → validate with evidence → confirm with user before fixing.
- Timing report violations are a red herring (SDC only constrains clk_osc).
- context limit 262k; this handoff doc is the recovery point.
