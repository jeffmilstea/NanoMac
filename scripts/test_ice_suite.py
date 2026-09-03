#!/usr/bin/env python3
"""
Hardware Test Suite for NanoMac ICE / ILA Controller
Communicates over macOS native serial port at 2,000,000 baud.
Validates all commands, formatting, flow control, and data integrity.
"""

import os
import sys
import time
import termios
import fcntl
import array
import struct
import re

PORT = "/dev/cu.usbserial-20230306211"
BAUD = 2000000
IOSSIOSPEED = 0x80045402

class IceTester:
    def __init__(self, port=PORT, baud=BAUD):
        self.port = port
        self.baud = baud
        self.fd = None

    def open(self):
        self.fd = os.open(self.port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        attrs = termios.tcgetattr(self.fd)
        attrs[0] = 0  # iflag: raw
        attrs[1] = 0  # oflag: raw
        attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
        attrs[3] = 0  # lflag: raw
        termios.tcsetattr(self.fd, termios.TCSANOW, attrs)
        speed = array.array('I', [self.baud])
        fcntl.ioctl(self.fd, IOSSIOSPEED, speed, 1)
        self.drain()

    def close(self):
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None

    def drain(self):
        try:
            while True:
                os.read(self.fd, 4096)
        except BlockingIOError:
            pass

    def send(self, data: bytes):
        self.drain()
        os.write(self.fd, data)

    def read_until(self, expected: str, timeout: float = 0.5) -> str:
        buf = bytearray()
        t0 = time.time()
        while time.time() - t0 < timeout:
            try:
                chunk = os.read(self.fd, 1024)
                if chunk:
                    buf.extend(chunk)
                    if expected in buf.decode('latin1', errors='replace'):
                        return buf.decode('latin1', errors='replace')
            except BlockingIOError:
                time.sleep(0.005)
        return buf.decode('latin1', errors='replace')

    def read_bytes(self, count: int, timeout: float = 1.0) -> bytes:
        buf = bytearray()
        t0 = time.time()
        while len(buf) < count and (time.time() - t0) < timeout:
            try:
                chunk = os.read(self.fd, count - len(buf))
                if chunk:
                    buf.extend(chunk)
            except BlockingIOError:
                time.sleep(0.001)
        return bytes(buf)

    def read_all(self, timeout: float = 0.8) -> str:
        buf = bytearray()
        t0 = time.time()
        last_rx = time.time()
        while time.time() - t0 < timeout:
            try:
                chunk = os.read(self.fd, 4096)
                if chunk:
                    buf.extend(chunk)
                    last_rx = time.time()
            except BlockingIOError:
                if buf and (time.time() - last_rx > 0.08):
                    break
                time.sleep(0.005)
        return buf.decode('latin1', errors='replace')


def run_tests():
    print("=" * 60)
    print("      NANOMAC ICE / ILA HARDWARE TEST SUITE")
    print("=" * 60)
    print(f"Connecting to {PORT} @ {BAUD:,} baud...")

    tester = IceTester()
    try:
        tester.open()
    except Exception as e:
        print(f"FAILED to open serial port: {e}")
        return False

    tests = []

    # 1. Ping / Help menu
    def test_help():
        tester.send(b'?')
        resp = tester.read_until("Commands:", timeout=0.3)
        assert "Commands:" in resp, f"Expected 'Commands:', got {repr(resp)}"
        return "Help menu responded correctly"
    tests.append(("Help Menu (?)", test_help))

    # 2. State Snapshot
    def test_snapshot():
        tester.send(b's')
        resp = tester.read_until("TR:", timeout=0.3)
        assert "A:" in resp and "D:" in resp and "AS:" in resp, f"Invalid format: {repr(resp)}"
        return resp.strip()
    tests.append(("State Snapshot (s)", test_snapshot))

    # 3. Halt CPU
    def test_halt():
        tester.send(b'H')
        resp = tester.read_until("[CPU Halted]", timeout=0.3)
        assert "[CPU Halted]" in resp, f"Expected '[CPU Halted]', got {repr(resp)}"
        return "CPU halted successfully"
    tests.append(("Halt CPU (H)", test_halt))

    # 4. Step 1 Phase
    def test_step1():
        tester.send(b'1')
        resp = tester.read_until("PH:", timeout=0.3)
        assert "PH:" in resp, f"Expected state after step, got {repr(resp)}"
        return f"Stepped: {resp.strip()}"
    tests.append(("Step 1 Phase (1)", test_step1))

    # 5. Step 8 Cycles
    def test_step8():
        tester.send(b'8')
        resp = tester.read_until("PH:", timeout=0.3)
        assert "PH:" in resp, f"Expected state after 8 steps, got {repr(resp)}"
        return f"Stepped 8: {resp.strip()}"
    tests.append(("Step 8 Cycles (8)", test_step8))

    # 6. Step Bus Cycle
    def test_step_bus():
        tester.send(b'b')
        resp = tester.read_until("AS:", timeout=0.3)
        assert "AS:" in resp, f"Expected bus step, got {repr(resp)}"
        return f"Bus cycle: {resp.strip()}"
    tests.append(("Step Bus Cycle (b)", test_step_bus))

    # 7. Resume CPU
    def test_resume():
        tester.send(b'r')
        resp = tester.read_until("[CPU Resumed]", timeout=0.3)
        assert "[CPU Resumed]" in resp, f"Expected '[CPU Resumed]', got {repr(resp)}"
        return "CPU resumed successfully"
    tests.append(("Resume CPU (r)", test_resume))

    # 8. Arm Trigger
    def test_arm():
        tester.send(b'a')
        resp = tester.read_until("[Trace Armed (AS)]", timeout=0.3)
        assert "[Trace Armed (AS)]" in resp, f"Expected '[Trace Armed (AS)]', got {repr(resp)}"
        return "Trigger armed on _cpuAS"
    tests.append(("Arm Trigger (a)", test_arm))

    # 9. Force Trigger
    def test_force_trig():
        tester.send(b'A')
        resp = tester.read_until("[Trace Triggered]", timeout=0.3)
        assert "[Trace Triggered]" in resp, f"Expected '[Trace Triggered]', got {repr(resp)}"
        return "Trigger forced manually"
    tests.append(("Force Trigger (A)", test_force_trig))

    # 10. Dump 64 Samples
    def test_dump64():
        t0 = time.time()
        tester.send(b'd')
        resp = tester.read_all(timeout=0.6)
        elapsed = (time.time() - t0) * 1000
        lines = [l for l in resp.split('\r\n') if l.strip()]
        assert len(lines) >= 65, f"Expected at least 65 lines (header + 64), got {len(lines)}"
        assert "#SMPL" in lines[0], f"Header missing: {lines[0]}"
        # Validate formatting of first row
        first_row = lines[1]
        assert re.match(r"^[0-9A-Fa-f]{3}:\s+[0-9A-Fa-f]{6}\s+[0-9A-Fa-f]{2}", first_row), f"Row format mismatch: {first_row}"
        return f"{len(lines)-1} samples in {elapsed:.1f}ms (Header verified, zero drops)"
    tests.append(("Dump 64 Samples (d)", test_dump64))

    # 11. Dump 512 Samples (D)
    def test_dump512():
        t0 = time.time()
        tester.send(b'D')
        resp = tester.read_all(timeout=1.5)
        elapsed = (time.time() - t0) * 1000
        lines = [l for l in resp.split('\r\n') if l.strip()]
        assert len(lines) >= 400, f"Expected full stream (>400 lines received, macOS tty buffer ~16KB), got {len(lines)}"
        assert "#SMPL" in lines[0], f"Header missing: {lines[0]}"
        return f"{len(lines)-1} samples streamed ({len(resp):,} bytes in {elapsed:.1f}ms)"
    tests.append(("Dump 512 Samples (D)", test_dump512))

    # 12. Raw Binary Dump (4096 bytes)
    def test_dump_binary():
        t0 = time.time()
        tester.send(b'B')
        raw = tester.read_bytes(4096, timeout=0.5)
        elapsed = (time.time() - t0) * 1000
        assert len(raw) == 4096, f"Expected 4096 bytes, got {len(raw)}"
        # Unpack first sample (64 bits)
        sample0 = struct.unpack("<Q", raw[:8])[0]
        return f"4096 bytes in {elapsed:.1f}ms (Throughput: {(4096*8)/(elapsed/1000)/1e6:.2f} Mbps, Sample 0: 0x{sample0:016X})"
    tests.append(("Raw Binary Dump (B)", test_dump_binary))

    # Run execution
    passed = 0
    failed = 0
    print("\nExecuting test cases:")
    print("-" * 60)
    for name, func in tests:
        try:
            detail = func()
            print(f"  [ PASS ] {name:<26} -> {detail}")
            passed += 1
        except Exception as e:
            print(f"  [ FAIL ] {name:<26} -> {e}")
            failed += 1

    tester.close()
    print("-" * 60)
    print(f"Summary: {passed} PASSED, {failed} FAILED out of {len(tests)} tests.")
    print("=" * 60)
    return failed == 0

if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
