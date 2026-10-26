# Original User Request

## 2026-08-24T06:02:22Z

This is a single self-contained fix; keep it small and focused. Implement an asynchronous wait-state DTACK engine for NanoMac (Apple Macintosh Plus on Tang Nano 20K) to enable functional 68000 CPU Turbo acceleration without memory bus collisions or system crashes, operating over the production external SPI Flash ROM and SDRAM memory architecture.

Working directory: /Users/Jeff/workspace/NanoMac
Integrity mode: development

## Requirements

### R1. Asynchronous CPU Wait-State & DTACK Generation
The 68000 CPU bus interface in `src/macplus/macplus.sv` must be decoupled from rigid `busPhase` assumptions during Turbo modes. When Turbo is enabled (`configTurbo != 2'b00`), the CPU clock enables (`turbo_enPhi1`, `turbo_enPhi2`) must allow fast execution, but `_cpuDTACK` must remain negated (*wait states*) on all memory accesses until the target subsystem (SDRAM, external SPI Flash ROM, or peripheral IO) acknowledges completion and presents valid read/write data.

### R2. SDRAM Phase Synchronization & Video DMA Protection
CPU memory requests must not corrupt or collide with video/sound DMA time-slots in `src/macplus/clocks.v` and `src/tang/nano20k/sdram.v`. The SDRAM controller must complete any in-flight or scheduled video/audio DMA cycles before executing CPU memory cycles, asserting a completion handshake directly to the CPU DTACK generation logic.

### R3. External Flash ROM & Bus Timing Integrity
The system operates exclusively with external SPI Flash ROM (`src/tang/nano20k/flash.v` at offset 0x480000) to preserve FPGA Block RAM budget. The DTACK engine must respect flash controller latency and timing phases during ROM instruction fetches, asserting `_cpuDTACK` only when valid ROM data is latched on `rom_data`.

### R4. Verification & Non-Regression Gate
All modifications must pass cycle-accurate Verilator simulation (`sim/run_top_tb.sh` and `sim/nanomac_tb.cpp`) for multi-frame intervals before physical FPGA synthesis. The 5 core invariants (1×/2× scaling, OSD 1-clock strobe sync, 48kHz audio pitch, 1:5 PLL clock lock, and ROM boot) must remain intact without regressions.

## Acceptance Criteria

### Correctness & Performance
- [ ] Top-level structural simulation (`sim/run_top_tb.sh`) compiles cleanly with no unmapped nets or synthesis warnings.
- [ ] Multi-frame Verilator simulation boots Mac OS (System 3.0 / disk interrogation) with Turbo mode enabled (2x, 4x, Max Turbo) without illegal instruction traps, bus hangs, or visual tearing.
- [ ] CPU memory access traces verify that `_cpuDTACK` is never asserted before read data is valid on `sdram_do` or `rom_data`.
- [ ] Measurable speedup in CPU-bound operations when switching Turbo modes in the OSD menu.

### Non-Regression (5 Core Invariants)
- [ ] **1× & 2× Scaling**: Both `wide=0` and `wide=1` remain centered and framed in 1280×720p.
- [ ] **OSD Overlay**: OSD text remains crisp with single 1-clock pulse edge detection (no 5× font stretching).
- [ ] **HDMI Audio**: 48 kHz linear interpolation phase step remains `30385` without pitch distortion or crackles.
- [ ] **Clock Lock**: Mac domain (15.6672 MHz) and HDMI domain (78.336 MHz) remain strictly locked at a 1:5 ratio.
- [ ] **Boot & ROM**: Cold boot and reset vector initialization from external flash ROM work reliably.

### Hardware-in-the-Loop (HITL) Execution
- [ ] Gowin EDA compilation (`src/build.tcl`) builds cleanly after terminating any stale `gw_sh.bin` processes.
- [ ] Bitstream (`src/impl/pnr/nanomac.bin`) flashes to the Tang Nano 20K and produces verified live video output captured via `./scripts/capture_frame.sh frame.png`.

