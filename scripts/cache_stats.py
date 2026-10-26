#!/usr/bin/env python3
"""Capture an ILA trace and report BRAM cache hit/enable statistics.

Usage:
    python3 scripts/cache_stats.py [--port PORT] [--baud BAUD]

Arms the on-chip ILA, waits for it to fill, then dumps 256 samples and
reports how often C$HIT (bit 25) and C$EN (bit 24) are asserted, plus how
many samples are actual ROM/RAM read cycles. This tells you whether the
2KB BRAM cache is actually hitting on the live board.
"""
import sys, time
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import nanomac_ice as ice


def main():
    port = None
    baud = 2000000
    i = 1
    while i < len(sys.argv):
        if sys.argv[i] == "--port":
            port = sys.argv[i + 1]; i += 2
        elif sys.argv[i] == "--baud":
            baud = int(sys.argv[i + 1]); i += 2
        else:
            i += 1

    ser = ice.get_connection(port, baud)
    try:
        ice.cmd_arm(ser)
        time.sleep(1.5)          # let the circular buffer fill at 80 MHz
        raw = ser.reset_input_buffer() or b""
        ser.reset_input_buffer()
        ser.write(b"B")
        data = ser.read(2048)
    finally:
        ser.close()

    n = len(data) // 8
    hits = en = mem_rd = 0
    hit_samples = []
    for i in range(n):
        v = int.from_bytes(data[i*8:(i+1)*8], "little")
        hit = bool(v & (1 << 25))
        enable = bool(v & (1 << 24))
        ctrl = v & 0x00FFFFFF
        ram_cs = bool(ctrl & (1 << 19))
        rom_cs = bool(ctrl & (1 << 20))
        dtack = bool(ctrl & (1 << 10))
        if enable:
            en += 1
        if hit:
            hits += 1
            hit_samples.append(i)
        if (ram_cs or rom_cs) and dtack:
            mem_rd += 1

    print(f"Samples          : {n}")
    print(f"C$EN asserted    : {en}/{n}   ({100*en//max(n,1)}%)")
    print(f"C$HIT asserted   : {hits}/{n}   ({100*hits//max(n,1)}%)")
    print(f"Mem-read @DTACK  : {mem_rd}/{n}")
    if hit_samples:
        print(f"First 10 hit samples: {hit_samples[:10]}")
        print("=> Cache is HITTING.")
    else:
        print("=> NO cache hits captured. Cache is not serving reads.")


if __name__ == "__main__":
    main()
