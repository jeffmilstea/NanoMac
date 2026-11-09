#!/usr/bin/env python3
"""
nanomac_ice.py - Host CLI and VCD generator for NanoMac ILA & ICE Debugger
Usage:
    python3 scripts/nanomac_ice.py state
    python3 scripts/nanomac_ice.py halt
    python3 scripts/nanomac_ice.py resume
    python3 scripts/nanomac_ice.py reset
    python3 scripts/nanomac_ice.py step [N]
    python3 scripts/nanomac_ice.py stepbus
    python3 scripts/nanomac_ice.py trigset <mode> <addr> <mask>
    python3 scripts/nanomac_ice.py arm
    python3 scripts/nanomac_ice.py trigger
    python3 scripts/nanomac_ice.py dump [--vcd output.vcd]
    python3 scripts/nanomac_ice.py poke <lo>
    python3 scripts/nanomac_ice.py poked <lo>
    python3 scripts/nanomac_ice.py peek
    python3 scripts/nanomac_ice.py clear
    python3 scripts/nanomac_ice.py interactive

trigset modes: 0=force 1=AS low 2=RAM-dma-collision 3=address match 4=hang detect
  Modes 1-3 all require _AS LOW (an active CPU bus cycle), so they can NEVER
  fire on a hard hang (CPU wedged with /AS high). Use mode 4 to catch those:
    trigset 4        (addr/mask ignored; fires after HANG_THRESH=192 samples
                       ~12us of total bus silence; the last CPU cycle lands at
                       rotated index 64 of the dump with ~190 pre-hang samples)
  Mode 3 address match, mask semantics: bit=1 means CARE, 0 means don't care.
  e.g. ROM error-spin loop at $4027E8 (16-word window):
      trigset 3 0x4027E8 0xFFFFF0
  (Do NOT use $0001B0: it collides with RAM-test data reads of
   $00xxxx — false positives. The error handler lives in ROM at
   $400000+$027E8 = $4027E8.)
"""

import sys
import time
import argparse
import glob
import struct

try:
    import serial
except ImportError:
    import os, termios, fcntl, array, select
    class NativeSerial:
        def __init__(self, port, baudrate=2000000, timeout=1.0):
            self.port = port
            self.fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
            attrs = termios.tcgetattr(self.fd)
            attrs[0] = 0; attrs[1] = 0; attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL; attrs[3] = 0
            termios.tcsetattr(self.fd, termios.TCSANOW, attrs)
            speed = array.array('I', [baudrate])
            fcntl.ioctl(self.fd, 0x80045402, speed, 1)
            self.timeout = timeout

        def write(self, data):
            mv = memoryview(data)
            sent = 0
            while sent < len(mv):
                try:
                    n = os.write(self.fd, mv[sent : sent + 256])
                    sent += n
                except BlockingIOError:
                    time.sleep(0.0005)
            return sent

        def read(self, size=1):
            buf = bytearray()
            t0 = time.time()
            while len(buf) < size:
                rem_to = self.timeout - (time.time() - t0)
                if rem_to <= 0:
                    break
                r, _, _ = select.select([self.fd], [], [], rem_to)
                if not r:
                    break
                try:
                    c = os.read(self.fd, size - len(buf))
                    if c:
                        buf.extend(c)
                except BlockingIOError:
                    pass
            return bytes(buf)

        def readline(self):
            line = bytearray()
            t0 = time.time()
            while time.time() - t0 < self.timeout:
                b = self.read(1)
                if not b: break
                line.extend(b)
                if b == b'\n': break
            return bytes(line)

        def reset_input_buffer(self):
            try:
                while True: os.read(self.fd, 4096)
            except BlockingIOError: pass

        def close(self):
            if self.fd is not None:
                os.close(self.fd)
                self.fd = None


def find_serial_port():
    ports = glob.glob("/dev/cu.usbserial-*1")
    if ports:
        return ports[0]
    ports = glob.glob("/dev/cu.usbserial-*")
    if ports:
        return sorted(ports)[-1]
    return "/dev/cu.usbserial-20230306211"


def get_connection(port=None, baud=2000000, timeout=1.0):
    if port is None:
        port = find_serial_port()
    try:
        if 'serial' in sys.modules:
            ser = serial.Serial(port, baudrate=baud, timeout=timeout)
        else:
            ser = NativeSerial(port, baudrate=baud, timeout=timeout)
        return ser
    except Exception as e:
        print(f"Error opening {port}: {e}")
        sys.exit(1)


def parse_sample(raw_64):
    """
    Parse a 64-bit ILA probe sample into named signals (probe map v3, 2026-11-03):
      [63]    ram_req        CPU RAM request latched for this E-cycle
                            (0 on a colliding phase-2 tick = slot not requested)
      [62]    cache_sweep    tag-invalidation sweep in progress
      [61]    cache_en_cfg   configCache || hw_cache_en
      [60]    video_off      video/audio DMA disabled (poke $F80008 bit3)
      [59:56] reserved (v2 sdram_dout data byte - sacrificed in v3)
      [55:32] CPU logical address (24 bits)
      [31:11] sdram_rd_addr[20:0]  real SDRAM word address the FSM serviced
      [10]    turbo_active
      [9]     cache_hit   [8] cache_en
      [7]     _cpuAS
      [6]     _cpuRW (1=READ)
      [5]     selectRAM   [4] selectROM
      [3]     loadPixels  [2] loadSound   (video/audio DMA reads of SDRAM)
      [1]     videoBusControl   [0] cpuBusControl
    cpu_rd: derived — the data/addr pair belongs to a CPU access
    (selectRAM, CPU bus control, and no video/audio DMA in the cycle).
    Note: on OLD (v2) firmware the [63:56] nibble was the sdram_dout byte;
    v3 shows it as Q. decode_state_lines flags v2 lines via the format.
    """
    flags = (raw_64 >> 56) & 0xFF
    ram_req   = bool(raw_64 & (1 << 63))
    sweep     = bool(raw_64 & (1 << 62))
    cen_cfg   = bool(raw_64 & (1 << 61))
    video_off = bool(raw_64 & (1 << 60))
    data = flags & 0x0F  # v3: reserved (v2: lower data byte)
    addr = (raw_64 >> 32) & 0x00FFFFFF
    sdram_addr = (raw_64 >> 11) & 0x1FFFFF
    turbo = bool(raw_64 & (1 << 10))
    cache_hit = bool(raw_64 & (1 << 9))
    cache_en  = bool(raw_64 & (1 << 8))
    _as = bool(raw_64 & (1 << 7))
    rw = "R" if (raw_64 & (1 << 6)) else "W"
    ram_cs = bool(raw_64 & (1 << 5))
    rom_cs = bool(raw_64 & (1 << 4))
    load_px = bool(raw_64 & (1 << 3))
    load_snd = bool(raw_64 & (1 << 2))
    vid_bm = bool(raw_64 & (1 << 1))
    cpu_bm = bool(raw_64 & (1 << 0))
    cpu_rd = ram_cs and cpu_bm and not load_px and not load_snd

    return {
        "addr": addr,
        "data": data,
        "ram_req": ram_req,
        "sweep": sweep,
        "cen_cfg": cen_cfg,
        "video_off": video_off,
        "sdram_addr": sdram_addr,
        "turbo": turbo,
        "cache_hit": cache_hit,
        "cache_en": cache_en,
        "_as": _as,
        "rw": rw,
        "ram_cs": ram_cs,
        "rom_cs": rom_cs,
        "load_px": load_px,
        "load_snd": load_snd,
        "vid_bm": vid_bm,
        "cpu_bm": cpu_bm,
        "cpu_rd": cpu_rd,
    }


def read_nonempty_line(ser):
    for _ in range(5):
        line = ser.readline().decode("utf-8", errors="replace").strip()
        if line:
            return line
    return ""


def cmd_state(ser):
    ser.reset_input_buffer()
    ser.write(b"s")
    line = read_nonempty_line(ser)
    print(f"[NanoMac ICE] State: {line}")


def cmd_halt(ser):
    ser.reset_input_buffer()
    ser.write(b"H")
    time.sleep(0.01)
    resp = read_nonempty_line(ser)
    print(f"[NanoMac ICE] {resp}")


def cmd_resume(ser):
    ser.reset_input_buffer()
    ser.write(b"r")
    time.sleep(0.01)
    resp = read_nonempty_line(ser)
    print(f"[NanoMac ICE] {resp}")


def cmd_reset(ser):
    ser.reset_input_buffer()
    ser.write(b"R")
    time.sleep(0.01)
    resp = read_nonempty_line(ser)
    print(f"[NanoMac ICE] {resp}")


def cmd_step(ser, count=1):
    for i in range(count):
        ser.reset_input_buffer()
        ser.write(b"1")
        resp = read_nonempty_line(ser)
        print(f"[{i+1}/{count}] {resp}")


def cmd_stepbus(ser, count=1):
    for i in range(count):
        ser.reset_input_buffer()
        ser.write(b"b")
        resp = read_nonempty_line(ser)
        print(f"[{i+1}/{count}] {resp}")
        resp = ser.readline().decode("utf-8", errors="replace").strip()
        print(f"[Bus Step {i+1}/{count}] {resp}")


def cmd_arm(ser):
    ser.reset_input_buffer()
    ser.write(b"a")
    resp = ser.readline().decode("utf-8", errors="replace").strip()
    print(f"[NanoMac ILA] {resp}")


def cmd_trigset(ser, mode, addr, mask):
    # 't' + mode + addr(3 bytes big-endian) + mask(3 bytes big-endian)
    payload = (b"t" + bytes([mode & 0x7,
                             (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF,
                             (mask >> 16) & 0xFF, (mask >> 8) & 0xFF, mask & 0xFF]))
    ser.reset_input_buffer()
    ser.write(payload)
    time.sleep(0.02)
    print(f"[NanoMac ILA] Trigger set: mode={mode} addr=0x{addr:06X} mask=0x{mask:06X} "
          f"(applies on next 'arm')")


def cmd_trigger(ser):
    ser.reset_input_buffer()
    ser.write(b"A")
    resp = ser.readline().decode("utf-8", errors="replace").strip()
    print(f"[NanoMac ILA] {resp}")


def cmd_dump_binary(ser, vcd_filename=None):
    ser.reset_input_buffer()
    ser.write(b"B")

    # Read 2049 bytes: 1 trigger-position header byte + 2048 (256 samples * 8 bytes)
    raw = ser.read(2049)
    if len(raw) < 2049:
        print(f"Warning: Expected 2049 bytes, received {len(raw)} bytes.")
        # fall back to no-header interpretation if the old firmware is still running
        raw = raw[-2048:] if len(raw) >= 2048 else raw

    # If a header byte is present, rotate the circular buffer so that the
    # trigger point (where the trigger condition first held) is sample 0.
    # Header byte is an 8-bit wraparound counter, so wrap-aware rotate.
    if len(raw) >= 2049:
        trig_pos = raw[0] & 0xFF
        raw = raw[1:]
        n = (len(raw) - (len(raw) % 8)) // 8
        samples = []
        for i in range(n):
            # circular index: trigger sample is at raw position trig_pos
            idx = (trig_pos + i) % n
            val = int.from_bytes(raw[idx * 8 : idx * 8 + 8], byteorder="little")
            samples.append(parse_sample(val))
        print(f"Captured {len(samples)} trace samples (trigger at sample 0, pos={trig_pos}).")
    else:
        samples = []
        for i in range(0, len(raw), 8):
            sample_bytes = raw[i : i + 8]
            if len(sample_bytes) == 8:
                val = int.from_bytes(sample_bytes, byteorder="little")
                samples.append(parse_sample(val))
        print(f"Captured {len(samples)} trace samples (no trigger-position header).")

    if vcd_filename:
        write_vcd(samples, vcd_filename)
        print(f"Exported GTKWave trace to: {vcd_filename}")
    else:
        print(f"{'SMPL':<4} {'CADDR':<8} {'DATA':<4} {'SADDR':<7} {'RW':<3} {'AS':<3} {'RAM':<4} {'ROM':<4} {'CPU':<4} {'PX':<3} {'SND':<4} {'TR':<3} {'C$HIT':<5} {'C$EN':<5}")
        print("-" * 100)
        for i, s in enumerate(samples[:64]):
            print(
                f"{i:03d}  {s['addr']:06X}   {s['data']:02X}   {s['sdram_addr']:06X} {s['rw']:<3} {int(s['_as']):<3} {int(s['ram_cs']):<4} {int(s['rom_cs']):<4} {int(s['cpu_rd']):<4} {int(s['load_px']):<3} {int(s['load_snd']):<4} {int(s['turbo']):<3} {int(s['cache_hit']):<5} {int(s['cache_en']):<5}"
            )
        if len(samples) > 64:
            print(f"... and {len(samples) - 64} more samples. Pass --vcd <file.vcd> to view in GTKWave.")


def write_vcd(samples, filename):
    with open(filename, "w") as f:
        f.write("$date\n  " + time.asctime() + "\n$end\n")
        f.write("$version\n  NanoMac ILA v2\n$end\n")
        f.write("$timescale\n  64ns\n$end\n")
        f.write("$scope module nanomac_ila $end\n")
        f.write("$var wire 24 a cpu_addr [23:0] $end\n")
        f.write("$var wire 8 d data [7:0] $end\n")
        f.write("$var wire 21 s sdram_addr [20:0] $end\n")
        f.write("$var wire 1 w rw $end\n")
        f.write("$var wire 1 z as $end\n")
        f.write("$var wire 1 r ram_cs $end\n")
        f.write("$var wire 1 o rom_cs $end\n")
        f.write("$var wire 1 q cpu_rd $end\n")
        f.write("$var wire 1 t turbo $end\n")
        f.write("$var wire 1 h cache_hit $end\n")
        f.write("$var wire 1 e cache_en $end\n")
        f.write("$var wire 1 g loadPixels $end\n")
        f.write("$var wire 1 f loadSound $end\n")
        f.write("$var wire 1 RQ ram_req $end\n")
        f.write("$var wire 1 SW sweep $end\n")
        f.write("$var wire 1 CE cen_cfg $end\n")
        f.write("$var wire 1 VO video_off $end\n")
        f.write("$upscope $end\n")
        f.write("$enddefinitions $end\n")

        for t, s in enumerate(samples):
            f.write(f"#{t}\n")
            f.write(f"b{s['addr']:024b} a\n")
            f.write(f"b{s['data']:08b} d\n")
            f.write(f"b{s['sdram_addr']:021b} s\n")
            f.write(f"{1 if s['rw'] == 'R' else 0}w\n")
            f.write(f"{1 if s['_as'] else 0}z\n")
            f.write(f"{1 if s['ram_cs'] else 0}r\n")
            f.write(f"{1 if s['rom_cs'] else 0}o\n")
            f.write(f"{1 if s['cpu_rd'] else 0}q\n")
            f.write(f"{1 if s['turbo'] else 0}t\n")
            f.write(f"{1 if s['cache_hit'] else 0}h\n")
            f.write(f"{1 if s['cache_en'] else 0}e\n")
            f.write(f"{1 if s['load_px'] else 0}g\n")
            f.write(f"{1 if s['load_snd'] else 0}f\n")
            f.write(f"{1 if s['ram_req'] else 0}RQ\n")
            f.write(f"{1 if s['sweep'] else 0}SW\n")
            f.write(f"{1 if s['cen_cfg'] else 0}CE\n")
            f.write(f"{1 if s['video_off'] else 0}VO\n")


def ice_sync_uart(ser):
    """Ensure ila_uart is in S_IDLE (flushes any interrupted S_MEM_WR_DATA transfer)."""
    ser.reset_input_buffer()
    old_to = ser.timeout
    ser.timeout = 0.05
    try:
        ser.write(b"S")
        line = read_nonempty_line(ser)
        if not line.startswith("A:"):
            ser.write(b"\x00" * 2048)
            time.sleep(0.02)
            ser.reset_input_buffer()
    finally:
        ser.timeout = old_to


def ice_mem_read(ser, addr, num_bytes):
    """Read num_bytes (rounded up to even words) from SDRAM starting at byte addr."""
    ice_sync_uart(ser)
    num_words = (num_bytes + 1) // 2
    out = bytearray()
    chunk_words = 2048  # 4KB chunks
    cur_addr = addr & 0xFFFFFE
    rem_words = num_words
    while rem_words > 0:
        n = min(rem_words, chunk_words)
        hdr = bytes([
            ord('M'),
            (cur_addr >> 16) & 0xFF,
            (cur_addr >> 8) & 0xFF,
            cur_addr & 0xFF,
            (n >> 8) & 0xFF,
            n & 0xFF,
        ])
        ser.reset_input_buffer()
        ser.write(hdr)
        data = ser.read(n * 2)
        if len(data) < n * 2:
            raise RuntimeError(f"ICE memread timeout at 0x{cur_addr:06X}: got {len(data)}/{n*2} bytes")
        out.extend(data)
        cur_addr += n * 2
        rem_words -= n
    return bytes(out[:num_bytes])


def ice_mem_write(ser, addr, data_bytes):
    """Write data_bytes (padded to even length) to SDRAM starting at byte addr."""
    ice_sync_uart(ser)
    if len(data_bytes) % 2 == 1:
        data_bytes = data_bytes + b"\x00"
    num_words = len(data_bytes) // 2
    chunk_words = 256  # 512B chunks fit cleanly in USB/TTY buffers
    cur_addr = addr & 0xFFFFFE
    offset = 0
    rem_words = num_words
    while rem_words > 0:
        n = min(rem_words, chunk_words)
        hdr = bytes([
            ord('W'),
            (cur_addr >> 16) & 0xFF,
            (cur_addr >> 8) & 0xFF,
            cur_addr & 0xFF,
            (n >> 8) & 0xFF,
            n & 0xFF,
        ])
        ser.reset_input_buffer()
        ser.write(hdr + data_bytes[offset : offset + n * 2])
        ack = ser.read(1)
        if ack != b"K":
            raise RuntimeError(f"ICE memwrite failed at 0x{cur_addr:06X}: ack={ack!r}")
        cur_addr += n * 2
        offset += n * 2
        rem_words -= n


def cmd_vram(ser, pattern="checker"):
    """Fill the 512x342 Mac Plus display buffer ($3FA700, 21888 bytes) via ICE DMA."""
    VRAM_ADDR = 0x3FA700
    VRAM_BYTES = 512 * 342 // 8  # 21,888 bytes (64 bytes/row * 342 rows)
    buf = bytearray(VRAM_BYTES)
    for y in range(342):
        row_off = y * 64
        if pattern == "clear":
            b = 0x00
            buf[row_off : row_off + 64] = bytes([b] * 64)
        elif pattern == "black":
            b = 0xFF
            buf[row_off : row_off + 64] = bytes([b] * 64)
        elif pattern == "stripes":
            b = 0xFF if ((y // 8) % 2 == 0) else 0x00
            buf[row_off : row_off + 64] = bytes([b] * 64)
        elif pattern == "grid":
            for x in range(64):
                buf[row_off + x] = 0xFF if (y % 16 == 0) else (0x80 if (x % 2 == 0) else 0x00)
        else:  # checker (8x8 pixel checkerboard with border)
            b = 0xFF if ((y // 8) % 2 == 0) else 0x00
            for x in range(64):
                c = b ^ (0xFF if (x % 2 == 0) else 0x00)
                if y < 2 or y >= 340 or x == 0 or x == 63:
                    c = 0xFF
                buf[row_off + x] = c
    t0 = time.time()
    ice_mem_write(ser, VRAM_ADDR, bytes(buf))
    dt = (time.time() - t0) * 1000.0
    print(f"[NanoMac ICE] Filled 512x342 display buffer ($3FA700, {VRAM_BYTES} bytes) with '{pattern}' in {dt:.1f} ms")


def ice_mouse(ser, dx, dy, btn=0xFF):
    """Inject mouse movement (dx, dy: signed 8-bit) and button state over UART 'm' command."""
    btn_b = 0xFF if btn is None else (int(btn) & 0xFF)
    dx_b = int(dx) & 0xFF
    dy_b = int(dy) & 0xFF
    ice_sync_uart(ser)
    ser.write(bytes([ord("m"), btn_b, dx_b, dy_b]))
    time.sleep(0.005)


def ice_fast_mem_read(ser, addr, num_bytes, chunk_words=2736):
    """Fast read num_bytes from SDRAM without ice_sync_uart overhead."""
    num_words = (num_bytes + 1) // 2
    out = bytearray()
    cur_addr = addr & 0xFFFFFE
    rem_words = num_words
    while rem_words > 0:
        n = min(rem_words, chunk_words)
        hdr = bytes([
            ord('M'),
            (cur_addr >> 16) & 0xFF,
            (cur_addr >> 8) & 0xFF,
            cur_addr & 0xFF,
            (n >> 8) & 0xFF,
            n & 0xFF,
        ])
        ser.write(hdr)
        data = ser.read(n * 2)
        if len(data) < n * 2:
            raise RuntimeError(f"Fast memread timeout at 0x{cur_addr:06X}: got {len(data)}/{n*2}")
        out.extend(data)
        cur_addr += n * 2
        rem_words -= n
    return bytes(out[:num_bytes])


def fast_moveto(ser, x, y, click=False):
    """Ultra-fast Mac cursor position update directly via raw W commands (no sync/logging)."""
    x = max(0, min(511, int(x)))
    y = max(0, min(341, int(y)))
    pt = struct.pack(">hh", y, x)
    # 1. Write MTemp ($0828), RawMouse ($082C), Mouse ($0830) (12 bytes = 6 words)
    hdr1 = bytes([ord('W'), 0x00, 0x08, 0x28, 0x00, 0x06]) + (pt * 3)
    ser.write(hdr1)
    ser.read(1)  # wait 'K' ack
    # 2. Write CrsrNew ($08CE) = 0x01, CrsrCouple ($08CF) = 0xFF (2 bytes = 1 word)
    hdr2 = bytes([ord('W'), 0x00, 0x08, 0xCE, 0x00, 0x01, 0x01, 0xFF])
    ser.write(hdr2)
    ser.read(1)  # wait 'K' ack
    if click:
        ser.write(bytes([ord("m"), 1, 0, 0]))
        ser.write(bytes([ord("m"), 0, 0, 0]))


def cmd_moveto(ser, x, y, click=False):
    """Set Mac cursor position directly via low-memory globals ($0828, $082C, $0830, $08CE)."""
    x = max(0, min(511, int(x)))
    y = max(0, min(341, int(y)))
    pt = struct.pack(">hh", y, x)
    # Write MTemp ($0828), RawMouse ($082C), Mouse ($0830) (12 bytes)
    ice_mem_write(ser, 0x0828, pt * 3)
    # Write CrsrNew ($08CE) = 0x01 (tell QuickDraw/cursor task cursor moved)
    # and CrsrCouple ($08CF) = 0xFF (keep physical USB mouse coupled to cursor)
    ice_mem_write(ser, 0x08CE, b"\x01\xFF")
    if click:
        time.sleep(0.01)
        ice_mouse(ser, 0, 0, btn=1)
        time.sleep(0.05)
        ice_mouse(ser, 0, 0, btn=0)
    print(f"[NanoMac ICE] Cursor moved to ({x}, {y})" + (" [click]" if click else ""))


def ice_kbd(ser, scancode):
    """Inject keyboard event (bit 7: 0=press, 1=release; bits 6:0: HID scancode) over UART 'k' command."""
    ser.write(bytes([ord("k"), int(scancode) & 0xFF]))


def ice_send_key(ser, scancode):
    """Send key press and release for a scancode."""
    ice_kbd(ser, scancode & 0x7F)
    time.sleep(0.03)
    ice_kbd(ser, (scancode & 0x7F) | 0x80)


def ice_get_hw_status(ser):
    """Read hardware registers via 'Q' and return live status dict."""
    ser.write(b"Q")
    resp = bytearray()
    t0 = time.time()
    while time.time() - t0 < 0.15:
        line = ser.readline()
        if not line:
            break
        resp.extend(line)
        if b"F8001C:" in line:
            break
    resp_str = resp.decode("utf-8", errors="replace")
    reg2_val = 0
    for line in resp_str.splitlines():
        if "F80008:" in line:
            part = line.split("F80008:")[1].strip()
            if part:
                try:
                    reg2_val = int(part[:4], 16)
                except ValueError:
                    pass
    turbo = bool(reg2_val & 0x0100) # bit 8: cpu_turbo_active
    cache = bool(reg2_val & 0x0400) # bit 10: cache_en_cfg
    return {"turbo": turbo, "cache": cache, "raw": f"0x{reg2_val:04X}"}


def ice_set_turbo(ser, enable):
    """Set Turbo ON/OFF via poke $F80008, preserving current cache setting."""
    st = ice_get_hw_status(ser)
    cur_cache = 1 if st["cache"] else 0
    lo = (0x03 if enable else 0x02) | (cur_cache << 2)
    ice_sync_uart(ser)
    ser.write(b"P" + bytes([0x55, lo]))
    time.sleep(0.02)
    return ice_get_hw_status(ser)


def ice_set_cache(ser, enable):
    """Set Cache ON/OFF via poke $F80008, preserving current turbo setting."""
    st = ice_get_hw_status(ser)
    cur_turbo = 1 if st["turbo"] else 0
    lo = (0x02 | cur_turbo) | ((1 if enable else 0) << 2)
    ice_sync_uart(ser)
    ser.write(b"P" + bytes([0x55, lo]))
    time.sleep(0.02)
    return ice_get_hw_status(ser)


def cmd_runbench(ser):
    """
    Inject and run a bare-metal 68000 CPU/cache benchmark via the Level 1 VBL vector ($000064)
    across all 4 hardware modes (Stock/Turbo x Cache OFF/ON), using the $F8000C 1.9584 MHz
    hardware cycle timer and $F80010-$F80018 hardware cache counters, then cleanly restore RAM.
    Uses $3FA700 (top 4 scanlines of video buffer, saved & restored) so the 68000 stack below
    $3FA700 is never touched.
    """
    CODE_ADDR = 0x3FA700
    STAT_ADDR = 0x3FA7C0
    DATA_ADDR = 0x3FA7D0
    VEC_ADDR  = 0x000064  # Level 1 VIA VBL Autovector (fires at 60.15 Hz when SR IPL=0)

    saved_vec  = ice_mem_read(ser, VEC_ADDR, 4)
    saved_area = ice_mem_read(ser, CODE_ADDR, 256)
    orig_vbl   = int.from_bytes(saved_vec, "big")
    print(f"[NanoMac ICE] Saved VBL vector ($000064 -> 0x{orig_vbl:08X}) and 256B at $3FA700")

    # Assemble 68000 benchmark routine at $3FA700:
    # 500 iterations of a 10-instruction RAM + ROM + ALU loop (5,000 instructions total)
    loop_body = bytes.fromhex(
        "3410"          # MOVE.W (A0),D2       ; RAM read
        "D451"          # ADD.W  (A1),D2       ; ROM read + ALU
        "D242"          # ADD.W  D2,D1         ; accumulate
        "E349"          # LSL.W  #1,D1         ; shift
        "B342"          # EOR.W  D1,D2         ; xor
        "34280002"      # MOVE.W 2(A0),D2      ; RAM displaced read
        "D4690002"      # ADD.W  2(A1),D2      ; ROM displaced read
        "5241"          # ADDQ.W #1,D1         ; increment
    )
    dbf_disp = (-len(loop_body) - 2) & 0xFFFF
    loop_code = loop_body + b"\x51\xC8" + dbf_disp.to_bytes(2, "big")

    inner = (
        bytes.fromhex(
            "48E7F0C0"          # MOVEM.L D0-D3/A0-A1,-(SP)
            "40E7"              # MOVE    SR,-(SP)
            "46FC2700"          # MOVE    #$2700,SR (mask interrupts during timed pass)
            "41F9003FA7D0"      # LEA     $003FA7D0,A0
            "43F900400100"      # LEA     $00400100,A1
            # Warmup pass (50 iterations) so cache is hot when enabled:
            "303C0031"          # MOVE.W  #49,D0
            "7200"              # MOVEQ   #0,D1
        )
        + loop_code
        + bytes.fromhex(
            # Clear $F8000C timer + $F80010..18 cache counters:
            "33FC550000F80010"  # MOVE.W  #$5500,$00F80010
            # Timed pass (500 iterations = 499):
            "303C01F3"          # MOVE.W  #499,D0
            "7200"              # MOVEQ   #0,D1
        )
        + loop_code
        + bytes.fromhex(
            "33F900F8000C003FA7C2"  # MOVE.W $00F8000C,$003FA7C2 (timer ticks)
            "33F900F80010003FA7C4"  # MOVE.W $00F80010,$003FA7C4 (cache_hits)
            "33F900F80014003FA7C6"  # MOVE.W $00F80014,$003FA7C6 (cache_misses)
            "33F900F80018003FA7C8"  # MOVE.W $00F80018,$003FA7C8 (cache_fills)
            "33C1003FA7CA"          # MOVE.W D1,$003FA7CA        (checksum)
            "33FCCAFE003FA7C0"      # MOVE.W #$CAFE,$003FA7C0    (done magic)
            "46DF"                  # MOVE    (SP)+,SR
            "4CDF030F"              # MOVEM.L (SP)+,D0-D3/A0-A1
        )
    )
    bne_disp = len(inner) + 2
    code = (
        bytes.fromhex("0C790000003FA7C0")  # CMP.W #$0000,$003FA7C0
        + b"\x66\x00" + bne_disp.to_bytes(2, "big")  # BNE.W done_jmp
        + inner
        + b"\x4E\xF9" + orig_vbl.to_bytes(4, "big")  # JMP orig_vbl
    )
    assert CODE_ADDR + len(code) <= STAT_ADDR, f"Code ({len(code)}B) overlaps STAT_ADDR!"

    modes = [
        ("Stock (7.83 MHz) + Cache OFF", 0x02),  # turbo=0, ovr=1, cache=0
        ("Stock (7.83 MHz) + Cache ON ", 0x06),  # turbo=0, ovr=1, cache=1
        ("Turbo (19.6 MHz) + Cache OFF", 0x03),  # turbo=1, ovr=1, cache=0
        ("Turbo (19.6 MHz) + Cache ON ", 0x07),  # turbo=1, ovr=1, cache=1
    ]

    results = []
    try:
        ice_mem_write(ser, STAT_ADDR, b"\xFF\xFF" + b"\x00" * 10)
        ice_mem_write(ser, CODE_ADDR, code)
        ice_mem_write(ser, DATA_ADDR, bytes.fromhex("123456789ABCDEF0"))

        for label, poke_lo in modes:
            ice_sync_uart(ser)
            ser.write(b"P" + bytes([0x55, poke_lo]))
            time.sleep(0.01)
            ice_mem_write(ser, STAT_ADDR, b"\x00" * 12)
            ice_mem_write(ser, VEC_ADDR, CODE_ADDR.to_bytes(4, "big"))

            # Wait up to 250ms for VBL to fire (poll STAT_ADDR via unused SDRAM slots without halting CPU)
            t0 = time.time()
            while time.time() - t0 < 0.25:
                time.sleep(0.03)
                stat = ice_mem_read(ser, STAT_ADDR, 12)
                magic = int.from_bytes(stat[0:2], "big")
                if magic == 0xCAFE:
                    ticks  = int.from_bytes(stat[2:4], "big")
                    hits   = int.from_bytes(stat[4:6], "big")
                    misses = int.from_bytes(stat[6:8], "big")
                    fills  = int.from_bytes(stat[8:10], "big")
                    cksum  = int.from_bytes(stat[10:12], "big")
                    results.append((label, ticks, hits, misses, fills, cksum))
                    break
            else:
                results.append((label, -1, 0, 0, 0, 0))
            ice_mem_write(ser, VEC_ADDR, saved_vec)
    finally:
        ice_mem_write(ser, VEC_ADDR, saved_vec)
        ice_mem_write(ser, CODE_ADDR, saved_area)
        ice_sync_uart(ser)
        ser.write(b"P" + bytes([0x55, 0x00]))  # restore hw_turbo_ovr = 0 so OSD settings remain in control
        time.sleep(0.01)
        print("[NanoMac ICE] Restored VBL vector & VRAM; System 7 resumed cleanly (OSD control restored).\n")

    base_ticks = results[0][1] if results and results[0][1] > 0 else 1
    print(f"{'Mode':<30} {'Ticks (510ns)':<14} {'Time (ms)':<10} {'Speedup':<9} {'Hits':<7} {'Misses':<7} {'Checksum'}")
    print("-" * 92)
    for label, ticks, hits, misses, fills, cksum in results:
        if ticks > 0:
            ms = ticks * 0.00051064
            sp = base_ticks / ticks
            print(f"{label:<30} {ticks:<14d} {ms:<10.3f} {sp:<8.2f}x {hits:<7d} {misses:<7d} 0x{cksum:04X}")
        else:
            print(f"{label:<30} TIMEOUT")


def main():
    parser = argparse.ArgumentParser(description="NanoMac ILA & ICE Debugger")
    parser.add_argument("--port", help="Serial port (default: auto-detect)")
    parser.add_argument("--baud", type=int, default=2000000, help="Baud rate (default: 2000000)")
    parser.add_argument("command", choices=["state", "halt", "resume", "reset", "step", "stepbus", "trigset", "arm", "trigger", "dump", "interactive", "poke", "poked", "peek", "clear", "memread", "memwrite", "vram", "runbench", "mouse", "moveto"])
    parser.add_argument("count", nargs="?", default=1, help="Step count / poke value / trigset mode / vram pattern / address / dx / x")
    parser.add_argument("addr", nargs="?", default=0x0001B0, help="trigset: trigger address / memread length / memwrite hex / dy / y")
    parser.add_argument("mask", nargs="?", default=None, help="trigset: address mask / mouse btn / moveto click")
    parser.add_argument("--vcd", help="Save dump to VCD file for GTKWave")

    args = parser.parse_args()
    ser = get_connection(args.port, args.baud)

    int_count = int(args.count, 0) if isinstance(args.count, str) and (args.count.isdigit() or args.count.startswith("0x") or args.count.startswith("0X") or (args.count.startswith("-") and args.count[1:].isdigit())) else (args.count if isinstance(args.count, int) else 1)
    int_addr  = int(args.addr, 0)  if isinstance(args.addr, str)  and (args.addr.isdigit()  or args.addr.startswith("0x")  or args.addr.startswith("0X")  or (args.addr.startswith("-") and args.addr[1:].isdigit()))  else (args.addr  if isinstance(args.addr, int)  else 0x0001B0)
    int_mask  = int(args.mask, 0)  if (args.mask is not None and isinstance(args.mask, str) and (args.mask.isdigit() or args.mask.startswith("0x") or args.mask.startswith("0X"))) else (args.mask if isinstance(args.mask, int) else 0xFFFFFF)

    if args.command == "state":
        cmd_state(ser)
    elif args.command == "halt":
        cmd_halt(ser)
    elif args.command == "resume":
        cmd_resume(ser)
    elif args.command == "reset":
        cmd_reset(ser)
    elif args.command == "step":
        cmd_step(ser, int_count)
    elif args.command == "stepbus":
        cmd_stepbus(ser, int_count)
    elif args.command == "trigset":
        cmd_trigset(ser, int_count & 0x7, int_addr & 0xFFFFFF, int_mask & 0xFFFFFF)
    elif args.command == "arm":
        cmd_arm(ser)
    elif args.command == "trigger":
        cmd_trigger(ser)
    elif args.command == "dump":
        cmd_dump_binary(ser, args.vcd)
    elif args.command == "poke":
        # write $F80008 control word: lo = int_count
        #   bit0=turbo_en bit1=turbo_ovr bit2=cache_en bit3=video_off
        #   bits[5:4]=turbo fill phase-4 (reserved in current RTL)
        # e.g. 'poke 4'  = cache on (video on)
        #      'poke 12' = cache on + video DMA off  (valid display-off test)
        ser.reset_input_buffer()
        lo = (int_count & 0xFF) if int_count else 0
        ser.write(b"P" + bytes([0x55, lo]))
        time.sleep(0.05)
        resp = ser.read(64).decode("utf-8", errors="replace").strip()
        print(f"[NanoMac ICE] Poked $F80008 lo=0x{lo:02X} "
              f"(turbo={lo & 1} ovr={(lo >> 1) & 1} cache={(lo >> 2) & 1} "
              f"video_off={(lo >> 3) & 1}) {resp}")
    elif args.command == "poked":
        # poke the $F80004 identity word (idx 1): expected back-read 0x0001
        lo = (int_count & 0xFF)
        ser.reset_input_buffer()
        ser.write(b"T" + bytes([0x00, lo]))
        time.sleep(0.05)
        resp = ser.read(64).decode("utf-8", errors="replace").strip()
        print(f"[NanoMac ICE] Poked $F80004 lo=0x{lo:02X} {resp}")
    elif args.command == "memread":
        data = ice_mem_read(ser, int_count, int_addr)
        for i in range(0, len(data), 16):
            chunk = data[i : i + 16]
            hex_s = " ".join(f"{b:02X}" for b in chunk)
            print(f"{int_count + i:06X}: {hex_s}")
    elif args.command == "memwrite":
        raw = bytes.fromhex(str(args.addr))
        ice_mem_write(ser, int_count, raw)
        print(f"[NanoMac ICE] Wrote {len(raw)} bytes to 0x{int_count:06X}")
    elif args.command == "vram":
        pat = str(args.count) if args.count != 1 else "checker"
        cmd_vram(ser, pat)
    elif args.command == "runbench":
        cmd_runbench(ser)
    elif args.command == "mouse":
        dx = int(args.count, 0) if isinstance(args.count, str) else int(args.count)
        dy = int(args.addr, 0) if isinstance(args.addr, str) else int(args.addr)
        btn = 0xFF
        if args.mask is not None:
            s_mask = str(args.mask).lower()
            btn = 1 if s_mask in ["1", "click", "down", "press"] else (0 if s_mask in ["0", "up", "release"] else int(args.mask, 0))
        ice_mouse(ser, dx, dy, btn)
    elif args.command == "moveto":
        x = int(args.count, 0) if isinstance(args.count, str) else int(args.count)
        y = int(args.addr, 0) if isinstance(args.addr, str) else int(args.addr)
        click = False
        if args.mask is not None:
            click = str(args.mask).lower() in ["1", "true", "click", "yes"]
        cmd_moveto(ser, x, y, click)
    elif args.command == "clear":
        # clear cache stat counters (hits/misses/fills)
        ser.reset_input_buffer()
        ser.write(b"C")
        time.sleep(0.05)
        resp = read_nonempty_line(ser)
        print(f"[NanoMac ICE] {resp}")
    elif args.command == "peek":
        # read all 8 hw registers $F80000-$F8001C
        ser.reset_input_buffer()
        ser.write(b"Q")
        time.sleep(0.15)
        resp = ser.read(512).decode("utf-8", errors="replace").strip()
        print(f"[NanoMac ICE] Peek:\n{resp}")
    elif args.command == "interactive":
        print("NanoMac ICE Interactive Console. Commands: s, H, r, R, 1, 8, b, a, A, d, D, B, q")
        while True:
            cmd = input("ICE> ").strip()
            if cmd == "q":
                break
            elif cmd in ["s", "H", "r", "R", "1", "8", "b", "a", "A", "d", "D", "B"]:
                ser.write(cmd.encode("ascii"))
                time.sleep(0.02)
                resp = ser.read_all().decode("utf-8", errors="replace")
                print(resp, end="")
            else:
                print("Unknown command. Type '?' for help.")


if __name__ == "__main__":
    main()

