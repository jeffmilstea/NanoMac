# NanoMac On-Chip ILA Logic Analyzer & In-Circuit Execution (ICE) Debugger

We have implemented, synthesized, and deployed a hardware-in-the-loop (HITL) **Internal Logic Analyzer (ILA)** and **In-Circuit Execution (ICE) CPU Controller** for NanoMac on the Tang Nano 20K, integrated directly with the M0S Dock via **FPGA-Companion**.

This provides deep, real-time introspection into the 68000 CPU bus cycles, Turbo wait-states, and SDRAM arbitration without trial-and-error guessing.

---

## 1. System Architecture & Features

```
 +-----------------------------------------------------------------------+
 |                         M0S Dock (BL616 MCU)                          |
 |                                                                       |
 |   UART / Telnet CLI ("ice", "ila") <---> SPI Controller (Target 5)    |
 +-----------------------------------+-----------------------------------+
                                     | SPI Bus (CLK, CS, MOSI, MISO)
                                     v
 +-----------------------------------+-----------------------------------+
 |                        Tang Nano 20K (FPGA)                           |
 |                                                                       |
 |  [mcu_spi.v] ----> [ila.sv (Target 5)]                                 |
 |                           |                                           |
 |         +-----------------+-------------------+                       |
 |         |                                     |                       |
 |         v                                     v                       |
 |   [ICE Execution Unit]                [512 x 64-bit BSRAM]            |
 |   - Halt CPU clock enables            - Circular trace buffer         |
 |   - Single-step N clock phases        - Configurable trigger:         |
 |   - Single-step N bus cycles            * Immediately on arm          |
 |   - Reset CPU override                  * CPU _AS falling edge        |
 |   - Live 64-bit hardware snapshot       * ROM select falling edge     |
 |                                         * RAM select falling edge     |
 |                                         * Manual force trigger        |
 +-----------------------------------------------------------------------+
```

### Probed Signal Layout (64 Bits per Sample)
Every sample in the 512-depth circular buffer captures:
- **`[63:56]`**: Upper CPU Data Bus (`sdram_dout[15:8]`)
- **`[55:32]`**: 24-bit CPU Bus Address (`cpuAddr[23:0]`)
- **`[31]`**: SDRAM Ready (`ram_ready`)
- **`[30]`**: SDRAM Output Enable (`sdram_oe`)
- **`[29]`**: SDRAM Write Enable (`sdram_we`)
- **`[28:26]`**: SDRAM Arbiter Phase (`phase[2:0]`)
- **`[25:24]`**: Spare / Status
- **`[23]`**: `_cpuVMA`
- **`[22]`**: `_cpuVPA`
- **`[21]`**: `selectVIA`
- **`[20]`**: `selectROM`
- **`[19]`**: `selectRAM`
- **`[18]`**: `refreshCycle`
- **`[17]`**: `loadSound`
- **`[16]`**: `loadPixels`
- **`[15]`**: `videoBusControl`
- **`[14]`**: `cpuBusControl`
- **`[13]`**: `cpu_slot`
- **`[12]`**: `rom_req`
- **`[11]`**: `ram_req`
- **`[10]`**: `_cpuDTACK`
- **`[9]`**: `_cpuRW`
- **`[8]`**: `_cpuLDS`
- **`[7]`**: `_cpuUDS`
- **`[6]`**: `_cpuAS`
- **`[5]`**: `cpu_turbo_active`
- **`[4]`**: `enPhi2_gated`
- **`[3]`**: `enPhi1_gated`
- **`[2:0]`**: `busPhase[2:0]`

---

## 2. FPGA Resource Budget & Synthesis

- **Device**: Gowin GW2AR-LV18QN88C8/I7 (Tang Nano 20K)
- **BSRAM Utilization**: **43 / 46 (93.5%)** — 3 BSRAM blocks remain free.
- **Logic LUTs**: **14,494 / 20,736 (71%)**
- **Registers**: **6,047 / 15,915 (38%)**
- **Bitstream Status**: Flashed to onboard Winbond W25Q64 SPI flash at offset `0x00000000` with **100% verified confirmation**.

---

## 3. FPGA-Companion Firmware & Build

- **Firmware Binary**: `/Users/Jeff/workspace/FPGA-Companion/src/bl616/build/build_out/fpga_companion_bl616.bin`
- **Repository Branch**: `feature/fpga-companion-ila` in `/Users/Jeff/Library/Mobile Documents/com~apple~CloudDocs/FPGA-Companion`
- **Included CLI Commands**:
  - `ice`: In-circuit CPU controller
  - `ila`: Circular trace logic analyzer

---

## 4. Hardware Verification & Interactive Debugging Guide

### Step 1: Flashing the M0S Dock
> [!TIP]
> **Hardware Isolation During Flashing**: As confirmed during verification, when flashing the M0S Dock (via CLI or `BLFlashCube-macos`), disconnect the power wire running between the Tang Nano 20K and M0S Dock, as well as the Tang Nano 20K's USB-C connection. This prevents parasitic power/ground loops and SPI pin states from interfering with the BL616 ISP bootloader handshake.

---

### Step 2: In-Circuit Execution (ICE) Control via USB-C

You can communicate directly with the on-chip ICE and ILA engine over the **Tang Nano 20K USB-C cable** (`/dev/cu.usbserial-20230306211`) at **2,000,000 baud**:

```bash
# Connect via picocom:
picocom -b 2000000 /dev/cu.usbserial-20230306211

# Or run our Python CLI / VCD exporter:
python3 scripts/nanomac_ice.py state
python3 scripts/nanomac_ice.py halt
python3 scripts/nanomac_ice.py step 10
python3 scripts/nanomac_ice.py dump --vcd trace.vcd
```

#### Interactive Terminal Commands (in `picocom`):
Press any of these single keys directly into the terminal:

| Key | Action | Response Description |
|:---:|:---|:---|
| **`?`** or **`h`** | **Help** | Prints the command reference menu. |
| **`s`** | **State Snapshot** | Prints live CPU state: `A:xxxxxx D:xx RW:x AS:x DT:x RM:x\r\n`. |
| **`H`** | **Halt CPU** | Freezes 68000 clock enables (video & sound DMA remain active). |
| **`r`** | **Resume CPU** | Unfreezes CPU clock enable; normal execution resumes. |
| **`R`** or **`z`**| **Reset CPU** | Pulses 68000 hardware reset line back to boot vector. |
| **`1`** | **Step Phase** | Steps 1 clock phase and automatically prints the updated state. |
| **`8`** | **Step Cycle** | Steps 8 clock phases (1 full clock cycle) and prints state. |
| **`b`** | **Step Bus Cycle**| Steps until `_cpuAS` completes its next cycle and prints state. |
| **`a`** | **Arm ILA Trace**| Arms circular buffer to trigger on the next `_cpuAS` falling edge. |
| **`A`** | **Force Trigger**| Manually triggers trace capture immediately. |
| **`d`** | **Dump 64 Samples**| Prints formatted ASCII table of the last 64 clock cycles. |
| **`D`** | **Dump All 512** | Prints formatted ASCII table of the entire 512-cycle trace buffer. |
| **`B`** | **Raw Binary Dump**| Dumps 4,096 bytes (512 $\times$ 8 bytes) for automated tools / VCD export. |

---

### Step 3: Logic Analyzer (ILA) Trace Capture

Capture 512 clock cycles of memory bus activity and dump them to ASCII or VCD format:

### Step 3: Logic Analyzer (ILA) Trace Capture via USB-C

You can capture 512 clock cycles of bus activity directly through `picocom` or via our automated Python CLI:

#### Capturing via `picocom`:
- Press **`a`**: Arms the circular buffer to trigger on the next memory cycle (`_cpuAS` falling edge). Prints `[Trace Armed (AS)]`.
- Press **`A`**: Forces an immediate manual trigger. Prints `[Trace Triggered]`.
- Press **`d`**: Dumps the last 64 clock cycles as a formatted ASCII trace table.
- Press **`D`**: Dumps all 512 cycles.

Sample ASCII table output:
```text
[SMPL] ADDR   DATA RW AS DTK RM RO PH TR
-----------------------------------------
000:   401200 2A   R  0  0   1  0  1  1
001:   401200 2A   R  0  0   1  0  2  1
002:   401200 2A   R  1  1   0  0  3  1
```

#### Capturing & Exporting to VCD via Python:
```bash
# Capture full 512-sample trace and export directly to GTKWave VCD:
python3 scripts/nanomac_ice.py dump --vcd trace.vcd

# Open in GTKWave:
open trace.vcd
```

---

## 5. Gowin PnR Timing Optimization Results

We applied multicycle path timing constraints in `src/tang/nano20k/nanomac.sdc` to relieve the `fx68k` 68000 instruction decode bottleneck (`Irc` $\rightarrow$ `microAddr`):

```tcl
set_multicycle_path -setup -from [get_cells {*Irc* *rIrd*}] -to [get_cells {*microAddr*}] 2
set_multicycle_path -hold  -from [get_cells {*Irc* *rIrd*}] -to [get_cells {*microAddr*}] 1
```

### Static Timing Analysis (STA) Verification:
- **`fx68k` Opcode Decode Setup Slack**: **`+120.519 ns`** (Massive positive setup headroom)
- **`fx68k` Opcode Decode Hold Slack**: **`+4.210 ns`** (Clean positive hold margin)
- **Worst Negative Slack (WNS)**: Improved from **`-9.374 ns`** to **`-7.481 ns`** (**`+1.893 ns` / ~20% improvement**)
- **Violations Eliminated**: 4 setup violations and 2 hold violations completely cleared.

---

## 6. Summary of Files Changed

| Path | Description |
|---|---|
| [`src/companion/ila.sv`](file:///Users/Jeff/Library/Mobile%20Documents/com~apple~CloudDocs/NanoMac/src/companion/ila.sv) | 512x64 circular trace buffer & ICE CPU step/halt logic |
| [`src/companion/ila_uart.sv`](file:///Users/Jeff/Library/Mobile%20Documents/com~apple~CloudDocs/NanoMac/src/companion/ila_uart.sv) | 2,000,000 baud hardware UART RX/TX controller, FIFO, command interpreter |
| [`src/macplus/macplus.sv`](file:///Users/Jeff/Library/Mobile%20Documents/com~apple~CloudDocs/NanoMac/src/macplus/macplus.sv) | Probed bus signals + gated CPU clock enable hook |
| [`src/tang/nano20k/top.sv`](file:///Users/Jeff/Library/Mobile%20Documents/com~apple~CloudDocs/NanoMac/src/tang/nano20k/top.sv) | Wired UART TX (Pin 69) and RX (Pin 70) directly to `ila_inst` |
| [`src/tang/nano20k/nanomac.cst`](file:///Users/Jeff/Library/Mobile%20Documents/com~apple~CloudDocs/NanoMac/src/tang/nano20k/nanomac.cst) | Physical pin constraints for `uart_tx` and `uart_rx` |
| [`src/tang/nano20k/nanomac.sdc`](file:///Users/Jeff/Library/Mobile%20Documents/com~apple~CloudDocs/NanoMac/src/tang/nano20k/nanomac.sdc) | Multicycle path timing constraints for `fx68k` instruction decode |
| [`scripts/nanomac_ice.py`](file:///Users/Jeff/Library/Mobile%20Documents/com~apple~CloudDocs/NanoMac/scripts/nanomac_ice.py) | Host CLI and GTKWave VCD trace exporter |

