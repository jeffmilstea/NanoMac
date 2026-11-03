#!/usr/bin/env python3
"""Authoritative max healthy /AS-silence on the live desktop.
Polls the ICE 's' snapshot (single instantaneous probe read) as fast as the
2Mbaud UART allows (~4 kHz) over ~60s of settled desktop, and tracks the
longest wall-clock run of AS:1 (bus silent). This is NOT limited by the 256
ILA ring, so it catches long silent gaps that would wrap the ring.
"""
import sys, time
sys.path.insert(0, "scripts")
from nanomac_ice import get_connection, find_serial_port

ser = get_connection(find_serial_port(), baud=2000000, timeout=0.5)
DUR = float(sys.argv[1]) if len(sys.argv) > 1 else 60.0

n_polls = 0
n_err = 0
max_run_s = 0.0
max_run_addr = "?"
run_start = None
last_addr_live = "?"
t_end = time.time() + DUR
samples = []  # (t, as_hi, addr)
while time.time() < t_end:
    t0 = time.time()
    ser.reset_input_buffer()
    ser.write(b"s")
    buf = b""
    dl = t0 + 0.20
    while time.time() < dl:
        buf += ser.read(64)
        if len(buf) >= 40 and b"\n" in buf:
            break
    txt = buf.decode("utf-8", "replace")
    if "AS:" not in txt:
        n_err += 1
        continue
    n_polls += 1
    try:
        as_hi = txt.split("AS:")[1].split()[0] == "1"
        addr = txt.split("A:")[1].split()[0]
    except Exception:
        n_err += 1
        continue
    samples.append((time.time(), as_hi, addr))
    if as_hi:
        if run_start is None:
            run_start = t0
            run_start_addr = last_addr_live
    else:
        last_addr_live = addr
        if run_start is not None:
            run = t0 - run_start
            if run > max_run_s:
                max_run_s = run
                max_run_addr = run_start_addr
            run_start = None

# finalize any open run
if run_start is not None:
    run = (time.time() - DUR) - run_start
    if run > max_run_s:
        max_run_s = run
        max_run_addr = run_start_addr

dt = samples and (samples[-1][0] - samples[0][0]) or 0
print(f"polls={n_polls} errs={n_err} over {dt:.1f}s (rate={n_polls/dt:.0f} Hz)")
print(f"TRUE MAX /AS-silence = {max_run_s*1e6:.0f} us (last live addr before it: {max_run_addr})")
# also: distribution of AS=0 (live) event intervals
live_ts = [s[0] for s in samples if not s[1]]
if len(live_ts) > 10:
    iv = [ (live_ts[i+1]-live_ts[i]) for i in range(len(live_ts)-1) ]
    iv.sort()
    n = len(iv)
    print(f"live-cycle count={n}  p50={iv[n//2]*1e6:.0f}us p90={iv[int(n*0.9)]*1e6:.0f}us p99={iv[int(n*0.99)]*1e6:.0f}us max={iv[-1]*1e6:.0f}us")
ser.close()
