# NanoMac — Live Project Handoff

> **Context References**:
> - **Hardware Architecture & Invariants**: [docs/ARCHITECTURE.md](file:///Users/Jeff/workspace/NanoMac/docs/ARCHITECTURE.md)
> - **Historical Debugging Log**: [docs/ARCHIVE_LOG.md](file:///Users/Jeff/workspace/NanoMac/docs/ARCHIVE_LOG.md)
> - **HITL Synthesis & Board Protocol**: [.agents/skills/tang-nano-hitl/SKILL.md](file:///Users/Jeff/workspace/NanoMac/.agents/skills/tang-nano-hitl/SKILL.md)

---

## 1. Current State (2026-11-06 — Unchained Cache + ICE SDRAM DMA Verified on Hardware)

1. **Unchained Zero-Wait-State Cache Hits ([`macplus.sv`](file:///Users/Jeff/workspace/NanoMac/src/macplus/macplus.sv#L510)) — VERIFIED ON HARDWARE**:
   - Decoupled `cache_hit` from `busPhase == 2` (`ram_req`/`rom_req`) and `cpu_slot`, and added canonical physical address `cpu_cache_addr`.
   - **Live ILA Measurement**: Completed bus cycles per 256-tick window rose from **26 to 47 (+81%)**, and average `/AS = 0` duration on cache hits dropped from **8.08 `clk_sys` ticks (516 ns) to 2.00 ticks (127.7 ns) — 4.04× faster**, serving cached RAM reads even while video DMA (`PX = 1`) owns SDRAM.
2. **ICE UART SDRAM DMA (`'W'`/`'M'`) & `$F8000C` Benchmark Timer — VERIFIED ON HARDWARE**:
   - Added bulk SDRAM write (`'W'`) and read (`'M'`) in [`ila_uart.sv`](file:///Users/Jeff/workspace/NanoMac/src/companion/ila_uart.sv), arbitrated via `ice_mem_busy` gating `cpu_slot` in [`macplus.sv`](file:///Users/Jeff/workspace/NanoMac/src/macplus/macplus.sv#L230) (never gating `enPhi1`/`enPhi2` across the `15.6672 MHz -> 39.168 MHz` boundary).
   - Fixed three hardware register bugs in [`dataController.sv`](file:///Users/Jeff/workspace/NanoMac/src/macplus/dataController.sv#L258) (`hwRegIdx[2]` = `cpuAddrRegMid[0]` = `A4`) and [`macplus.sv`](file:///Users/Jeff/workspace/NanoMac/src/macplus/macplus.sv#L422) (`cache_cacheable` uses `cache_en_cfg`; `cache_clr` checks `cpuAddr[4]` = `A4`).
   - Added `memread`, `memwrite`, `vram` (fills 21,888B `$3FA700` display buffer in `1.34s`), and `runbench` (injects 68000 VBL benchmark at `$3FA700`, measures all 4 hardware modes via `$F8000C` 1.9584 MHz timer, and restores System 7 cleanly) to [`nanomac_ice.py`](file:///Users/Jeff/workspace/NanoMac/scripts/nanomac_ice.py).

## 2. Live Hardware Benchmark (`python3 scripts/nanomac_ice.py runbench`)

| Mode | Ticks (`510.64 ns`) | Time (`ms`) | Speedup | Cache Hits | Cache Misses | Checksum |
|---|---:|---:|---:|---:|---:|---|
| **Stock (7.83 MHz) + Cache OFF** | `48,108` | `24.566` | `1.00×` | `0` | `0` | `0x1799` |
| **Stock (7.83 MHz) + Cache ON** | `35,052` | `17.899` | **`1.37×`** | `7,989` | `28` | `0x1799` |
| **Turbo (19.6 MHz) + Cache OFF** | `48,943` | `24.992` | `0.98×` | `0` | `0` | `0x1799` |
| **Turbo (19.6 MHz) + Cache ON** | `14,083` | `7.191` | **`3.42×`** | `7,989` | `28` | `0x1799` |

## 3. OSD Live-Switch, Keyboard Fix & Remote KVM (2026-11-08)
- **OSD Live-Switching & Bus-Idle Synchronization**: `top.sv` synchronizes `osd_cache` on `cpu_bus_idle` and pulses `osd_ovr_clr` on OSD menu changes to release `hw_turbo_ovr` in `dataController.sv`; `macplus.sv` decodes `cache_en_cfg = hw_turbo_ovr ? hw_cache_en : configCache`; `nanomac_ice.py runbench` restores `$F80008` to `0x5500` (`hw_turbo_ovr = 0`).
- **VIA PHI2 & Keyboard Inquiry**: Corrected VIA $\Phi_2$ clock mapping (`~E`), hoisted `strobe` in `keyboard.v`, and removed the premature 133ms watchdog timeout in `dataController.sv` so keyboard inquiries complete cleanly.
- **Concurrent USB & Remote Mouse**: In `nanomac_ice.py`, preserved Mac OS global `$08CF` (`CrsrCouple = 0xFF`) on `moveto` writes to prevent decoupling physical USB mouse.
- **Enhanced KVM Web App (`http://localhost:8765`)**: Dedicated background grabber thread streaming VRAM continuously at full UART speed (~3.8 FPS), instant memory-cached `/frame.bmp` long-polling with `Condition` notifications, non-blocking `/status` polling, fast raw `'W'` mouse injection (`fast_moveto`), sticky/latching OSK modifier keys + quick combo shortcuts (⌘O, ⌘Q, ⌘W, etc.), and hardware VBL-timed double-clicking (`/mouse?action=dblclick`).
