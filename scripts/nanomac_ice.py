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
    python3 scripts/nanomac_ice.py arm
    python3 scripts/nanomac_ice.py trigger
    python3 scripts/nanomac_ice.py dump [--vcd output.vcd]
    python3 scripts/nanomac_ice.py interactive
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
    Parse a 64-bit ILA probe sample into named signals:
      [63:56] Data bus (upper 8 bits)
      [55:32] Address bus (24 bits)
      [31:29] Spares
      [28:26] SDRAM phase
      [25:24] Spares
      [23:0]  Mac control probes:
        [22] RAM chip select
        [21] VIA chip select
        [20] ROM chip select
        [19] RAM request
        [10] _cpuDTACK
        [9]  cpuRW
        [6]  _cpuAS
        [5]  Turbo mode active
        [4:0] Bus cycle / phase
    """
    data = (raw_64 >> 56) & 0xFF
    addr = (raw_64 >> 32) & 0x00FFFFFF
    phase = (raw_64 >> 26) & 0x7
    cache_hit = bool(raw_64 & (1 << 25))
    cache_en  = bool(raw_64 & (1 << 24))
    ctrl = raw_64 & 0x00FFFFFF

    ram_cs = bool(ctrl & (1 << 22))
    via_cs = bool(ctrl & (1 << 21))
    rom_cs = bool(ctrl & (1 << 20))
    ram_req = bool(ctrl & (1 << 19))
    dtack = bool(ctrl & (1 << 10))
    rw = "R" if (ctrl & (1 << 9)) else "W"
    _as = bool(ctrl & (1 << 6))
    turbo = bool(ctrl & (1 << 5))

    return {
        "addr": addr,
        "data": data,
        "phase": phase,
        "ram_cs": ram_cs,
        "via_cs": via_cs,
        "rom_cs": rom_cs,
        "ram_req": ram_req,
        "dtack": dtack,
        "rw": rw,
        "_as": _as,
        "turbo": turbo,
        "cache_hit": cache_hit,
        "cache_en": cache_en,
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


def cmd_trigger(ser):
    ser.reset_input_buffer()
    ser.write(b"A")
    resp = ser.readline().decode("utf-8", errors="replace").strip()
    print(f"[NanoMac ILA] {resp}")


def cmd_dump_binary(ser, vcd_filename=None):
    ser.reset_input_buffer()
    ser.write(b"B")

    # Read 2048 bytes (256 samples * 8 bytes) — ILA trimmed to 256 samples
    raw = ser.read(2048)
    if len(raw) < 2048:
        print(f"Warning: Expected 2048 bytes, received {len(raw)} bytes.")

    samples = []
    for i in range(0, len(raw), 8):
        sample_bytes = raw[i : i + 8]
        if len(sample_bytes) == 8:
            val = int.from_bytes(sample_bytes, byteorder="little")
            samples.append(parse_sample(val))

    print(f"Captured {len(samples)} trace samples.")

    if vcd_filename:
        write_vcd(samples, vcd_filename)
        print(f"Exported GTKWave trace to: {vcd_filename}")
    else:
        print(f"{'SMPL':<4} {'ADDR':<8} {'DATA':<4} {'RW':<3} {'AS':<3} {'DTACK':<5} {'RAM':<4} {'ROM':<4} {'PH':<3} {'TURBO':<5} {'C$HIT':<5} {'C$EN':<5}")
        print("-" * 70)
        for i, s in enumerate(samples[:64]):
            print(
                f"{i:03d}  {s['addr']:06X}   {s['data']:02X}   {s['rw']:<3} {int(s['_as']):<3} {int(s['dtack']):<5} {int(s['ram_cs']):<4} {int(s['rom_cs']):<4} {s['phase']:<3} {int(s['turbo']):<5} {int(s['cache_hit']):<5} {int(s['cache_en']):<5}"
            )
        if len(samples) > 64:
            print(f"... and {len(samples) - 64} more samples. Pass --vcd <file.vcd> to view in GTKWave.")


def write_vcd(samples, filename):
    with open(filename, "w") as f:
        f.write("$date\n  " + time.asctime() + "\n$end\n")
        f.write("$version\n  NanoMac ILA\n$end\n")
        f.write("$timescale\n  10ns\n$end\n")
        f.write("$scope module nanomac_ila $end\n")
        f.write("$var wire 24 a addr [23:0] $end\n")
        f.write("$var wire 8 d data [7:0] $end\n")
        f.write("$var wire 1 w rw $end\n")
        f.write("$var wire 1 s as $end\n")
        f.write("$var wire 1 k dtack $end\n")
        f.write("$var wire 1 r ram_cs $end\n")
        f.write("$var wire 1 o rom_cs $end\n")
        f.write("$var wire 3 p phase [2:0] $end\n")
        f.write("$var wire 1 t turbo $end\n")
        f.write("$upscope $end\n")
        f.write("$enddefinitions $end\n")

        for t, s in enumerate(samples):
            f.write(f"#{t}\n")
            f.write(f"b{s['addr']:024b} a\n")
            f.write(f"b{s['data']:08b} d\n")
            f.write(f"{1 if s['rw'] == 'R' else 0}w\n")
            f.write(f"{1 if s['_as'] else 0}s\n")
            f.write(f"{1 if s['dtack'] else 0}k\n")
            f.write(f"{1 if s['ram_cs'] else 0}r\n")
            f.write(f"{1 if s['rom_cs'] else 0}o\n")
            f.write(f"b{s['phase']:03b} p\n")
            f.write(f"{1 if s['turbo'] else 0}t\n")


def main():
    parser = argparse.ArgumentParser(description="NanoMac ILA & ICE Debugger")
    parser.add_argument("--port", help="Serial port (default: auto-detect)")
    parser.add_argument("--baud", type=int, default=2000000, help="Baud rate (default: 2000000)")
    parser.add_argument("command", choices=["state", "halt", "resume", "reset", "step", "stepbus", "arm", "trigger", "dump", "interactive"])
    parser.add_argument("count", nargs="?", type=int, default=1, help="Step count")
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
    elif args.command == "arm":
        cmd_arm(ser)
    elif args.command == "trigger":
        cmd_trigger(ser)
    elif args.command == "dump":
        cmd_dump_binary(ser, args.vcd)
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

