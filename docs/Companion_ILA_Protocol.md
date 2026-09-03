# Companion ILA & ICE Debugger Protocol Specification

## 1. Overview

The NanoMac ILA & ICE subsystem provides cycle-accurate logic analysis and interactive hardware execution control over the FPGA-Companion SPI link (`SPI_TARGET_ILA = 8'd5`).

---

## 2. SPI Target & Commands

Target ID: `8'd5` (`TARGET_ILA`)

### Command 0: Status & Info (`SPI_ILA_CMD_STATUS`)
Reads 7 bytes of status information from the core:
* **Byte 0: Flags**:
  * `Bit 0`: `1` = ILA is enabled / present
  * `Bit 1`: `1` = CPU is halted by ICE
  * `Bit 2`: `1` = Trigger is currently armed
  * `Bit 3`: `1` = Trigger occurred, filling post-trigger buffer
  * `Bit 4`: `1` = Buffer full / capture done (ready to read)
  * `Bits 7:5`: Protocol version (`3'b001`)
* **Byte 1..2**: Buffer depth in samples (big-endian: `512`)
* **Byte 3..4**: Trigger position sample index (0..511)
* **Byte 5..6**: Current write pointer sample index (0..511)

### Command 1: Configure Trigger & Clock (`SPI_ILA_CMD_CONFIG`)
Writes 8 configuration bytes:
* **Byte 0: Clock Select**:
  * `0`: Sample on `clk_pixel` (15.6672 MHz) every cycle
  * `1`: Sample on `busPhase == 0` (1.958 MHz, macro bus cycle rate)
* **Byte 1: Trigger Mode**:
  * `0`: Manual / Force trigger only
  * `1`: On `_cpuAS` falling edge (start of any CPU memory access)
  * `2`: On `_cpuAS == 0 && _cpuDTACK == 0` (data transfer acknowledge)
  * `3`: On 24-bit Address match: `(cpu_addr & mask) == (target & mask)`
  * `4`: On RAM collision (CPU accessing RAM during video/sound DMA)
* **Bytes 2..4**: 24-bit Target Address (big-endian)
* **Bytes 5..7**: 24-bit Target Address Mask (big-endian, e.g. `0xFFFFFF` for exact match)

### Command 2: Read Trace Buffer (`SPI_ILA_CMD_READ_SAMPLE`)
Reads consecutive samples from the trace buffer. Each sample consists of 8 bytes (64 bits, little-endian byte order).
Reading bytes auto-increments the byte index and sample pointer.

### Command 3: Arm / Disarm / Force Trigger (`SPI_ILA_CMD_ARM`)
Writes 1 byte:
* `0`: Disarm ILA
* `1`: Arm ILA (fills 64 pre-trigger samples, then waits for trigger)
* `2`: Force immediate trigger

### Command 4: ICE Execution Control (`SPI_ICE_CMD_CTRL`)
Writes up to 3 bytes:
* **Byte 0: Subcommand**:
  * `0`: **Halt**: Immediately freeze 68000 CPU clock enables (`enPhi1`/`enPhi2`).
  * `1`: **Resume**: Resume continuous full-speed CPU execution.
  * `2`: **Reset**: Force CPU reset line pulse.
  * `3`: **Step Clocks**: Advance CPU by $N$ clock phases.
  * `4`: **Step Bus Cycles**: Advance CPU by $N$ bus cycles (`_cpuAS` cycles).
* **Bytes 1..2**: 16-bit step count $N$ (big-endian, 1..65,535).

### Command 5: Live State Readout (`SPI_ICE_CMD_STATE`)
Reads the instantaneous 64-bit unlatched probe values (8 bytes, little-endian) while the CPU is halted.

---

## 3. 64-Bit Monitored Probe Layout

| Bit Range | Signal Name | Description |
|---|---|---|
| `[2:0]` | `busPhase[2:0]` | Sub-cycle phase (0..7) |
| `[3]` | `enPhi1_gated` | CPU Phase 1 clock enable |
| `[4]` | `enPhi2_gated` | CPU Phase 2 clock enable |
| `[5]` | `cpu_turbo_active` | Turbo mode active (16 MHz) |
| `[6]` | `_cpuAS` | 68000 Address Strobe (0 = active) |
| `[7]` | `_cpuUDS` | Upper Data Strobe |
| `[8]` | `_cpuLDS` | Lower Data Strobe |
| `[9]` | `_cpuRW` | Bus Read (1) / Write (0) |
| `[10]` | `_cpuDTACK` | Data Transfer Acknowledge (0 = ack) |
| `[11]` | `ram_req` | Synchronous RAM cycle requested |
| `[12]` | `rom_req` | Synchronous ROM cycle requested |
| `[13]` | `cpu_slot` | Available CPU memory time-slot |
| `[14]` | `cpuBusControl` | Active CPU 8-phase bus window |
| `[15]` | `videoBusControl`| Active Video/Audio DMA bus window |
| `[16]` | `loadPixels` | Video DMA active |
| `[17]` | `loadSound` | Sound DMA active |
| `[18]` | `refreshCycle` | SDRAM refresh active |
| `[19]` | `selectRAM` | Address decoded to RAM space |
| `[20]` | `selectROM` | Address decoded to ROM space |
| `[21]` | `selectVIA` | Address decoded to VIA peripheral |
| `[22]` | `_cpuVPA` | Valid Peripheral Address (6800 VIA cycle) |
| `[23]` | `_cpuVMA` | Valid Memory Address |
| `[25:24]`| *Spares* | Unused (tied 0) |
| `[28:26]`| `phase[2:0]` | SDRAM controller phase |
| `[29]` | `sdram_we` | SDRAM write enable |
| `[30]` | `sdram_oe` | SDRAM output enable |
| `[31]` | `ram_ready` | SDRAM initialized and ready |
| `[55:32]`| `cpuAddr[23:0]` | Full 24-bit 68000 CPU Address bus |
| `[63:56]`| `sdram_dout[15:8]`| Upper data bus byte |

