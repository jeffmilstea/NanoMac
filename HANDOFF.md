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


## SESSION END NOTE (2026-10-27 21:00 UTC) - HONEST STATUS, READ THIS FIRST

### What is SOLVED / VERIFIED
- Sim stock regression clean (5865 oracle flags = known tb artifact,
  identical to cache-off baseline).
- Commit 6f79470 boots clean on the board: stock+cache cold boot
  (user-confirmed after flash), warm poke-55 turbo+cache (runs, no
  freeze), OSD turbo on/off both work.
- No Sieve regression: 3-iter Abs 596.871 (Oct23) vs 596.993 (Oct27,
  current build, cache ON, stock) = 0.02%. The "1791.8" figure is
  Speedometer's 1-iteration Abs (= 3x the 3-iteration Abs). User's
  Oct25 "~3x previous!" note was the same artifact.
- Cache counters saturate (FFFF) - high hit rate confirmed; `clear`
  ICE command works ("[Cache counters cleared]").

### What is NOT SOLVED (open, fresh bug)
OSD Turbo OFF + Cache ON (set in OSD, saved, power cycle) -> machine
FREEZES immediately, reboot -> stripey bars. Captured frozen state:
- peek: F80008:0030 (hw override bits all 0, fillph default, turbo RO
  bit 0) => NO poke was involved; this is the pure OSD config path.
- CPU spinning at $08011A-$080120 reading 0xCC33 pattern, write to
  $003E38 => ROM RAM-test / error region spin (same class as the
  0200F8 and FF8CFC spins).
- ILA C$EN (cache_cacheable) = 0 in EVERY sample of the spin.
  So during the spin either (a) the spin addresses are not
  selectRAM/selectROM (C$EN legitimately 0), or (b) configCache/osd_cache
  is not reaching macplus. NOTE: C$EN=0 in a spin loop at $08xxxx
  (RAM) would be a RED FLAG that configCache is 0.
- sysctrl.v line 340: `if(id == "C") system_cache <= data_in[0];`
  under CMD 4; top.sv: .system_cache(osd_cache) -> .configCache(osd_cache).
  UNVERIFIED: whether the osd_cache reg in sysctrl is RESET-CLEARED and
  whether the MCU actually persists+sends it on boot (OSD values are
  MCU RAM/flash state - if not restored on FPGA boot, configCache=0
  from power-up until the MCU re-sends it, i.e. cache is OFF during
  the earliest boot = this exact crash signature).
  ALSO UNVERIFIED: cache_en_cfg 0->1 edge triggers the 1024-line
  invalidation sweep; if osd_cache rises MID-BOOT (when the MCU
  re-sends it) the sweep + late-enable interacts with boot ROM in a
  way that has never been tested (warm poke-55 tested it at desktop,
  not during boot).
- The previous-session claim "boots clean in all four mode combos"
  was NEVER verified for OSD stock+cache cold boot. It fails.

### Prime suspect for the OSD cold-boot crash
osd_cache timing: configCache goes 0 during early boot (MCU not yet
restored) then 1 mid-boot -> cache_in_sweep sweep fires mid-boot,
OR the crash happens in the window BEFORE osd_cache rises, during
which the ROM RAM test runs with cache OFF (fine) - so the crash
may actually be the MCU not persisting 'C' at all and the user
seeing a pre-existing stock crash... BUT user says stock-only boots
clean, so configCache=1 must be doing something. Needs: (1) add
configCache/osd_cache/sweep-active to the ILA probe bundle, (2)
capture the FAILED cold boot from t=0 (arm before power-up is
impossible; instead power cycle WITH dump buffer pre-armed and
check first samples), or (3) simplest bisection: poke 4 (0x04 =
cache_en only, no turbo) on a GOOD stock boot to enable cache via
hw path and see if THAT also crashes (isolates OSD config path vs
cache-enable-during-boot).

### Rules for the next session (learned the hard way)
1. NEVER claim a board state was "verified" unless the user
   explicitly confirmed it in this session.
2. Never import expectations (e.g. "turbo should be 2.5x in
   Dhrystone") - ground every claim in manual_benchmarking.txt
   data. Dhrystone has ALWAYS been ~569 in every mode, always.
3. Speedometer Abs is NOT normalized across iteration counts:
   1-iter Sieve Abs = 3x 3-iter Sieve Abs. Match iterations!
4. The "19.6Mhz" label in Speedometer output is a mode flag, not a
   measured frequency. Rat (0.016) is identical across modes.
5. poke 6 (force turbo OFF mid-run) = instant lockup. Do not use.
6. ICE `reset` clears hw_* regs. OSD config is a separate path.

### Board state at session end
Flash contains 6f79470 (rebuilt+reflashed 20:55 UTC). Board is in
FAILED state (stock + OSD cache on, stripey bars on reboot).
Recovery: set OSD Cache OFF (or just cache off + turbo off), power
cycle -> boots clean.

## ILA UPGRADE (2026-10-31) — Configurable Trigger + Capture-Rotation + A/B Snapshot

### What was added (working tree, NOT yet built/flashed)

**Problem the upgrade solves:**
The poke-4 (stock + cache) repro freezes at the error-handler spin
($0001B0-$0001B4). To diagnose the root cause we need the *last good
cycles before the corruption* — i.e. a capture that triggers **exactly
when the CPU jumps into the error handler** and shows 64 samples of
context around it. The old ILA only supported:
- `arm` ('a') = always triggers on `_cpuAS` low (first bus cycle after
  arming — useless for a specific-address event),
- no way to configure the trigger address/mask from the UART (the SPI
  path had full trig_mode/trig_addr/trig_mask, but `ila_uart.sv`
  hardcoded mode 1 on arm),
- binary dump ('B') had no trigger-position marker, so the 256-sample
  circular buffer couldn't be rotated to put the trigger at sample 0.

**Changes (all in working tree, uncommitted, untested):**

1. `src/companion/ila_uart.sv` — new 't' command:
   `'t'` + 7 bytes: mode, addr[23:16..0], mask[23:16..0].
   Stored in `uart_trig_mode/addr/mask` regs (reset default: mode 1
   = _cpuAS low, addr 0x0001B0, mask 0xFFFFFF — identical to old 'a').
   On `arm`, `ila.sv` now copies all three into the ILA trigger FSM
   (previously only trig_mode, hardcoded to 1 by the UART layer).
   Also: 'B' binary dump now sends 1 header byte first = trigger_pos
   (8-bit circular position where trigger fired) so the host can
   rotate the dump to put the trigger sample at index 0.

2. `src/companion/ila.sv`:
   - arm copy now includes trig_addr + trig_mask (was mode only),
   - new wire `uart_trig_addr/uart_trig_mask` + ila_uart instantiation.

3. `scripts/nanomac_ice.py`:
   - new `trigset <mode> <addr> <mask>` command (mode 3 = addr match;
     mask bit=1 means CARE. Error-handler example for the 16-word
     window $0001B0-$0001BF: `trigset 3 0x0001B0 0xFFFFE0`.
     NOTE: 0x0001F0 is WRONG — it leaves the upper 15 bits don't-care
     and matches any address with bits[8:5]==0b11011 (fires on
     unrelated desktop RAM); learned on the board 2026-10-31),
   - `dump` reads the 2049-byte stream (1 trigger_pos header + 2048
     sample bytes) and rotates the circular buffer so sample 0 ==
     trigger point; also tolerant of old firmware (2048 bytes, no
     header),
   - `parse_sample` + VCD + table now decode the already-probed bits:
     [18] refreshCycle, [16] loadPixels (video DMA read) — the two
     signals needed to check "did a video/audio DMA read return
     foreign data that poisoned a cache fill?",
   - new `poked <lo>` command: poke the $F80004 identity word (RTL
     'T' cmd, ice_poke_idx 1) for A/B validation — RAM write
     landed iff peek shows $F80004 != 0x0001.

**Trigger modes (ila.sv trig_mode, v2):**
0=manual/force, 1=_cpuAS low (default), 2=_cpuAS && (selectRAM &&
video/audio DMA active), 3=_cpuAS && (addr & mask)==(trig_addr & mask).
(NOTE: v2 dropped the old mode 4; DTACK is no longer probed in the
v2 map so mode 2's dtack condition is folded into the RAM-collision
definition. Mode numbering at the UART level: `trigset <mode>` uses
the same 0-3 set as ila.sv trig_mode.)

**Probe map v2 (2026-11-01) — supersedes the old map below:**
[63:56] sdram_dout[15:8] data byte
[55:32] cpuAddr[23:0]            (trigger address space)
[31:11] sdram_rd_addr[20:0]      NEW: real SDRAM word addr the FSM read
[10]    turbo_active  [9] cache_hit  [8] cache_en
[7]     _cpuAS  [6] _cpuRW(1=READ)  [5] selectRAM  [4] selectROM
[3]     loadPixels  [2] loadSound  [1] videoBusControl  [0] cpuBusControl
cpu_rd is DERIVED in the script/host as: selectRAM && cpuBusControl &&
!loadPixels && !loadSound — i.e. the data/addr pair is a genuine CPU
read, not a video/audio DMA read of the shared SDRAM.
The OLD map (pre-v2) is no longer valid; do not reuse old VCDs.

**Why the trigger target is $4027E8 (NOT $0001B0):**
$0001B0 is a ROM error-handler entry in the $400000 ROM image, but the
CPU accesses it at $4001B0 / $4027E8 (ROM is mapped at $40xxxx). The
address the ILA trigger compares is the 24-bit cpuAddr. The actual
ROM spin loop `6104 7000 4E75 4EBA F1F0` sits at ROM offset $027E8,
i.e. cpuAddr = $4027E8. Triggering on the low 16-bit window $0001B0
collides with ordinary RAM-test data reads of $00xxxx addresses
(false positives seen on the board). Use:
    trigset 3 0x4027E8 0xFFFFF0   (16-word window around the spin)
This fired cleanly at the real error handler (capture3, pos=174).

**How the trigger plan works for the freeze diagnosis (v2):**
1. Boot clean (OSD Cache OFF, stock). `poke 4` to enable cache.
2. `trigset 3 0x4027E8 0xFFFFF0` — fires the instant the CPU fetches
   an instruction in the error-spin window.
3. `arm`, wait for freeze (~60-100s), `dump --vcd /tmp/poke4.vcd`.
4. In GTKWave (64ns per sample in v2): sample 0 = first error-spin
   fetch. 64 samples before = last correct cycles. Now that SADR
   (real SDRAM word addr) and cpu_rd are in the trace, distinguish:
   - a CPU read (cpu_rd=1) of a $00xxxx word where SADR/cpuAddr agree
     but data is wrong  -> genuine cache/SDRAM data corruption, OR
   - a video/audio DMA (loadPixels/loadSound=1) reading SDRAM in the
     same window  -> shared-bus collision hypothesis.
5. A/B `poked`/`peek` as a second, independent fault injection.

**2026-11-01 board captures:**
- capture1 (mask 0x0001F0): false trigger on desktop RAM $3F53B2.
- capture2 (mask 0xFFFFE0 on $0001B0): false trigger on RAM-test data
  read $0001B6 while ROM executed at $401AAA.
- capture3 (trigset 3 0x4027E8 0xFFFFF0, v1 map): CORRECT trigger at the
  error spin. Pre-trigger showed a sequential read sweep $00DB6DD8-
  $00DB6DE4 (rw=R, ram_cs=0, rom_cs=0, cache_en=0) just before the jump
  to the error handler — but with v1's probe map that sweep's cpuAddr
  vs sdram address couldn't be disambiguated (video DMA confound).
- capture4 (v2 map, trigset 3 0x4027E8 0xFFFFF0): whole 256-sample
  window is INSIDE the handler: ROM $402764-$4027F8 (display routine),
  screen-RAM writes $3E4DBA-$3E4DC6, low-RAM reg/data reads
  $00014C/$01BE54. No video/audio DMA in window. The faulting fetch
  is BEFORE sample 128 (outside the window) -> need an EARLIER trigger.

## 2026-11-01 MAJOR CORRECTION: the "5865 oracle artifacts" were ORACLE BUGS
The sim cache-oracle sampled the data bus at the DTACK ASSERT edge
(phase 4). The 68k (fx68k) latches iEdb at enPhi2, at/after DTACK
DEASSERT (~phase 7). On a stock MISS, at phase 4 the bus still holds
the PREVIOUS cycle's sdram_do (stale); the oracle's `delivered==
cachedata` guard mis-fires and flags "CACHE FAULT" against the newly-
written value. DEBUG_MEM evidence (word 0): RAM-test readbacks at
929.75x are 0001 -> FFFE -> 0001 -> FFFE -> 0001 (exactly what the
test wrote); `SDRAM READ 000400->00000000 = 10000` (upper half 0001)
is correct. The flagged "delivered=FFFE@000000 / 0001@080000" pair
was the same word's data 2 phases stale. Consequences:
- 5865 "bad" flags in every prior cache-ON run = oracle mis-sampling,
  NOT cache corruption.
- The 6GB "spin loop" in prior cache-ON sim runs was the machine at
  the DESKTOP (healthy), plus a GetTickCountMs 32-bit overflow in the
  "Speed factor" display.
- Oracle fix (nanomac_tb.cpp): sample on dtack 0->1 edge. (First fix
  overshot to next cycle -> hits=0; the correct tick is phase 7 of
  the access cycle: DTACK low, data valid for BOTH hit and miss.)
  [PENDING: finalize oracle edge, re-baseline, re-verify cache-ON sim
  shows bad=0 AND non-zero hits.]
- Sim verdict: cache-ON-from-t0 boots to desktop and idles healthy;
  RAM-test readback data verified correct via DEBUG_MEM.

## Board bug is BOARD-ONLY (sim does not reproduce, even in-scenario)
- Sim late-enable (cache 0->1 at 5000ms = desktop; --cache-late 5000):
  clean 62s+ post-enable, LEDs healthy, bad=0, no freeze.
- Board poke-4 (same scenario): freeze every time (~60-110s).
So the fault is NOT in the shared cache logic (bram_cache.sv fill/tag/
DTACK proven correct in sim). It must involve what the sim can't
model: real SDRAM (refresh/timing/signal integrity), real clock/PLL
behavior, or a board-only path (MCU/OSD config bounce during the poke,
hw_cache_en glitch, SD card, video). Note poke-4 passes F80008 through
the ICE path and triggers the 1024-cycle invalidate sweep — watch for a
race between sweep completion and a coincident video DMA / MCU
config re-send.

## capture5 (2026-11-01, trigset 3 0x402680 0xFFFFF0, entry trigger) — SUSPICIOUS
- dump reported pos=0 (trigger_pos was still the RESET DEFAULT 0 -> the
  trigger likely NEVER fired; the ILA stayed in ARMED and the ring
  scrolled). ALL 256 samples show the CPU DEAD: CA stuck $BE003E,
  AS:1 (no bus cycle), loadPixels flickering, sdram_addr scanning the
  video framebuffer ($1FB500-$1FD200) — pure video refresh, no CPU.
- So in this run the CPU died at $BE003E WITHOUT ever fetching the
  $402680 handler entry (or the trigger config never took effect).
  Either way the entry-trigger plan is UNVERIFIED — the trigger path
  itself needs a canary test before trusting any capture.
- ILA FSM (ila.sv ~240-275): ARM_PRE fills 64 samples, ARMED keeps
  writing the ring continuously until trigger_hit, then POST_FILL
  writes 192 more and stops. trigger_pos = wr_ptr AT trigger (8-bit),
  else stays 0 from reset. Host rotates dump so index 0 == trigger.
  If >256 samples pass before the trigger, pre-trigger context is lost
  (ring overwrote it) — but the post 192 remain valid.
- NEW SUSPICION to chase: CPU park address $BE003E with AS:1 — the
  CPU may hang before the error handler (no fetch at all), which no
  address-trigger can catch. A mode-1 (AS low) canary would catch any
  bus activity; if even AS never drops after the fault, the CPU
  stopped fetching entirely.

## SESSION 2026-11-02 (new): freeze is a HARD HANG; all triggers structurally blind to it

### Board canary on the STILL-FROZEN board (no power cycle needed)
- `state` x3 over ~1s: CPU parked A:BE003E, AS:1 in EVERY sample, D byte = video
  data (FF/66), SA (sdram_rd_addr) walking the framebuffer, TR:0, RM:0, RO:0.
  => the CPU is making ZERO bus cycles: this is a hard hang, not a spin.
- peek: F80008:0404 (poke-4 cache-on stock), F80010/14/18 all FFFF (saturated
  before death), F8001C:000E, F8000C:DEAD (GIT_HASH fallback).
- $BE003E decodes to SCC (addrDecoder.v casez 4'b10?1 -> selectSCC; $B=1011
  matches). A normal SCC access DTACKs immediately (io_done=1 in stock), so a
  CPU issuing $BExxxx cycles would show /AS pulsing — it does not. AS:1
  persistently means the 68k is NOT even starting cycles: stuck between
  instructions (corrupt PC/stack/vector, or a wedged interrupt path). $BE003E
  is the address the A-bus holds while idle — likely the corrupted PC or the
  target of an incomplete long JMP/exception.

### ROOT CAUSE of "capture5 trigger never fired"
- Ran mode-1 (AS low) canary live: trigset 1 0 0 + arm + dump -> pos=0,
  never fired, all samples AS:1. The trigger path (trigset -> arm ->
  trigger_hit -> trigger_pos) is VERIFIED GOOD (mode-1 fired correctly in
  earlier healthy captures).
- WHY it can never catch this fault: EVERY trigger mode in ila.sv
  (1=!_as, 2=!_as&&collision, 3=!_as&&addr_match) requires _as LOW. A
  hard-hung CPU never asserts /AS. So address triggers are USELESS for this
  freeze class. The $402680 entry trigger in capture5 was pointless IF the
  CPU hangs before/independently of the error handler — which the $BE003E
  dead-CPU state shows it does.

### FIX: ILA trigger mode 4 = CPU-bus-silence (hang) detect  [RTL DONE, sim-validated]
- src/companion/ila.sv: quiet_cnt counts consecutive samples with _as high
  (probes[7]), resets on any _as low. HANG_THRESH=192 samples (~12us) of
  total bus silence -> trigger_hit (mode 4). Reset on disarm/reset/arm.
- 192 is EVIDENCE-BASED: measured the healthy desktop max /AS gap in sim
  (new asGapMax tracker in nanomac_tb.cpp, cache off, 44s idle desktop):
  262 sim-ticks = 131 ILA samples (one event at desktop entry 13.175ms, never
  exceeded). 192 = 1.47x margin. Also <256 so after rotation the LAST CPU
  cycle before silence is at index 64 with 191 pre-hang samples.
  (An initial HANG_THRESH=128 would have FALSE-FIRED on a healthy desktop —
  caught before flashing.)
- Behavioral validation: sim/ila_hang_tb.sv (standalone Verilator TB driving
  the real ila+ila_uart via SPI CMD1/CMD3). RESULT: healthy pattern (gaps
  up to 180) does NOT fire; hang (AS high 260) fires at exactly quiet=192
  with non-zero trigger_pos. Build:
  verilator -j 4 --timing --binary -Wno-lint ... -top-module ila_hang_tb
    ../src/companion/ila.sv ../src/companion/ila_uart.sv ila_hang_tb.sv
  ./obj_dir/Vila_hang_tb   -> all PASS
- scripts/nanomac_ice.py: trigset 4 now documented (mode 4, addr/mask ignored).
- NOTE the ILA has NO sim coverage in nanomac_tb.v (companion not compiled in
  Verilator main sim) — hence the standalone TB above + Gowin synth as the
  final check. Companion changes are NOT Verilator-sim-validated against the
  full machine, only lint + standalone TB + synth.

### SIM ORACLE FINALIZED (the "5865 artifacts" saga closed)
- nanomac_tb.cpp cache_oracle now samples at PHASE 6 (not DTACK edges):
  phase==6 && !dtack && read && (ram_req||rom_req) && cache_hit -> compare
  cpu_data_in_dbg vs ground truth. Phase 7 = cycle end (/AS already up,
  selects cleared -> hits=0); DTACK-deassert edge overshoots into next cycle
  (the earlier "first fix"); phase 4 = stale data (original 5865 bug).
  Phase 6 = S7 latch state: data valid for BOTH hit (cache_data stable since
  ph3) and stock miss (sdram_do valid since ph6).
- Re-baseline (cache ON, fastboot 0): ORACLE bad=0, hits ~700k/s (1M by 1.1s
  after RAM test), fills saturate FFFF (16-bit), diagPh6NoHit=0 (on 100% of
  verified hits the cache actually drove the bus with the checked word).
- New asGapMax tracker in the same file (for HANG_THRESH sizing); desktop
  gap max = 131 ILA samples.

### MODE-4 REDESIGN: two-stage hang detect (board-calibrated 2026-11-02)
Single-level silence thresholds FAILED on the live board: HANG_THRESH=192
false-fired (pos=195, within ~15us of arm on a healthy desktop) and 160
false-fired too (pos=176). Authoritative live measurement
(scripts/measure_as_gap.py, ~4kHz /AS polling, 75s settled desktop): the
desktop 68k has RECURRENT /AS-deasserted silences of 10-12us (>=192
samples) between instruction bursts — so any threshold <=~4ms false-fires,
and any threshold >16.3us (ring width) loses the pre-hang context.
TWO-STAGE FIX in ila.sv:
  - HANG_CAND=192 silent samples -> new state ILA_CANDIDATE: FREEZE the ring
    (stop overwriting), trigger_pos = wr_ptr - 192 (position of the LAST CPU
    bus cycle). Any live /AS-low cycle aborts the candidate -> back to ARMED
    (ring resumes from the same pointer; harmless).
  - HANG_CONF=60000 silent samples (3.84ms, below the 65535=4.19ms
    quiet_cnt cap) -> ILA_DONE (confirmed hang). Healthy silence never
    exceeds ~1-2ms (VIA timer tick ~1ms releases the WAIT loop).
  On confirm: rotated dump index 0 = hang onset; indices 192..255 = the
  last 64 CPU samples before the hang (the smoking gun).
- Verilator TB (sim/ila_hang_tb.sv, drives real ila via SPI CMD1/CMD3)
  all-PASS: 20 live-range 195-sample gaps entered candidate and ALL aborted
  (state back to ARMED, no false trigger); hard hang (61000 silent) ->
  DONE with non-zero trigger_pos.

### NEXT BOARD PLAN (flash #3 already done: HANG_CAND=192/HANG_CONF=60000)
1. Power cycle (OSD Cache OFF, stock). Let the desktop SETTLE 60s+ (the
   false-fires at 192/160 were partly mid-boot; settled rhythm matters).
2. SETTLED canary: `trigset 4` + `arm`, wait 30s, `dump` -> MUST be pos=0
   (candidates abort; never reach DONE). If it fires, the threshold needs
   another pass (re-measure with scripts/measure_as_gap.py first).
3. `poke 4`, wait for the ~60-110s freeze.
4. `dump --vcd /tmp/hang.vcd` -> expect pos!=0. Rotated index 0 = hang
   onset; index ~192 = LAST CPU bus cycle (addr + data + SADDR +
   cache_en/hit at the moment of death); samples 193-255 = final
   instruction sequence. That identifies: bad instruction vs bad data vs
   video-DMA collision vs clock/config wedge.
5. Secondary (if the last CPU cycle looks normal -> not a data fault): add
   sweep-complete + hw_cache_en + configCache to ila_probes (v3 probe map;
   osd_cache_probe/cache_sweep_probe exist on macplus but are not probed
   yet; sacrifice the sdram_dout byte [63:56] or widen the map).

### FLASH #4 (2026-11-02 ~13:00 UTC): trigger_pos gated to CONFIRM
Live canary with flash #3 (two-stage) proved the machine alive (ring
256/256 live samples, no DONE), but reported stale non-zero pos (155/153/
229) because trigger_pos was stamped at CANDIDATE (stage 1), and healthy
>=192-sample /AS gaps enter the candidate state constantly. A canary must
report pos=0 when healthy. Fix (Verilator-TB re-validated all-PASS):
- ila.sv: trigger_pos stamped only at CONFIRM (stage 2 -> DONE); candidate
  no longer touches it. Healthy desktop -> pos=0; hang -> pos!=0.
- ila_uart.sv B-dump: header byte = trigger_pos only if ila_state==DONE(4),
  else 0 (defense in depth for all modes).
- sim/ila_hang_tb.sv now asserts pos==0 after aborted candidates: healthy
  195-sample gaps -> ARMED + pos=0; hard hang (61000 silent) -> DONE
  pos=245. ALL PASS.
Board has flash #4 in SPI; power cycle + OSD Cache OFF, settle 60s, then:
canary (expect pos=0) -> poke 4 -> freeze -> dump (expect pos!=0, DONE).
### Board state right now
- Board has flash #4 in SPI, NOT yet power-cycled since the flash.
- sim/nanomac is built HEADLESS with the phase-6 oracle (bad=0 baseline) +
  asGapMax tracker.
- sim/ila_hang_tb.sv + obj_dir hold the standalone two-stage hang TB.
- NOTE: address-trigger plans (trigset 3 0x402680 entry / F-space vector)
  are OBSOLETE for this freeze class — the CPU hangs with /AS never low,
  so modes 1-3 can never fire on it. Keep them only for spins (bad-
  instruction freezes, which do go through the error handler).

## 2026-11-03: hang.vcd DECODED - ROOT-CAUSE CANDIDATE (CPU read slot stolen by video; last cycle never serviced)

### The capture that answered it
Board had flash #4; previous session ran the plan (canary OK, poke 4, freeze,
dump). /tmp/hang.vcd = two-stage mode-4 confirmation capture (13:20 UTC Nov 2).
Rotation: index 0 = trigger (wr_ptr-192), indices 1..191 = post-hang silence,
indices 192..255 = pre-hang (254 = last live sample, 255 = first silent).
Post-hang silence: 192 samples AS=1, SADR walking video RAM 1FD4D3->1FD4DF
(video refresh alive), D=00/3F. CPU makes ZERO further bus cycles.

### The last 5 CPU bus cycles (chronological; all stock TR=0, cache on C$E=1)
  1. idx192-198  W $000004  (vector 1 area, lo word)   C$H=0  SDRAM serviced (SADR 000002)
  2. idx202-214  W $000006  (vector 1 area, hi word)   C$H=0  serviced (SADR 000003)
  3. idx218-230  R $00000C  DHi=21 (vector 3 = illegal-instr vector lo)  serviced
  4. idx234-246  R $00000E  DHi=00 (vector 3 hi)  serviced
  5. idx250-254  R $00003E  (vector 15 lo byte, $00003C-3F = 11-line-addr-error
                 / supervisor-illegal area)  ** DROPPED: SADR shows 000007
                 (stale) then 1FD4D3 = a VIDEO read; never 00001F **
  -> permanent AS-high. Nothing else ever happens.

NOTE: CADDR in probe map v2 IS the full 24-bit byte address (SADR == CADDR/2
on CPU accesses confirms it). Do NOT multiply by 2 again (earlier session
mis-decoded the window as $000008/$00000C etc. - wrong).

### What the address pattern means
$000004/$000006 = one move.l writing vector 1 ($000002-000007 = $402xxx ROM
handler area or a trap vector redirect); $00000C/$00000E = one move.l reading
vector 3; $00003E = byte of vector 15. This is a ROM exception-handler /
crash-logging code path (same family as the $4027EC BSR spin seen earlier).
So the machine had ALREADY taken an exception ~1ms before this window; this
window is the handler's tail. Sequence = (a) early exception (origin
undetermined, needs earlier trigger), then (b) the final vector read is
dropped by the video/CPU SDRAM conflict -> hard hang.

### THE KEY FAULT (provable from the trace): a CPU RAM read got no SDRAM
fetch slot -> no valid data -> the 68k parks with /AS high forever
Mechanism (stock mode, single shared phase-2 SDRAM fetch):
- The SDRAM FSM (src/tang/nano20k/sdram.v) accepts EXACTLY ONE request per
  phase-2 tick: `if (state==IDLE && phase==2) if (oe||we) ACTIVE... else
  AUTO_REFRESH`. oe/we/addr come from addrController.v:
  `_ramOE = ~((cpu_ram_access && _cpuRW) || va_ram_access)` and
  `addrMux = loadPixels?videoAddr:loadSound?audioAddr:cpuAddr[21:1]`
  (line 108) - video and CPU share ONE fetch slot per E-cycle, and on the
  video half-cycle the address mux selects the VIDEO address.
- macplus.sv:238: ram_req set at `busPhase==2 && selectRAM && cpu_slot`,
  `cpu_slot = cpuBusControl || (!loadPixels && !loadSound && !refreshCycle)`.
  Intent: on a phase-2 tick in the video half-slot, video wins the SDRAM
  fetch (loadPixels=1 -> video addr on the bus, _ramOE=1 for video,
  ram_req not set); on the CPU half-slot, the CPU read gets it.
- BUT /AS asserts at a random phase grid position (68k 7.83MHz vs 15.667MHz
  grid = 2.5:1, drifts through all alignments). If the address-valid moment
  of a CPU RAM read coincides with a phase-2 tick in the video half (or the
  E-cycle's phase-2 tick falls in the video slot), the SDRAM FSM fetches the
  VIDEO address: sdram_rd_done fires with sdram_rd_addr = video address.
  Two corrupt outcomes:
    (i)  cpu-side ram_done (busPhase>=4) still DTACKs, but sdram_do carries
         video data => CPU latches garbage (poisoned read), OR
    (ii) fill match fails: ram_fill_evt requires sdram_rd_addr==miss_addr
         (macplus.sv:521-522) => NO fill => line never valid => that line
         re-misses forever (C$E=1, C$H=0 on all 5 traced accesses = cache
         NEVER catches these lines).
- In the capture, access 5 (R $00003E): ram_cs high, C$E=1, C$H=0,
  loadPixels=1, SADR = 1FD4D3 (video), never 00001F. The read was never
  serviced as a CPU read. After it: permanent AS-high.
- WHY the 68k goes AS-high instead of AS-low-forever: the 68k latched
  garbage/never-completed; with the address stuck at $00003E and the
  instruction never completing, the CPU sits in idle between instructions
  (A-bus holds the last address; no fetch issued). The exact fx68k internal
  state (S4 stuck vs idle-with-stuck-urom) is a minor open question - the
  functional fault is identical either way.

### Why cache-OFF boots clean / cache-ON freezes in 60-110s (board-only)
- The video/CPU phase-2 collision exists regardless of cache (stock
  arbiter RTL). With cache OFF, the hot code/data is re-read from SDRAM
  every time, but a poisoned read at the desktop mostly hits tolerant
  code paths or the specific phase-2 alignment rarely coincides with a
  CRITICAL read (vector fetch, instruction fetch in a tight loop). The
  60-110s delay after poke-4: the 1024-line invalidate sweep fires on
  cache-enable; every first re-touch is a MISS that MUST win the phase-2
  slot. 1M+ misses/sec re-touching hot lines => a fatal alignment
  (miss fetch on a video-slot phase-2) lands within seconds-to-minutes.
- ALSO the fill-drop (outcome ii) means cache lines in the hot region are
  permanently invalid => miss rate stays at ~100% for those lines after
  enable, maximizing the collision surface exactly where the freeze hits.
- Sim cannot reproduce: the Verilator SDRAM mock services requests
  without honoring the phase-2 single-slot/video arbitration (and the sim
  video grid may be phase-locked such that a CPU /AS never lands on the
  colliding tick). Confirmed board-only.

### CONFIRMATION STEPS (next board session, in priority order)
1. CHEAPEST & STRONGEST: repeat poke-4 freeze with the display OFF
   (unplug HDMI or OSD video off => no video DMA). If the machine no
   longer freezes within ~5min, the video/CPU SDRAM collision is
   confirmed as the trigger.
2. ILA probe v3: sacrifice sdram_dout byte [63:56] for ram_req +
   cache_in_sweep + cache_en_cfg (osd_cache_probe/cache_sweep_probe
   exist in macplus but are not probed). Then a freeze dump shows
   directly: last CPU cycle had ram_req=0 (slot stolen) vs ram_req=1
   (FSM/SDRAM fault).
3. Sim repro: in nanomac_tb, force a CPU RAM read whose /AS-assert
   lands on a phase-2 tick during loadPixels (scriptable: hold video
   at a known phase, fire the read) and check whether the mock SDRAM
   serves the CPU or the video address. If the mock serves the CPU,
   the mock is masking the bug - fix it to honor the phase-2 single
   slot and the sim should reproduce the freeze.
4. First-exception origin: trigger on the FIRST vector-table write
   (trigset 3 0x000004 0xFFFFFF) to catch what the original exception
   was (the pre-hang window here only shows the handler tail).

### OPTION A: BOARD RESULT (2026-11-03 evening) — CPU SIDE FIXED, VIDEO BROKEN
⚠️ SUPERSEDED IN PART: the "CPU SIDE FIXED" claim only held in stock
cache-OFF boot. The cache-ON freeze is ALIVE (re-confirmed 2026-11-03
23:35 UTC, see "CORRECTION: the 'no freeze' claim was wrong for
cache-ON" below this section).
- **Built + flashed (commits 9e4e250, 37317a0).** Board: booted fully to
  desktop (NO hang; CPU/cache side works). But the DISPLAY IS SCRAMBLED:
  full-screen ~50/50 black/white horizontal-tear noise (captured:
  images/frame_optiona_scramble.png). Booted stock: Turbo=OFF, Cache=OFF,
  no pokes at all.
- **Diagnosis (HIGH confidence; unproven in RTL sim yet):**
  `/AS` is ACTIVE-LOW, so `cpu_mem_acc = selectRAM && !_cpuAS`
  (addrController.v:125) is 1 exactly while the 68k is IN an active
  RAM access (AS low, address in the RAM window). At the desktop the
  68k is in RAM accesses a LARGE fraction of the time: instruction
  fetches (Finder is in RAM), memory-mapped video updates, blits.
  Because of the 68k<->grid drift (~2.5:1, documented), a video
  fetch tick (phase-2 tick in a videoBusControl window where
  loadPixels=1) lands on an in-flight CPU RAM access ~50% of the
  time. Under Option A each such collision makes the CPU win the
  slot:
  1. lpx=0 -> the video pixel word for that window is NEVER
     fetched; the videoShifter (videoShifter.v:22) shifts blank
     ({shiftRegister[14:0],1}) instead of loading the word;
  2. videoTimer's videoAddr is combinational {ypos,xpos}
     (videoTimer.v:62) - the counter does not wait for the fetch,
     so the line DESYNCS by one word (16 px) at every dropped word
     and everything after it is shifted/garbage;
  3. with ~50% of words dropped, nearly every line tears ->
     full-screen 50/50 noise = exactly the screenshot.
  - THE WRONG ASSUMPTION: "a collision is a rare alignment event;
    one dropped pixel word is invisible." At the desktop collisions
    are the NORM (~1 per 2 video words), and each dropped word
    tears the REST of the line, so they are very visible. The
    original hang bug and this scramble are two faces of the same
    coin: one shared phase-2 slot, two masters, and NEITHER side
    may simply lose.
  - Why sim never caught it: (gap 1) tb_ramwin's fake 68k is either
    100% AS-low (first half: every tick classified CPU-expected, so
    "CPU wins" is the expected verdict and the lost video words are
    never counted) or 100% AS-high (second half: no collisions at
    all) - it never models the ~50%-duty in-flight-access pattern
    of the real desktop, and it checks rd_addr ownership only,
    never the video word stream. (gap 2) the full-machine
    nanomac_tb has NO pixel-stream oracle - video correctness is
    not checked anywhere in sim. BOTH gaps.
  - Why the desktop RAM test still passed in sim: sram-vs-sdram
    cross-check only verifies CPU-side data.
- **Suspect list (ranked):**
  1. (above) cpu_mem_acc high while the 68k is in RAM accesses ->
     constant video-word theft at the desktop.
  2. audio path (lsnd gate) - far less likely: audio collides once
     per hblank, would cause small artifacts, not full-screen noise.
  3. HDMI/sync - ruled out by the boot text being normal and the
     noise pattern (horizontal tearing consistent with dropped
     16-bit words).
- **KEY REALIZATION: Option A is INSUFFICIENT, not just buggy.**
  The system has one phase-2 slot per E-cycle for CPU + video DMA
  (~50% duty) + audio. Option A makes the CPU always win, which
  fixes the CPU poison/hang BUT starves video on ~half its words at
  the desktop -> the scramble. The fix that worked for the CPU
  REQUIRES video to be lossless instead: a dropped video word must
  be RE-ISSUED (video slows down / backfills), not dropped. So the
  real fix = "CPU wins the slot; video/audio requests are QUEUED and
  retried until serviced."
- **FIX DIRECTION (next session; validate-in-sim-first per rule):**
  (a) CPU-wins arbitration stays (cpu_mem_acc / cpu_slot parts), but
      video/audio become non-dropping:
      - Option A1 (small): in addrController, when lpx is suppressed
        by cpu_mem_acc, set a `vpx_pending` flag; on the NEXT tick
        where the CPU is not using the slot, lpx' = vpx_pending (the
        same videoAddr word - videoAddr is combinational from
        {ypos,xpos} so it still points at the dropped word; BUT the
        xpos counter keeps running, so the word changes each tick!
        -> the pending flag must ALSO freeze the video word: either
        latch videoAddr at the dropped tick and serve the latched
        word on the retry tick, or move the pixel word counter into
        a registered "video fetch address" that advances ONLY when
        the fetch is actually serviced (Option A2, cleaner: video
        fetch address = registered counter advanced on lpx==1 at
        phase 2; then a collision simply delays the counter - the
        shifter receives words in order, just late; the line's
        timing is carried by the shifter's 32.5MHz shift clock which
        is already decoupled from the fetch grid via the 16-bit
        shift register - one late word = one word of blank at the
        tear point, NOT a full-line desync).
        NEEDS CAREFUL DESIGN: verify the shifter tolerates a 1-E-
        cycle (63.8ns) word gap without blanking/tearing (the shift
        register just shifts 16 extra '1' bits = one black pixel-
        pair window - likely invisible, MUST verify in sim).
      - Option A2 (medium, preferred): the video fetch address
        becomes a register that only increments when the SDRAM slot
        is actually won by video (lpx==1 && phase==2 serviced).
        videoTimer keeps {ypos,xpos} for timing; addrController
        derives the fetch stream. This is the "video DMA paces
        itself to slot availability" design.
      - Option B (2-deep SDRAM request queue in sdram.v FSM) is the
        heavier alternative; only if A2 proves messy.
  (b) SIM FIRST - a pixel-stream oracle is mandatory before any
      video RTL change:
      - tb_ramwin.sv: add a third phase where the fake 68k does
        50%-duty RAM reads (AS low ~400 ticks, high ~400 ticks,
        looping, address cycling through RAM words) - the desktop
        pattern - and assert: EVERY video word is eventually fetched
        (count fetches per videoAddr word == 1, no word missing, no
        duplicates) even though some arrive late.
      - nanomac_tb: add a pixel-stream check (compare the word the
        shifter loads on each lpx tick against the expected
        framebuffer word from a known test pattern written at boot;
        even counting loadPixels-to-sdram-fetch 1:1 would have
        caught this bug).
  (c) Board triage (cheap, do FIRST if board is free; it is up and
      scrambled, stock, cache OFF, no pokes):
      - `python3 scripts/nanomac_ice.py poke 8` (hw_video_off=1,
        cache off): expect screen goes solid/blank (no noise) =
        confirms corruption is in the video fetch path. `poke 0`:
        noise returns.
      - `poke 4` (cache on, video ON): does it still freeze 60-110s?
        If NOT, the CPU-side half of Option A is confirmed good even
        with broken video (the poison path is closed); record it.
- **IMMEDIATE STATE:** board is BOOTED (working CPU, scrambled
  display), stock Turbo=OFF Cache=OFF, no pokes. SPI flash =
  commits 37317a0/9e4e250. Do NOT poke the cache on until the video
  path is fixed (old freeze behavior may still be present underneath
  - unknown, the scramble masks it).

### CORRECTION (2026-11-03 ~23:45 UTC): the "no freeze / CPU fixed" claim was
WRONG for cache-ON. Board re-triage (ICE port /dev/cu.usbserial-20230306211)
reproduced the ORIGINAL hang signature with cache ON.
- **Video theft CONFIRMED (triage A/B):** `poke 8` (hw_video_off=1) -> screen
  SOLID BLACK (user-confirmed), CPU still active (state: AS:0 RM:1, addr
  walking). `poke 0` -> 50/50 noise returns (user-confirmed). => scramble is
  the cpu_mem_acc drop + advancing-combinational-videoAddr diagnosis, proven
  on the board.
- **Cache-ON FREEZE IS BACK:** `poke 4` (cache on, video on) at 23:34:51 UTC.
  User observed the display go CLEAN (unscrambled) the moment the cache
  invalidate sweep started -> that is a FROZEN FRAME, not a working desktop.
  ILA state from 23:37:03 through 23:45+ (6+ reads over 4+ min):
  `A:00003E Q:20 RW:R AS:1 RM:0 RO:0 TR:0`, SA (SADR) walking (video refresh
  alive) on every read. Park at $00003E (A is the full 24-bit byte address;
  this is the same address as access 5 in hang.vcd, the vector-15 lo-byte
  read $00003C-3F). Same park address, same AS=1, same "SADR walks, CPU
  silent" = the original hang.vcd signature, exactly.
  Peek at freeze: F80008:0404 (cache=1 video_on), F80010/14/18 (hits/misses/
  fills) = FFFF (saturated), F8001C last_fill=003E. Dump:
  /tmp/hang2_optiona_cacheon.vcd (trigger armed, pos=0, 256 samples).
- **What it means:** the evening session's "no freeze at startup" was only
  ever observed in STOCK (cache OFF) mode. The freeze re-appears within
  ~1-2 min of cache enable, identical signature to the pre-Option-A hang.
  Two hypotheses remain open (undiscriminated):
    (a) Option A does NOT actually close the collision path on the board
        (e.g. the sim tb_ramwin divergence is real, not a sim gap) —
        Option A is buggy on the board;
    (b) the freeze is the Q1 FIRST-EXCEPTION: a different bug fires an
        exception ~1 min after cache enable; the handler then does the
        $000004/$000006/$00000C/$00000E/$00003E vector-table walk and the
        LAST vector read ($00003E) is dropped by the video/CPU slot
        collision -> hard park. (i.e. Option A works for the collision,
        but the collision is only the KILL SHOT, and a separate trigger
        bug survives.)
  Discriminator: capture the FIRST vector write — `trigset 3 0x000004
  0xFFFFFF`, arm, poke 4, dump. If the trace shows a normal instruction
  stream before the first $000004 write, and the read at $00003E that
  parks IS serviced (SADR reaches 00001F in the pre-hang window), it is (b)
  with a separate trigger; if the $00003E read is again never serviced
  (SADR walks video RAM), it is (a).
- **Board state at correction:** FROZEN (cache on, video on, scrambled-then-
  frozen frame). Recovery: `poke 0` does NOT clear the frozen CPU; the
  machine needs a power cycle or ICE reset ('R' clears hw regs only).
- **Todo-list / next-step delta:** the handoff's NEXT item 1 (board triage)
  is now COMPLETE with this result: video theft confirmed, cache-on freeze
  REPRODUCED (not confirmed-good). NEXT item 2 (sim pixel-stream oracle)
  and item 3 (lossless video fix) are still needed but are NOT sufficient
  to restore cache use: the freeze must be root-caused first, or the cache
  can never be left on for the Speedometer benchmark.

### OPTION A IMPLEMENTED + SIM-VALIDATED (2026-11-03 session)
- **Deterministic collision TB (sim/tb_ramwin.sv)**: real clocks +
  addrDecoder + videoTimer + addrController + board sdram.v FSM. Fake
  68k continuous word READ of $00003E (word $00001F) for 2000 ticks,
  then CPU idle 2000. 4MB identity mapping. Checks every phase-2
  fetch the FSM issues (rd_addr latched 1 cycle later) against the
  expected owner (CPU word / videoAddr / audioAddr).
  - UNFIXED: `cpu-fetches=125 ok=75 / 50 MISMATCHES (all video word
    1f939x, lp=1)` -> bug reproduced. video-only=127 ok, audio=3 ok.
  - FIXED:  `cpu-fetches=125 ok=125, video=127 ok, audio=3 ok,
    MISMATCHES=0, RESULT: PASS`.
  - Build: verilator -j 4 --timing --binary -Wno-lint -Wno-fatal
    -top-module tb_ramwin -Mdir obj_ramwin <clocks/addrDecoder/
    videoTimer/addrController>.v ../src/tang/nano20k/sdram.v tb_ramwin.sv
  - NOTE: tb MUST connect .phase(phase) to the sdram FSM (I forgot
    once; FSM stays in IDLE, rd_addr stuck 0).
- **Changes (working tree, sim-validated, NOT yet built for FPGA):**
  - addrController.v: Option A core. cpu_mem_acc = selectRAM && !_cpuAS;
    lpx = loadPixels && !cpu_mem_acc && !video_dma_off;
    lsnd = loadSound && !cpu_mem_acc && !video_dma_off; used in
    va_ram_access, cpu_ram_access, _ramOE/_ramWE, addrMux.
    New input `video_dma_off` (hw_video_off poke bit3).
  - macplus.sv: cpu_slot gains `|| cpu_mem_acc` (so ram_req IS set on
    the colliding phase-2 tick -> DTACK + fill on that cycle);
    loadPixels_eff/loadSound_eff = <raw> && !cpu_mem_acc &&
    !hw_video_off -> dataController shifter/audio (prevents loading
    the CPU word into the pixel line); mac_probes[17:16] now show the
    EFFECTIVE loads; new out hw_video_off_probe; dc0 gets
    .hw_video_off(hw_video_off); ac0 gets .video_dma_off(hw_video_off).
  - dataController.sv: new hw_video_off reg ($F80008 bit3, poke; RO
    mirror bit11; status readout widened 5'd0->4'd0+bit11).
  - top.sv: PROBE MAP v3 (2026-11-03): [63]ram_req (mac_probes[11]),
    [62]cache_sweep, [61]cache_en_cfg (macplus.cache_en_cfg),
    [60]hw_video_off, [59:56]reserved (sacrificed sdram_dout byte).
    [55:32]..[0] unchanged from v2 (cpuAddr still [55:32]).
  - ila_uart.sv: 's' state line now "A:xxxxxx Q:x" (Q = [63:60]
    flags nibble {ram_req,sweep,cen,vidoff}) instead of "D:xx".
  - scripts/nanomac_ice.py: parse_sample v3 (ram_req/sweep/cen_cfg/
    video_off), VCD gets RQ/SW/CE/VO, poke printout shows
    turbo/ovr/cache/video_off. PY_COMPILE OK.
- **Full-machine regression (Verilator, HEADLESS):**
  - ./nanomac --cache 1 --fastboot 0: boots to desktop, ORACLE
    bad=0, hits ~21.8M/20s, diagPh6NoHit=0. (The stray
    "RAM read mismatch @0007fbd4/000fac.." lines are the tb's
    sram-vs-sdram cross-check firing during RAM-test pattern
    windows - present in ALL prior baselines too, not a fault;
    ORACLE bad=0 is the verdict.)
  - ./nanomac --cache 0 --fastboot 0: bad=0, healthy.
  - Standalone ILA hang TB (ila_hang_tb.sv) re-run after ila_uart
    edit: ALL PASS (healthy gaps abort, hang 61000 -> DONE pos=245).
- **Gowin build fix (commit 37317a0):** gw_sh EX3828 rejects the
  hierarchical ref `macplus.cache_en_cfg` (Verilator allows it).
  Now a proper macplus output port `cache_en_cfg_probe`. Sim
  regression re-checked clean. If further EX3828/hierarchical-ref
  errors appear, same pattern: expose as a module output port.
- **STILL TO DO (next session):**
  1. FPGA build: cd src && bash build.sh  (gw_sh; GIT_HASH fallback
     0xDEAD if -verilog_define warning persists - known, non-fatal).
  2. bash scripts/flash_board.sh src/impl/pnr/nanomac.fs -f
     then POWER CYCLE.
  3. Board validation sequence (keyboard-free):
     a. OSD Cache OFF + stock, boot clean, settle 60s.
     b. SETTLED canary: trigset 4 + arm + 30s + dump -> pos=0.
     c. poke 4 (cache on, video ON) -> expect freeze 60-110s on
        OLD build; on this build expect NO freeze. If it still
        freezes: dump --vcd (v3 map shows ram_req at last cycle).
     d. ICE 'R' (clears hw regs), poke 12 (cache on, video DMA OFF)
        -> 5+ min must stay healthy (display-off confirmation;
        THIS is the corrected step 1 of the old plan).
     e. Optional Q1: trigset 3 0x000004 0xFFFFFF to catch the first
        vector write = original exception.
  4. If board green: Speedometer 3-iter sieve comparison
     (stock+cache 14.0M cycles/iter baseline) + cache counters
     (clear/peek window).
- **RISK NOTES (read before declaring victory):**
  - Option A drops one video pixel word per collision: invisible
    (next word re-aligns the shifter; at most a 1-word gap in a
    512-word line) but has NEVER been exercised on the board.
  - The poisoned-read path (outcome i) and the fill-drop path
    (outcome ii) are both closed by the same fix, but the
    FIRST-EXCEPTION origin (Q1) may be a different bug that the
    handler was logging - the freeze could recur via that path.
    The v3 probe + poke-12 test discriminate.
  - turbo mode still has the known phase-2 wr-invalidate gap
    (documented under "Bisect plan"); Option A's cpu_mem_acc is
    phase-agnostic (level, not phase) so it should also protect
    turbo reads, but turbo was not re-validated in sim this session
    (sim CLKCPU is phase-locked; no drift).

### FIX DIRECTION (NOT implemented; follow validate-in-sim-first rule)
Preferred (Option A): CPU access wins the phase-2 SDRAM slot - suppress
video pixel fetch on any phase-2 tick where a CPU RAM/ROM access is
address-valid (selectRAM||selectROM && !_cpuAS). Video drops one
pixel-cycle (invisible); CPU always serviced. Change point:
addrController.v _ramOE/addrMux (gate va_ram_access with
!(selectRAM||selectROM && !_cpuAS)) or macplus.sv cpu_slot usage.
Option B: SDRAM FSM accepts a late/queued request when phase-2 was
taken by video (2-deep request queue). Bigger change.
Option C (cache-only mitigation): on fill-address mismatch, re-issue
the miss (retry next slot). Masks, does not fix poisoned cache-off reads.

### OPEN SUB-QUESTIONS (do not lose)
- Q1: which exception fired FIRST 60-110s after poke-4 (the root
  trigger of the crash that the handler then logged)? Step 4 above.
- Q2: $BE003E park address (state x3 on frozen board) = SCC-decoded
  idle A-bus of the same stuck 68k (normal SCC cycles DTACK instantly,
  so AS:1 persistent = same stuck-bus class), likely corrupted PC.
- Q3: reconcile "rAS only clears on S6" with AS-high-after-hang:
  either the 68k completed access 5 with garbage (S6 OK, urom stuck
  in a stuck fetch of a bad vector), or fx68k has a stall path not
  yet traced. Low priority - the chipset-side dropped read is the
  proven fault.

## 2026-11-03 (session: Option A implementation) — PLAN + CORRECTIONS

### ⚠️ CORRECTION: the "display-off poke 4" confirmation test is INVALID
- There is NO OSD "video off" option. sysctrl.v CMD4 config IDs:
  R(reset) Y(memory) V(volume) W(floppy-prot) X(video MODE: 720p/wide/
  native) T(turbo) S(hdd-prot) F(fastboot) C(cache) M(serial). All video
  modes run the video DMA.
- Unplugging HDMI does NOT stop the video DMA: loadPixels
  (videoTimer.v:63) is driven purely by the internal xpos/_vblank/
  videoCycle counters — independent of HDMI/EDID/display state. SDRAM
  keeps being fetched for the framebuffer with no display attached.
- Therefore "display off + poke 4" would still run the video/CPU
  collision. To make a valid no-video test, add a real video-DMA off
  switch: new poke bit 3 in the $F80008 control word = hw_video_off
  (gates loadPixels/loadSound into addrController + dataController
  shifter/audio). Test pokes:
    poke 4  (0x04) = cache ON, video ON   -> expect freeze 60-110s
    poke 12 (0x0C) = cache ON, video DMA OFF -> expect NO freeze (5min+)
  (ICE 'R' reset between the two — it clears the hw regs.)

### Mechanism confirmed in code this session (board RTL, exact lines)
- sdram.v:153-165 — FSM in STATE_IDLE accepts a request ONLY at
  phase==2: (oe||we) -> CMD_ACTIVE (row latch, rd_addr_r<=addr) else
  CMD_AUTO_REFRESH. Exactly ONE fetch per phase-2 tick, no queue.
- addrController.v:108 — addrMux = loadPixels?videoAddr :
  loadSound?audioAddr : cpuAddr[21:1]. Video/audio win the address mux;
  _ramOE (line 101) also asserts for va_ram_access.
- macplus.sv:221 — cpu_slot = cpuBusControl || (!loadPixels &&
  !loadSound && !refreshCycle); ram_req set only at busPhase==2 &&
  selectRAM && cpu_slot (line 238) -> in a video half-slot a CPU RAM
  read gets NO fetch slot and no ram_req -> data path serves
  sdram_do = video word (doutD) -> 68k latches video data as if it
  were the vector (poisoned read, outcome (i)).
- fx68k cross-check (src/fx68k/fx68k.sv): busEnd = ~rDtack | iStop
  (line 2355); iStop only via xVma/(Vpai&(iAddrErr|~rBerr)) (line
  575-576) — no data-missing abort path, so the poisoned read
  completes "normally" and the CPU chokes on the NEXT fetch (Q3).
  dataIo latches iEdb at the next T4 (line 1777-1785) — consistent
  with data being latched from phase-6-valid sdram_do.
- Why the sim never reproduces: nanomac_tb.v:181 ties .CLKCPU(clk) —
  the 68k is phase-locked to the phase grid, so /AS can never drift
  onto the colliding tick the way the board's 2.5:1 drift does.
  (The earlier "mock SDRAM" note in this doc is inaccurate: the sim
  DOES instantiate the real board sdram.v FSM — TANG_FILES in
  sim/Makefile. What masks the poison is the C++ SRAM model
  (nanomac_tb.cpp:598-638): it serves ram[ram_addr] directly at
  phase 6, so even a poisoned cycle hands the CPU the right word,
  and the dual-implementation cross-check (line 632) only compares
  against the FSM when the FSM actually read.)

### Option A implementation (this session)
- addrController.v: gate the video/audio SDRAM fetch while a CPU RAM
  access is address-valid: cpu_mem_acc = selectRAM && !_cpuAS;
  lpx = loadPixels && !cpu_mem_acc; lsnd = loadSound && !cpu_mem_acc;
  used in va_ram_access, cpu_ram_access, addrMux. (CPU read AND
  write now win the slot; a skipped video pixel word / audio byte
  is invisible.)
- macplus.sv: companion change — cpu_slot gains `|| (selectRAM &&
  !_cpuAS)` so ram_req IS set on the colliding phase-2 tick ->
  DTACK in the first E-cycle and the fill fires on that cycle;
  shifter + audio get the gated load signals (videoShifter must not
  load the CPU word into the pixel line); mac_probes use gated
  loadPixels/loadSound so the ILA shows the effective bus state.
- dataController.sv: new hw_video_off reg ($F80008 bit 3, poke),
  RO bit 11 in the status readout; macplus gates loadPixels/
  loadSound with !hw_video_off before ac0/dc0 (the valid
  "display-off" test enabler).
- ILA probe v3 (top.sv): [63:56] now {ram_req, cache_in_sweep,
  cache_en_cfg, hw_video_off, 4'b0} (sacrifices the sdram_dout byte
  [63:56] per plan); ila_uart 's' snapshot format and
  scripts/nanomac_ice.py parse_sample updated.
- Sim validation:
  (a) deterministic collision TB (sim/tb_ramwin.v): real clocks +
      addrDecoder + videoTimer + addrController + sdram FSM, fake
      CPU asserts a RAM read timed to a video-half phase-2 tick.
      UNFIXED: rd_addr = video word (bug reproduced). FIXED:
      rd_addr = CPU word, video fetches unaffected when no CPU
      access.
  (b) full-machine regression: ./nanomac --cache 1 --fastboot 0
      must stay bad=0 + boots (cache off baseline too).
- Board plan (needs user, after build+flash):
  1. Power cycle, OSD Cache OFF (recover the frozen board).
  2. Settled desktop: trigset 4 + arm + 30s + dump -> pos=0 canary.
  3. poke 4 (cache on, video on) -> freeze -> dump --vcd (v3 map:
     last CPU cycle now shows ram_req directly).
  4. ICE 'R' reset, poke 12 (cache on, video DMA off) -> 5+ min,
     no freeze => video-collision root cause CONFIRMED.
  5. (Optional) trigset 3 0x000004 0xFFFFFF to catch the FIRST
     vector write = the original exception (Q1).

## Clocks/phase reference (stock mode)

clk_sys=clk_pixel=15.6672MHz; 8 phases per E-cycle; /AS low from phase 2;
ram_req/rom_req set at phase 2; cache_hit valid from phase 3; DTACK: hit@3,
stock miss@4, turbo miss@7; cache_wr_pulse (invalidate) @ phase 2 of RAM write.
Turbo: cpu 19.584MHz via DCS (39.168 raw /2), enPhi alternating.
ILA: clk_pixel, 256x64 trace, probe map v2 (see "Probe map v2" above;
[55:32]cpuAddr, [31:11]sdram_rd_addr, [9]cache_hit [8]cache_en [7]AS
[6]RW [5]selectRAM [4]selectROM [3]loadPixels [2]loadSound [1]videoBMC
[0]cpuBMC, [10]turbo).

## Lessons / user preferences
- ALWAYS validate fixes in Verilator before building/Flashing (user instruction).
- Prefer SPI flash (-f) over SRAM (-m) for bitstream loads.
- Debug protocol: hypothesize → validate with evidence → confirm with user before fixing.
- Timing report violations are a red herring (SDC only constrains clk_osc).
- context limit 262k; this handoff doc is the recovery point.

## FRESH-SESSION PROMPT (paste as first message 2026-11-04+)
Read HANDOFF.md: (1) "CORRECTION (2026-11-03 ~23:45 UTC): the 'no
freeze / CPU fixed' claim was WRONG for cache-ON" first, (2) then
"OPTION A IMPLEMENTED + SIM-VALIDATED", (3) then the hang.vcd decode
section above it.

STATE: Option A (CPU wins the phase-2 SDRAM fetch slot) is built +
flashed (commits 9e4e250, 37317a0, docs 0638d13). TWO independent
bugs are live on the board, both confirmed by board triage 2026-11-03
evening (ICE port /dev/cu.usbserial-20230306211):
(1) VIDEO SCRAMBLE (stock, cache OFF, no pokes): full-screen 50/50
    black/white horizontal-tear noise (images/frame_optiona_scramble.png).
    CONFIRMED via A/B: poke 8 (hw_video_off) -> solid black, poke 0 ->
    noise returns. Diagnosis: cpu_mem_acc (addrController.v:125) is
    high whenever the 68k is in an in-flight RAM access; at the desktop
    that's ~50% of video fetch ticks -> the video word is DROPPED while
    the combinational videoAddr (videoTimer.v:62) advances anyway ->
    shifter desync per dropped word. Fix = lossless video (A2 registered
    fetch counter), after a sim pixel-stream oracle.
(2) CACHE-ON HARD FREEZE (the ORIGINAL hang, NOT fixed by Option A):
    poke 4 (cache on, video on) -> within ~1-2 min the CPU parks at
    $00003E, AS=1, RW:R, RM:0, SADR walking (video alive) - the exact
    hang.vcd signature. The "clean desktop" seen at freeze is a FROZEN
    FRAME (CPU dead -> no slot theft -> video redraws the last frame).
    "No freeze" was only ever observed in cache-OFF boot. Open
    hypotheses: (a) Option A's collision path is not actually closed on
    the board, or (b) the freeze is the Q1 first-exception (a separate
    bug) whose handler's final vector read is the kill shot.
    Discriminator = capture the first vector write: trigset 3 0x000004
    0xFFFFFF. Board is FROZEN as of session end; recovery = power cycle.

DIAGNOSIS (high confidence, NOT yet proven in sim): /AS is
ACTIVE-LOW, so the Option-A gate `cpu_mem_acc = selectRAM && !_cpuAS`
(addrController.v:125) is 1 exactly while the 68k is IN an active RAM
access. At the desktop that's a LARGE fraction of the time (Finder
instruction fetches in RAM + memory-mapped video updates). With the
68k<->grid drift (~2.5:1), ~half of all video fetch ticks land on an
in-flight CPU RAM access -> Option A makes the CPU win the slot ->
the video word is DROPPED (lpx=0) and videoTimer's combinational
videoAddr ({ypos,xpos}, videoTimer.v:62) advances anyway -> the
shifter desyncs by one word at every drop, tearing the rest of the
line. ~50% of words dropped = full-screen noise. KEY INSIGHT:
Option A (CPU always wins) is INSUFFICIENT by itself - the video
side must be made LOSSLESS (a suppressed word must be re-issued,
not dropped), otherwise every CPU RAM access costs the display a
tear. The original hang and this scramble are the same coin:
one shared phase-2 slot, two masters, neither may simply lose.
Sim gaps that hid it: tb_ramwin.sv's fake 68k is either 100%
AS-low (all ticks CPU-expected; lost video words uncounted) or 100%
AS-high (no collisions) - it never models the ~50%-duty desktop
pattern - and nanomac_tb has NO pixel-stream oracle at all.

NEXT (in order; updated 2026-11-03 evening after re-triage):
1. BOARD TRIAGE - DONE (2026-11-03 evening, see CORRECTION section):
   video theft confirmed (poke 8 -> solid black, poke 0 -> noise back);
   cache-on freeze REPRODUCED (poke 4 -> park at $00003E, AS=1, SADR
   walking; hit/miss/fill counters FFFF; /tmp/hang2_optiona_cacheon.vcd).
   Board left FROZEN -> needs POWER CYCLE before any further work.
2. FREEZE FIRST (blocks all cache use; must precede the benchmark):
   power cycle, settle to stock desktop (scrambled, CPU alive), canary
   (trigset 4 + arm + 30s + dump -> pos=0), then `trigset 3 0x000004
   0xFFFFFF` (first vector-table write) + arm + `poke 4` + wait ~2 min
   + dump. Decode: (a) $00003E read serviced in pre-hang window (SADR
   reaches 00001F) => freeze is Q1 separate-exception trigger; (b)
   $00003E read never serviced again => Option A's collision path is
   NOT closed on the board (sim/tb_ramwin says PASS but board says
   FAIL -> find the divergence). Decide direction from that evidence.
3. SIM FIRST - a pixel-stream oracle is mandatory before any video
   RTL change:
   (a) tb_ramwin.sv: add a third phase where the fake 68k does
       50%-duty RAM reads (AS low ~400 ticks / high ~400 ticks,
       address cycling through RAM words) = the desktop pattern, and
       assert EVERY video word is eventually fetched exactly once
       (none missing, none duplicated), even if some arrive late.
   (b) nanomac_tb.cpp/.v: assert 1:1 between loadPixels ticks and
       video SDRAM fetches (or compare loaded words against a known
       framebuffer pattern) - this single check would have caught
       the scramble.
4. FIX video (only after the sim reproduces the scramble): keep
   CPU-wins arbitration, make video LOSSLESS - preferred Option A2:
   the video fetch address becomes a REGISTERED counter that advances
   only when the SDRAM slot is actually won by video (a collision
   delays, never drops, the word; verify in sim that the shifter
   tolerates the resulting 1-E-cycle word gap as one black pixel-
   pair, not a line tear). Alternative A1: pending-flag + latched
   videoAddr retry. Option B: 2-deep request queue in sdram.v FSM.
   Do NOT ship any video change without (3) green.
5. Only when stock video is clean AND the freeze root cause is
   resolved (step 2): full board validation (settled canary, poke 4
   cache-on -> no freeze for 5+ min, poke 12 display-off
   confirmation 5+ min), then Speedometer 3-iter sieve vs
   14.0M cycles/iter baseline + clear/peek counter window.

RULES (unchanged): validate-in-sim-first before building/flashing;
hypothesize -> validate with evidence -> confirm with user before
fixing; SPI flash (-f) for bitstreams; timing-report violations are a
red herring (SDC only constrains clk_osc).
