# NanoMac ICE, ILA & Remote KVM User Guide

This guide covers how to use the **In-Circuit Emulator (ICE)**, **Integrated Logic Analyzer (ILA)**, and **Zero-Install Web KVM Server** on NanoMac (Tang Nano 20K).

---

## 1. Hardware Connection & Setup

All ICE, ILA, and KVM features communicate through the Tang Nano 20K's onboard USB-C serial port (BL616 bridge):
* **Serial Device**: `/dev/cu.usbserial-20230306211` (macOS auto-detected by scripts)
* **Baud Rate**: **2,000,000 baud** (2 Mbps, 8N1)
* **Concurrent Operation**: Hardware input (USB mouse/keyboard via companion MCU) and remote UART injection operate concurrently without interference.

---

## 2. In-Circuit Emulator (ICE) & Logic Analyzer (`nanomac_ice.py`)

The CLI script `scripts/nanomac_ice.py` provides interactive debugging, bus tracing, memory DMA, and hardware benchmarking.

### CPU Execution Control
```bash
# View live CPU bus status (PC address, bus cycle phase, halted flag)
python3 scripts/nanomac_ice.py state

# Halt CPU execution immediately (freezes 68000 clock enables)
python3 scripts/nanomac_ice.py halt

# Resume normal full-speed CPU execution
python3 scripts/nanomac_ice.py resume

# Pulse CPU reset
python3 scripts/nanomac_ice.py reset

# Step CPU by N clock phases (default 1)
python3 scripts/nanomac_ice.py step 10

# Step CPU by N full bus cycles (falling edges of /AS)
python3 scripts/nanomac_ice.py stepbus 1
```

### Hardware CSR Register Peek & Poke (`$F80000` - `$F8001C`)
```bash
# Dump all 8 hardware control and status registers
python3 scripts/nanomac_ice.py peek

# Configure $F80008 Control Register:
#   bit 0: turbo_en (19.6 MHz)
#   bit 1: turbo_ovr (override OSD)
#   bit 2: cache_en (BRAM 16KB zero-wait cache)
#   bit 3: video_dma_off (turn off video DMA for maximum CPU speed)
python3 scripts/nanomac_ice.py poke 4   # Cache ON, Stock speed (7.83 MHz)
python3 scripts/nanomac_ice.py poke 7   # Cache ON, Turbo ON (19.6 MHz)
python3 scripts/nanomac_ice.py poke 12  # Cache ON, Stock speed, Video DMA OFF

# Clear BRAM cache hit/miss/fill performance counters
python3 scripts/nanomac_ice.py clear
```

### Logic Analyzer (ILA) & Bus Tracing
```bash
# Configure trigger mode:
#   trigset <mode> <address> <mask>
#   mode 0: Force trigger
#   mode 1: Any /AS assertion (bus cycle start)
#   mode 2: RAM/DMA collision
#   mode 3: Address match (cpuAddr & mask == addr & mask)
#   mode 4: Hang detector (bus silence > 12 us)
python3 scripts/nanomac_ice.py trigset 3 0x4027E8 0xFFFFF0

# Arm the 512-sample circular buffer
python3 scripts/nanomac_ice.py arm

# Export trace buffer to standard VCD file for viewing in GTKWave
python3 scripts/nanomac_ice.py dump --vcd trace.vcd
```

### Direct SDRAM DMA & VRAM Fill
```bash
# Read N bytes from SDRAM byte address
python3 scripts/nanomac_ice.py memread 0x3FA700 64

# Write hex bytes to SDRAM byte address
python3 scripts/nanomac_ice.py memwrite 0x001000 "4E714E71"

# Fill the 512x342 Mac display buffer ($3FA700, 21,888 bytes) with pattern
python3 scripts/nanomac_ice.py vram checker
python3 scripts/nanomac_ice.py vram white
python3 scripts/nanomac_ice.py vram black
```

### Automated Live Hardware Benchmark
Executes a 68000 test suite at `$3FA700`, measures cycle counts across all 4 modes using the 1.9584 MHz hardware timer at `$F8000C`, and restores the Mac screen:
```bash
python3 scripts/nanomac_ice.py runbench
```

---

## 3. Remote Web KVM Server (`nanomac_kvm.py`)

A zero-install Web KVM console streaming live Mac VRAM and forwarding mouse and keyboard inputs over UART.

### Starting the Server
```bash
python3 scripts/nanomac_kvm.py
```
Open **`http://localhost:8765`** in any modern web browser or inside **VS Code Simple Browser** (`Cmd+Shift+P` -> `Simple Browser: Show`).

### Features & Capabilities
1. **High-Performance VRAM Stream (~3.8 FPS)**:
   - Dedicated background grabber thread continuously reads the 21,888-byte display buffer from SDRAM (`$3FA700`) via ICE DMA.
   - Long-polling conditional request (`/frame.bmp?id=N`) delivers frames to the browser with $<0.2\text{ ms}$ latency.
   - Live FPS and RTT latency indicators with an automatic disconnect watchdog.
2. **Concurrent Mouse & Cursor Control**:
   - Move mouse over canvas to jump the Mac cursor instantly.
   - `[ Click ]` and `[ Dbl-Click ]` buttons execute hardware VBL-timed pulses ($60\text{ ms}$ hold, $80\text{ ms}$ gap) guaranteed to trigger double-clicks in Mac OS Finder.
   - Canvas double-clicking is supported directly.
3. **Interactive On-Screen Keyboard (OSK)**:
   - Toggle with `[ ⌨ On-Screen Keyboard ]`.
   - **Sticky Modifiers**: Clicking `⌘ Cmd`, `Option`, `Shift`, or `Control` latches the modifier (highlighted in green). Clicking a regular key (e.g. `O` or `Q`) automatically sends the key with the modifier held and then unlatches it.
   - **Quick Shortcuts**: Dedicated buttons for `⌘O Open`, `⌘W Close`, `⌘S Save`, `⌘Q Quit`, `⌘A Select All`, `⌘Z Undo`, `⌘C Copy`, `⌘V Paste`.
   - **Physical Keyboard Forwarding**: Typing on your host computer keyboard forwards keypresses directly into Mac OS.
4. **Live Turbo & Cache Control**:
   - Status badges display real-time clock speed (`19.6 MHz` / `7.8 MHz`) and cache status (`ON` / `OFF`).
   - Click either badge button to live-switch hardware speed or toggle the BRAM cache.
