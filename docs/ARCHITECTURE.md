# NanoMac Hardware Architecture & Invariants

## 1. Clock Domains & Phase Grid
- **`clk_sys` / `clk_pixel`**: **15.6672 MHz** (Mac Plus master clock).
  - Divided by `clocks.v` into 8 phases (`busPhase = 0..7`, `clk8_en_n = !busPhase[0]`, `clk8_en_p = busPhase[0]`, `cycleReady = (busPhase == 7)`).
  - Two alternating 8-tick E-cycles (`16` ticks = `1.021 µs` total):
    - **`videoBusControl = 1` (`!busCycle`)**: Video (`loadPixels`), Audio (`loadSound`), or Refresh (`refreshCycle`) owns SDRAM at `busPhase == 2`.
    - **`cpuBusControl = 1` (`busCycle`)**: CPU owns SDRAM at `busPhase == 2` (or steals an unused `videoBusControl` cycle when `!loadPixels && !loadSound && !refreshCycle`).
- **`clk_cpu` (via Gowin `DCS` in `top.sv`)**:
  - **Stock (`turbo_synced == 0`)**: `clk_pixel` (`15.6672 MHz`), `enPhi1 = clk8_en_p`, `enPhi2 = clk8_en_n` (`7.8336 MHz` effective 68000 clock).
  - **Turbo (`turbo_synced != 0`)**: `clk_cpu_raw` (`39.168 MHz` = `78.336 MHz / 2`), alternating `enPhi1`/`enPhi2` (`19.584 MHz` effective, **2.5×** stock, 5:2 phase ratio with `clk_sys`).
- **`clk_pixel_x5`**: **78.336 MHz** (720p60 HDMI pixel clock & external SPI Flash clock).

## 2. 68000 Bus & Address Bit Indexing (`cpuAddr[23:1]`)
- **CRITICAL**: `fx68k` exposes `cpuAddr` as **`[23:1]`** (there is no `A0` wire).
  - `cpuAddr[k]` is **68000 pin `A_k`** (e.g., `cpuAddr[23]` = `A23`, `cpuAddr[4]` = `A4`, `cpuAddr[1]` = `A1`).
  - Word index in 4MB RAM (`21` bits, `2M` words): `cpuAddr[21:1]`.
- **Active-Low Control Signals**:
  - `_cpuAS` (`0` = address strobe active), `_cpuRW` (**`1` = READ, `0` = WRITE**), `_cpuUDS` / `_cpuLDS` (`0` = upper/lower byte active), `_cpuDTACK` (`0` = data transfer acknowledge).
  - `fx68k` latches `iEdb` (`dataControllerDataOut`) on the cycle `_cpuDTACK` is asserted low (T3 -> T4 transition).

## 3. Memory Map & Mirroring (Mac Plus, 4MB Config)
- **`$000000 - $3FFFFF`**: Primary RAM (up to 4MB; overlaid by ROM when `memoryOverlayOn == 1` at boot).
- **`$400000 - $4FFFFF`**: 128KB Macintosh Plus ROM (external SPI flash at `0x480000`).
- **`$800000 - $8FFFFF`, `$A00000 - $AFFFFF`**: Mac Plus `A23` RAM mirror (`cpuAddr[21:1]` maps `$8FF000` -> RAM word `$07F800`, identical to `$0FF000`). Used by the Mac ROM Illegal/Exception crash handler.
  - **WARNING**: Never decode `$900000-$9FFFFF` (`4'b1001`, SCC Read) or **`$B00000-$BFFFFF` (`4'b1011`, SCC Write `$BFFFF9-$BFFFFF`)** as RAM mirrors! Shadowing `$B00000-$BFFFFF` blocks CPU writes to the Z8530 SCC (`4'b10?1`), preventing the Mac ROM from enabling DCD mouse movement interrupts on SCC channels A & B.
- **`$FFFFE0 - $FFFFFF`**: 68000 Interrupt/Exception Vector Mirror (`cpuAddr[23:5] == 19'h7FFFF`), mapped by `addrController.v` to the low 16 RAM words (`$000000 - $00001E`).
- **Cache Exclusion (`ram_mirror_alias`)**: `$800000-$BFFFFF`, `$FFFFE0-$FFFFFF`, and `$000000-$00001E` bypass `bram_cache` to prevent alias coherence hazards.

## 4. SDRAM Controller (`src/tang/nano20k/sdram.v`)
- Runs on `clk_sys` (`15.6672 MHz`).
- Accepts a command (`oe` or `we`) **only** in `STATE_IDLE` at **`phase == 3'd2`**:
  - Latches row `addr[19:9]`, bank `addr[21:20]`, and `rd_addr_r <= addr`.
  - Issues CAS at `state == 1` (`busPhase == 3`).
  - Data returns at `state == STATE_READ` (`busPhase == 6`): `rd_done` pulses high for 1 `clk_sys` cycle, `dout` presents live SDRAM data, and `doutD` latches it for `busPhase >= 7`.

## 5. Hardware Diagnostic & Control Registers (`$F80000 - $F8001F`)
Decoded when `selectHardwareRegs == 1`, indexed by `hwRegIdx = {A4, A3, A2}` = `cpuAddr[4:2]` (`cpuAddrRegMid[0], cpuAddrRegA3, cpuAddrRegLo[1]`):
- `0` (`$F80000` RO): `16'h4E4D` (`'NM'`)
- `1` (`$F80004` RO): `16'h0001` (Rev 1)
- `2` (`$F80008` R/W): Control/Status (write requires `0x55` in `[15:8]`):
  - `[0]` `hw_turbo_en`, `[1]` `hw_turbo_ovr`, `[2]` `hw_cache_en`, `[3]` `hw_video_off`, `[8]` `cpu_turbo_active` (RO), `[10]` `hw_cache_en` (RO)
- `3` (`$F8000C` RO): `hw_bench_timer` — 16-bit saturating hardware timer (`1.9584 MHz` = `510.64 ns/tick`, cleared alongside `$F80010`)
- `4` (`$F80010` R/W): `cache_hits` (write `0x55xx` clears `hw_bench_timer`, `cache_hits`, `cache_misses`, `cache_fills`)
- `5` (`$F80014` RO): `cache_misses`
- `6` (`$F80018` RO): `cache_fills`
- `7` (`$F8001C` RO): `{last_fill_is_rom, 1'b0, last_fill_addr[13:1], 1'b0}`

## 6. On-Chip ICE/ILA & SDRAM DMA (`src/companion/ila_uart.sv`)
- **ICE SDRAM DMA (`'W'` write / `'M'` read)**: Steals CPU SDRAM slots (`busPhase == 2..6`) via `ice_mem_busy` gating `cpu_slot` in `macplus.sv` (using normal 68000 `_cpuDTACK` wait states, never gating `enPhi1`/`enPhi2` across the `15.6672 MHz -> 39.168 MHz` boundary) and triggers a cache invalidation sweep (`ice_poke_idx == 7`) after writes.
