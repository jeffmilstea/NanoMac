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

try:
    import serial
except ImportError:
    import os, termios, fcntl, array
    class NativeSerial:
        def __init__(self, port, baudrate=2000000, timeout=1.0):
            self.fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
            attrs = termios.tcgetattr(self.fd)
            attrs[0] = 0; attrs[1] = 0; attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL; attrs[3] = 0
            termios.tcsetattr(self.fd, termios.TCSANOW, attrs)
            speed = array.array('I', [baudrate])
            fcntl.ioctl(self.fd, 0x80045402, speed, 1)
            self.timeout = timeout

        def write(self, data):
            return os.write(self.fd, data)

        def read(self, size=1):
            buf = bytearray()
            t0 = time.time()
            while len(buf) < size and (time.time() - t0 < self.timeout):
                try:
                    c = os.read(self.fd, size - len(buf))
                    if c: buf.extend(c)
                except BlockingIOError:
                    time.sleep(0.001)
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


def main():
    parser = argparse.ArgumentParser(description="NanoMac ILA & ICE Debugger")
    parser.add_argument("--port", help="Serial port (default: auto-detect)")
    parser.add_argument("--baud", type=int, default=2000000, help="Baud rate (default: 2000000)")
    parser.add_argument("command", choices=["state", "halt", "resume", "reset", "step", "stepbus", "trigset", "arm", "trigger", "dump", "interactive", "poke", "poked", "peek", "clear"])
    parser.add_argument("count", nargs="?", type=lambda s: int(s, 0), default=1, help="Step count / poke value / trigset mode (decimal or 0x-hex)")
    parser.add_argument("addr", nargs="?", type=lambda s: int(s, 0), default=0x0001B0, help="trigset: trigger address (default 0x0001B0)")
    parser.add_argument("mask", nargs="?", type=lambda s: int(s, 0), default=0xFFFFFF, help="trigset: address mask, 1=cared (default 0xFFFFFF)")
    parser.add_argument("--vcd", help="Save dump to VCD file for GTKWave")

    args = parser.parse_args()
    ser = get_connection(args.port, args.baud)

    if args.command == "state":
        cmd_state(ser)
    elif args.command == "halt":
        cmd_halt(ser)
    elif args.command == "resume":
        cmd_resume(ser)
    elif args.command == "reset":
        cmd_reset(ser)
    elif args.command == "step":
        cmd_step(ser, args.count)
    elif args.command == "stepbus":
        cmd_stepbus(ser, args.count)
    elif args.command == "trigset":
        cmd_trigset(ser, args.count & 0x7, args.addr & 0xFFFFFF, args.mask & 0xFFFFFF)
    elif args.command == "arm":
        cmd_arm(ser)
    elif args.command == "trigger":
        cmd_trigger(ser)
    elif args.command == "dump":
        cmd_dump_binary(ser, args.vcd)
    elif args.command == "poke":
        # write $F80008 control word: lo = args.count
        #   bit0=turbo_en bit1=turbo_ovr bit2=cache_en bit3=video_off
        #   bits[5:4]=turbo fill phase-4 (reserved in current RTL)
        # e.g. 'poke 4'  = cache on (video on)
        #      'poke 12' = cache on + video DMA off  (valid display-off test)
        ser.reset_input_buffer()
        lo = (args.count & 0xFF) if args.count else 0
        ser.write(b"P" + bytes([0x55, lo]))
        time.sleep(0.05)
        resp = ser.read(64).decode("utf-8", errors="replace").strip()
        print(f"[NanoMac ICE] Poked $F80008 lo=0x{lo:02X} "
              f"(turbo={lo & 1} ovr={(lo >> 1) & 1} cache={(lo >> 2) & 1} "
              f"video_off={(lo >> 3) & 1}) {resp}")
    elif args.command == "poked":
        # poke the $F80004 identity word (idx 1): expected back-read 0x0001
        lo = (args.count & 0xFF)
        ser.reset_input_buffer()
        ser.write(b"T" + bytes([0x00, lo]))
        time.sleep(0.05)
        resp = ser.read(64).decode("utf-8", errors="replace").strip()
        print(f"[NanoMac ICE] Poked $F80004 lo=0x{lo:02X} {resp}")
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

