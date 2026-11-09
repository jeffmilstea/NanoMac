#!/usr/bin/env python3
"""
NanoMac KVM — Zero-Install Web App for Remote Mac Plus Control
Streams 512x342 1-bit Mac VRAM ($3FA700) and forwards mouse/keyboard over UART.

Access at http://localhost:8765 (works in VS Code Simple Browser, Safari, Chrome, Firefox).
"""

import argparse
import io
import json
import os
import struct
import sys
import threading
import time
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# Import low-level UART helpers from nanomac_ice
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from nanomac_ice import (
    get_connection,
    ice_sync_uart,
    ice_mem_read,
    ice_fast_mem_read,
    ice_mem_write,
    ice_mouse,
    cmd_moveto,
    fast_moveto,
    ice_kbd,
    ice_send_key,
    ice_get_hw_status,
    ice_set_turbo,
    ice_set_cache,
)

VRAM_ADDR  = 0x3FA700
VRAM_BYTES = 512 * 342 // 8  # 21,888 bytes (64 bytes/row * 342 rows)

# 1-bit Top-Down BMP Header (62 bytes total: 14B file header + 40B DIB header + 8B palette)
BMP_HEADER = (
    struct.pack("<2sIHHI", b"BM", 14 + 40 + 8 + VRAM_BYTES, 0, 0, 62) +
    struct.pack("<IiiHHIIiiII", 40, 512, -342, 1, 1, 0, VRAM_BYTES, 2835, 2835, 2, 2) +
    b"\xFF\xFF\xFF\x00\x00\x00\x00\x00"
)

HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>NanoMac KVM Console</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: #16171a;
    color: #e0e2e8;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    display: flex;
    flex-direction: column;
    align-items: center;
    min-height: 100vh;
    padding: 12px 16px;
    user-select: none;
  }
  header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
    max-width: 1060px;
    margin-bottom: 10px;
    flex-wrap: wrap;
    gap: 8px;
  }
  h1 { font-size: 1.15rem; font-weight: 700; color: #f0f2f5; display: flex; align-items: center; gap: 8px; }
  .logo { font-size: 1.25rem; }
  .stats { font-size: 0.85rem; color: #8e94a0; display: flex; gap: 14px; align-items: center; flex-wrap: wrap; }
  .stats span b { color: #61afef; }
  .screen-container {
    position: relative;
    background: #000;
    border: 2px solid #2e323a;
    border-radius: 6px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.5);
    overflow: hidden;
    cursor: crosshair;
  }
  #screen {
    display: block;
    width: 1024px;
    height: 684px;
    image-rendering: pixelated;
    image-rendering: crisp-edges;
  }
  .controls {
    display: flex;
    gap: 8px;
    margin-top: 10px;
    width: 100%;
    max-width: 1060px;
    flex-wrap: wrap;
    align-items: center;
  }
  button {
    background: #252830;
    color: #e0e2e8;
    border: 1px solid #3e4451;
    border-radius: 5px;
    padding: 6px 12px;
    font-size: 0.82rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s ease;
  }
  button:hover { background: #323846; border-color: #61afef; color: #fff; }
  button:active { background: #404859; }
  .badge-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: 4px;
    font-size: 0.8rem;
    cursor: pointer;
    border: 1px solid transparent;
  }
  .badge-on { background: #1b382b; color: #98c379; border-color: #2c6e49; }
  .badge-off { background: #3b2828; color: #e06c75; border-color: #633333; }
  .badge-btn:hover { filter: brightness(1.2); }

  /* On-Screen Keyboard */
  .osk-container {
    margin-top: 12px;
    width: 100%;
    max-width: 1060px;
    background: #1e2025;
    border: 1px solid #333842;
    border-radius: 8px;
    padding: 10px;
    display: none;
    flex-direction: column;
    gap: 6px;
    box-shadow: 0 6px 18px rgba(0,0,0,0.4);
  }
  .osk-row {
    display: flex;
    gap: 5px;
    justify-content: center;
  }
  .key {
    background: #2c313a;
    color: #d7dae0;
    border: 1px solid #3e4451;
    border-bottom: 2px solid #21252b;
    border-radius: 4px;
    min-width: 36px;
    height: 36px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.82rem;
    font-family: inherit;
    font-weight: 500;
    cursor: pointer;
    padding: 0 6px;
    transition: all 0.08s;
  }
  .key:hover { background: #3e4451; color: #fff; }
  .key:active, .key.active { background: #4b5263; border-bottom: 1px solid #3e4451; transform: translateY(1px); color: #61afef; }
  .key.latched { background: #1b4d3e !important; color: #50fa7b !important; border-color: #50fa7b !important; box-shadow: 0 0 10px rgba(80, 250, 123, 0.45); }
  .key-wide  { min-width: 54px; }
  .key-wider { min-width: 68px; }
  .key-space { min-width: 280px; }
  .key-mod   { background: #22262d; color: #abb2bf; font-size: 0.76rem; }

  .osk-shortcuts {
    display: flex;
    gap: 6px;
    align-items: center;
    flex-wrap: wrap;
    padding-bottom: 4px;
    border-bottom: 1px solid #2e323a;
    margin-bottom: 4px;
  }
  .shortcut-btn {
    background: #252830;
    color: #98c379;
    border: 1px solid #3e4451;
    border-radius: 4px;
    padding: 4px 8px;
    font-size: 0.78rem;
    font-weight: 600;
    cursor: pointer;
  }
  .shortcut-btn:hover { background: #323846; border-color: #98c379; color: #fff; }
</style>
</head>
<body>

<header>
  <h1><span class="logo"></span> NanoMac KVM</h1>
  <div class="stats">
    <span>FPS: <b id="stat-fps">0.0</b></span>
    <span>RTT: <b id="stat-ms">0</b> ms</span>
    <span>Cursor: <b id="stat-cur">(0, 0)</b></span>
    <span id="stat-btn">Button: Up</span>
  </div>
</header>

<div class="screen-container">
  <img id="screen" src="/frame.bmp" alt="Macintosh Screen">
</div>

<div class="controls">
  <button id="btn-turbo" class="badge-btn badge-off" onclick="toggleTurbo()">Turbo: 7.8 MHz</button>
  <button id="btn-cache" class="badge-btn badge-off" onclick="toggleCache()">Cache: OFF</button>
  <button onclick="toggleScale()">Zoom 1x / 2x</button>
  <button onclick="sendClick()">Click</button>
  <button onclick="sendDblClick()">Dbl-Click</button>
  <button id="btn-osk" onclick="toggleOSK()">⌨ On-Screen Keyboard</button>
  <span style="font-size: 0.78rem; color: #5c6370; margin-left: auto;">Host physical keyboard typing forwarded to Mac</span>
</div>

<div id="osk" class="osk-container">
  <!-- Shortcuts Bar -->
  <div class="osk-shortcuts">
    <span style="font-size: 0.78rem; color: #8e94a0; margin-right: 4px;">Shortcuts:</span>
    <button class="shortcut-btn" onclick="sendCombo(0x6B, 0x12)">⌘O Open</button>
    <button class="shortcut-btn" onclick="sendCombo(0x6B, 0x1A)">⌘W Close</button>
    <button class="shortcut-btn" onclick="sendCombo(0x6B, 0x16)">⌘S Save</button>
    <button class="shortcut-btn" onclick="sendCombo(0x6B, 0x14)">⌘Q Quit</button>
    <button class="shortcut-btn" onclick="sendCombo(0x6B, 0x04)">⌘A Select All</button>
    <button class="shortcut-btn" onclick="sendCombo(0x6B, 0x1D)">⌘Z Undo</button>
    <button class="shortcut-btn" onclick="sendCombo(0x6B, 0x06)">⌘C Copy</button>
    <button class="shortcut-btn" onclick="sendCombo(0x6B, 0x19)">⌘V Paste</button>
  </div>
  <!-- Row 1 -->
  <div class="osk-row">
    <div class="key key-mod" data-code="0x29">Esc</div>
    <div class="key" data-code="0x1E">1</div>
    <div class="key" data-code="0x1F">2</div>
    <div class="key" data-code="0x20">3</div>
    <div class="key" data-code="0x21">4</div>
    <div class="key" data-code="0x22">5</div>
    <div class="key" data-code="0x23">6</div>
    <div class="key" data-code="0x24">7</div>
    <div class="key" data-code="0x25">8</div>
    <div class="key" data-code="0x26">9</div>
    <div class="key" data-code="0x27">0</div>
    <div class="key" data-code="0x2D">-</div>
    <div class="key" data-code="0x2E">=</div>
    <div class="key key-wide key-mod" data-code="0x2A">Delete</div>
  </div>
  <!-- Row 2 -->
  <div class="osk-row">
    <div class="key key-wide key-mod" data-code="0x2B">Tab</div>
    <div class="key" data-code="0x14">Q</div>
    <div class="key" data-code="0x1A">W</div>
    <div class="key" data-code="0x08">E</div>
    <div class="key" data-code="0x15">R</div>
    <div class="key" data-code="0x17">T</div>
    <div class="key" data-code="0x1C">Y</div>
    <div class="key" data-code="0x18">U</div>
    <div class="key" data-code="0x0C">I</div>
    <div class="key" data-code="0x12">O</div>
    <div class="key" data-code="0x13">P</div>
    <div class="key" data-code="0x2F">[</div>
    <div class="key" data-code="0x30">]</div>
    <div class="key" data-code="0x31">\\</div>
  </div>
  <!-- Row 3 -->
  <div class="osk-row">
    <div class="key key-wide key-mod" data-code="0x39">Caps</div>
    <div class="key" data-code="0x04">A</div>
    <div class="key" data-code="0x16">S</div>
    <div class="key" data-code="0x07">D</div>
    <div class="key" data-code="0x09">F</div>
    <div class="key" data-code="0x0A">G</div>
    <div class="key" data-code="0x0B">H</div>
    <div class="key" data-code="0x0D">J</div>
    <div class="key" data-code="0x0E">K</div>
    <div class="key" data-code="0x0F">L</div>
    <div class="key" data-code="0x33">;</div>
    <div class="key" data-code="0x34">'</div>
    <div class="key key-wider key-mod" data-code="0x28">Return</div>
  </div>
  <!-- Row 4 -->
  <div class="osk-row">
    <div class="key key-wider key-mod" data-code="0x69">Shift</div>
    <div class="key" data-code="0x1D">Z</div>
    <div class="key" data-code="0x1B">X</div>
    <div class="key" data-code="0x06">C</div>
    <div class="key" data-code="0x19">V</div>
    <div class="key" data-code="0x05">B</div>
    <div class="key" data-code="0x11">N</div>
    <div class="key" data-code="0x10">M</div>
    <div class="key" data-code="0x36">,</div>
    <div class="key" data-code="0x37">.</div>
    <div class="key" data-code="0x38">/</div>
    <div class="key key-wider key-mod" data-code="0x6D">Shift</div>
  </div>
  <!-- Row 5 -->
  <div class="osk-row">
    <div class="key key-wide key-mod" data-code="0x6A">Option</div>
    <div class="key key-wide key-mod" data-code="0x6B">⌘ Cmd</div>
    <div class="key key-space" data-code="0x2C">Space</div>
    <div class="key key-wide key-mod" data-code="0x6E">Option</div>
    <div class="key key-mod" data-code="0x50">←</div>
    <div class="key key-mod" data-code="0x51">↓</div>
    <div class="key key-mod" data-code="0x52">↑</div>
    <div class="key key-mod" data-code="0x4F">→</div>
  </div>
</div>

<script>
const img = document.getElementById("screen");
const statFps = document.getElementById("stat-fps");
const statMs = document.getElementById("stat-ms");
const statCur = document.getElementById("stat-cur");
const statBtn = document.getElementById("stat-btn");
const btnTurbo = document.getElementById("btn-turbo");
const btnCache = document.getElementById("btn-cache");
const osk = document.getElementById("osk");

let fpsCount = 0;
let lastFpsTime = performance.now();
let lastFrameSuccess = performance.now();
let isStreaming = true;
let isScale2x = true;
let currentTurbo = false;
let currentCache = false;

// Watchdog: Drop FPS to 0.0 when not receiving data
setInterval(() => {
  const dt = performance.now() - lastFrameSuccess;
  if (dt > 1200) {
    statFps.textContent = "0.0";
    statMs.textContent = "-";
  }
}, 800);

let lastFrameId = -1;

function fetchNextFrame() {
  if (!isStreaming) return;
  const t0 = performance.now();
  fetch("/frame.bmp?id=" + lastFrameId, { cache: "no-store" })
    .then(r => {
      if (!r.ok) throw new Error("HTTP error");
      const fid = r.headers.get("X-Frame-Id");
      if (fid !== null) lastFrameId = parseInt(fid, 10);
      return r.blob();
    })
    .then(blob => {
      const dt = performance.now() - t0;
      lastFrameSuccess = performance.now();
      statMs.textContent = dt.toFixed(0);
      fpsCount++;
      const now = performance.now();
      if (now - lastFpsTime >= 1000) {
        statFps.textContent = (fpsCount * 1000 / (now - lastFpsTime)).toFixed(1);
        fpsCount = 0;
        lastFpsTime = now;
      }
      const url = URL.createObjectURL(blob);
      img.onload = () => { URL.revokeObjectURL(url); fetchNextFrame(); };
      img.src = url;
    })
    .catch(() => {
      statFps.textContent = "0.0";
      setTimeout(fetchNextFrame, 200);
    });
}

function updateStatus() {
  fetch("/status")
    .then(r => r.json())
    .then(data => {
      currentTurbo = data.turbo;
      currentCache = data.cache;
      btnTurbo.className = "badge-btn " + (currentTurbo ? "badge-on" : "badge-off");
      btnTurbo.textContent = currentTurbo ? "Turbo: 19.6 MHz" : "Turbo: 7.8 MHz";
      btnCache.className = "badge-btn " + (currentCache ? "badge-on" : "badge-off");
      btnCache.textContent = currentCache ? "Cache: ON" : "Cache: OFF";
    })
    .catch(() => {});
}
setInterval(updateStatus, 2000);
updateStatus();

function toggleTurbo() {
  const next = !currentTurbo ? 1 : 0;
  fetch("/set_turbo?val=" + next).then(() => updateStatus());
}

function toggleCache() {
  const next = !currentCache ? 1 : 0;
  fetch("/set_cache?val=" + next).then(() => updateStatus());
}

function getMacCoords(e) {
  const rect = img.getBoundingClientRect();
  const scaleX = 512 / rect.width;
  const scaleY = 342 / rect.height;
  const x = Math.max(0, Math.min(511, Math.floor((e.clientX - rect.left) * scaleX)));
  const y = Math.max(0, Math.min(341, Math.floor((e.clientY - rect.top) * scaleY)));
  return { x, y };
}

let moveThrottle = null;
img.addEventListener("mousemove", (e) => {
  const { x, y } = getMacCoords(e);
  statCur.textContent = `(${x}, ${y})`;
  if (moveThrottle) return;
  moveThrottle = setTimeout(() => {
    moveThrottle = null;
    fetch(`/mouse?x=${x}&y=${y}`);
  }, 35);
});

img.addEventListener("mousedown", (e) => {
  e.preventDefault();
  const { x, y } = getMacCoords(e);
  statBtn.textContent = "Button: DOWN";
  statBtn.style.color = "#e5c07b";
  fetch(`/mouse?x=${x}&y=${y}&btn=1`);
});

window.addEventListener("mouseup", (e) => {
  statBtn.textContent = "Button: Up";
  statBtn.style.color = "#98c379";
  fetch("/mouse?btn=0");
});

function sendClick() {
  fetch("/mouse?action=click");
}

function sendDblClick() {
  fetch("/mouse?action=dblclick");
}

function sendCombo(mod, key) {
  fetch(`/combo?mod=${mod}&key=${key}`);
}

img.addEventListener("dblclick", (e) => {
  e.preventDefault();
  const { x, y } = getMacCoords(e);
  fetch(`/mouse?x=${x}&y=${y}&action=dblclick`);
});

function toggleScale() {
  isScale2x = !isScale2x;
  if (isScale2x) {
    img.style.width = "1024px";
    img.style.height = "684px";
  } else {
    img.style.width = "512px";
    img.style.height = "342px";
  }
}

function toggleOSK() {
  const isOpen = osk.style.display === "flex";
  osk.style.display = isOpen ? "none" : "flex";
}

// On-Screen Keyboard Modifier Latching & Key Events
const MODIFIER_CODES = new Set([0x6B, 0x6A, 0x6E, 0x69, 0x6D, 0x39, 0x68, 0x6C]);
const latchedModifiers = new Set();

document.querySelectorAll(".key").forEach(keyEl => {
  const code = parseInt(keyEl.getAttribute("data-code"), 16);
  keyEl.addEventListener("click", (e) => {
    e.preventDefault();
    if (MODIFIER_CODES.has(code)) {
      // Toggle modifier latch
      if (latchedModifiers.has(code)) {
        latchedModifiers.delete(code);
        keyEl.classList.remove("latched");
        keyEl.classList.remove("active");
        fetch(`/kbd?code=${code}&down=0`);
      } else {
        latchedModifiers.add(code);
        keyEl.classList.add("latched");
        fetch(`/kbd?code=${code}&down=1`);
      }
    } else {
      // Regular key press
      keyEl.classList.add("active");
      fetch(`/kbd?code=${code}&down=1`);
      setTimeout(() => {
        keyEl.classList.remove("active");
        fetch(`/kbd?code=${code}&down=0`);
        // If modifiers are latched (e.g. Cmd for Cmd-O/Cmd-Q), release them now
        if (latchedModifiers.size > 0) {
          setTimeout(() => {
            const modsToRelease = Array.from(latchedModifiers).filter(m => m !== 0x39);
            modsToRelease.forEach(modCode => {
              latchedModifiers.delete(modCode);
              const hex = "0x" + modCode.toString(16).toUpperCase().padStart(2, "0");
              const el = document.querySelector(`.key[data-code="${hex}"]`);
              if (el) {
                el.classList.remove("latched");
                el.classList.remove("active");
              }
              fetch(`/kbd?code=${modCode}&down=0`);
            });
          }, 35);
        }
      }, 75);
    }
  });
});

// Host Physical Keyboard Forwarding
const JS_TO_HID = {
  "KeyA": 0x04, "KeyB": 0x05, "KeyC": 0x06, "KeyD": 0x07, "KeyE": 0x08, "KeyF": 0x09, "KeyG": 0x0A,
  "KeyH": 0x0B, "KeyI": 0x0C, "KeyJ": 0x0D, "KeyK": 0x0E, "KeyL": 0x0F, "KeyM": 0x10, "KeyN": 0x11,
  "KeyO": 0x12, "KeyP": 0x13, "KeyQ": 0x14, "KeyR": 0x15, "KeyS": 0x16, "KeyT": 0x17, "KeyU": 0x18,
  "KeyV": 0x19, "KeyW": 0x1A, "KeyX": 0x1B, "KeyY": 0x1C, "KeyZ": 0x1D,
  "Digit1": 0x1E, "Digit2": 0x1F, "Digit3": 0x20, "Digit4": 0x21, "Digit5": 0x22,
  "Digit6": 0x23, "Digit7": 0x24, "Digit8": 0x25, "Digit9": 0x26, "Digit0": 0x27,
  "Enter": 0x28, "Escape": 0x29, "Backspace": 0x2A, "Tab": 0x2B, "Space": 0x2C,
  "Minus": 0x2D, "Equal": 0x2E, "BracketLeft": 0x2F, "BracketRight": 0x30, "Backslash": 0x31,
  "Semicolon": 0x33, "Quote": 0x34, "Backquote": 0x35, "Comma": 0x36, "Period": 0x37, "Slash": 0x38,
  "CapsLock": 0x39, "ArrowRight": 0x4F, "ArrowLeft": 0x50, "ArrowDown": 0x51, "ArrowUp": 0x52,
  "ControlLeft": 0x68, "ShiftLeft": 0x69, "AltLeft": 0x6A, "MetaLeft": 0x6B,
  "ControlRight": 0x6C, "ShiftRight": 0x6D, "AltRight": 0x6E, "MetaRight": 0x6F
};

window.addEventListener("keydown", (e) => {
  if (e.repeat) return;
  const hid = JS_TO_HID[e.code];
  if (hid !== undefined) {
    e.preventDefault();
    fetch(`/kbd?code=${hid}&down=1`);
  }
});

window.addEventListener("keyup", (e) => {
  const hid = JS_TO_HID[e.code];
  if (hid !== undefined) {
    e.preventDefault();
    fetch(`/kbd?code=${hid}&down=0`);
  }
});

fetchNextFrame();
</script>
</body>
</html>
"""


class KVMState:
    def __init__(self, ser):
        self.ser = ser
        self.lock = threading.Lock()
        self.cv = threading.Condition(self.lock)
        self.current_bmp = BMP_HEADER + (b"\x00" * VRAM_BYTES)
        self.frame_id = 0
        self.last_status = {"turbo": False, "cache": False, "raw": "0x0000"}
        self.running = True
        self.thread = threading.Thread(target=self._stream_loop, daemon=True)
        self.thread.start()

    def _stream_loop(self):
        last_stat_time = 0
        while self.running:
            try:
                # Capture frame over UART at maximum speed
                with self.lock:
                    vram_raw = ice_fast_mem_read(self.ser, VRAM_ADDR, VRAM_BYTES, chunk_words=2736)
                if len(vram_raw) == VRAM_BYTES:
                    with self.cv:
                        self.current_bmp = BMP_HEADER + vram_raw
                        self.frame_id += 1
                        self.cv.notify_all()
            except Exception:
                time.sleep(0.05)

            # Periodically poll hardware registers every 2s
            now = time.time()
            if now - last_stat_time > 2.0:
                last_stat_time = now
                try:
                    with self.lock:
                        st = ice_get_hw_status(self.ser)
                    self.last_status = st
                except Exception:
                    pass

            # Brief sleep allows pending mouse/kbd input to acquire lock immediately
            time.sleep(0.001)

    def get_frame(self, last_id=-1, timeout=0.35):
        with self.cv:
            if self.frame_id != last_id:
                return self.frame_id, self.current_bmp
            self.cv.wait(timeout)
            return self.frame_id, self.current_bmp

    def mouse_click(self, count=1):
        """Perform reliable single or double click with Mac VBL-compliant hold and release times."""
        def _run():
            for i in range(count):
                with self.lock:
                    self.ser.write(bytes([ord("m"), 1, 0, 0]))  # Button DOWN
                time.sleep(0.06)  # Hold down for 60 ms (~4 VBL frames)
                with self.lock:
                    self.ser.write(bytes([ord("m"), 0, 0, 0]))  # Button UP
                if i < count - 1:
                    time.sleep(0.08)  # Inter-click gap: 80 ms (~5 VBL frames)
        threading.Thread(target=_run, daemon=True).start()

    def send_combo(self, mod_code, key_code):
        """Execute a modifier + key combination (e.g. Command-O, Command-Q) with proper hold timing."""
        def _run():
            with self.lock:
                ice_kbd(self.ser, mod_code & 0x7F)  # Mod DOWN
            time.sleep(0.04)
            with self.lock:
                ice_kbd(self.ser, key_code & 0x7F)  # Key DOWN
            time.sleep(0.08)
            with self.lock:
                ice_kbd(self.ser, (key_code & 0x7F) | 0x80)  # Key UP
            time.sleep(0.03)
            with self.lock:
                ice_kbd(self.ser, (mod_code & 0x7F) | 0x80)  # Mod UP
        threading.Thread(target=_run, daemon=True).start()


kvm = None


class KVMHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Silence verbose per-request HTTP logs
        return

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/" or url.path == "/index.html":
            body = HTML_PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif url.path == "/frame.bmp":
            qs = parse_qs(url.query)
            try:
                last_id = int(qs.get("id", [-1])[0])
            except (ValueError, TypeError):
                last_id = -1
            fid, body = kvm.get_frame(last_id=last_id, timeout=0.35)

            self.send_response(200)
            self.send_header("Content-Type", "image/bmp")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Frame-Id", str(fid))
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
            self.end_headers()
            self.wfile.write(body)
        elif url.path == "/mouse":
            qs = parse_qs(url.query)
            x = int(qs["x"][0]) if "x" in qs else None
            y = int(qs["y"][0]) if "y" in qs else None
            click = (qs.get("click", ["0"])[0] == "1")
            action = qs.get("action", [None])[0]
            btn_val = None
            if "btn" in qs:
                btn_val = 1 if qs["btn"][0] == "1" else 0

            if action == "click":
                kvm.mouse_click(1)
            elif action == "dblclick":
                kvm.mouse_click(2)
            else:
                with kvm.lock:
                    try:
                        if x is not None and y is not None:
                            fast_moveto(kvm.ser, x, y, click=click)
                        if btn_val is not None:
                            kvm.ser.write(bytes([ord("m"), btn_val, 0, 0]))
                    except Exception:
                        pass

            self.send_response(204)
            self.end_headers()
        elif url.path == "/combo":
            qs = parse_qs(url.query)
            try:
                mod_code = int(qs.get("mod", ["0x6B"])[0], 0)
                key_code = int(qs.get("key", ["0"])[0], 0)
                kvm.send_combo(mod_code, key_code)
            except Exception:
                pass
            self.send_response(204)
            self.end_headers()
        elif url.path == "/kbd":
            qs = parse_qs(url.query)
            try:
                code_raw = qs.get("code", [None])[0]
                down = (qs.get("down", ["1"])[0] == "1")
                if code_raw is not None:
                    code = int(code_raw, 0) & 0x7F
                    scancode = code if down else (code | 0x80)
                    with kvm.lock:
                        ice_kbd(kvm.ser, scancode)
            except Exception:
                pass

            self.send_response(204)
            self.end_headers()
        elif url.path == "/status":
            body = json.dumps(kvm.last_status).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif url.path == "/set_turbo":
            qs = parse_qs(url.query)
            val = (qs.get("val", ["1"])[0] == "1")
            with kvm.lock:
                try:
                    st = ice_set_turbo(kvm.ser, val)
                    kvm.last_status = st
                except Exception:
                    st = {"turbo": val, "cache": False}
            body = json.dumps(st).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif url.path == "/set_cache":
            qs = parse_qs(url.query)
            val = (qs.get("val", ["1"])[0] == "1")
            with kvm.lock:
                try:
                    st = ice_set_cache(kvm.ser, val)
                    kvm.last_status = st
                except Exception:
                    st = {"turbo": False, "cache": val}
            body = json.dumps(st).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()


def main():
    global kvm
    parser = argparse.ArgumentParser(description="NanoMac KVM Server")
    parser.add_argument("--port", type=int, default=8765, help="HTTP server port (default: 8765)")
    parser.add_argument("--serial", help="Serial port (default: auto-detect)")
    parser.add_argument("--baud", type=int, default=2000000, help="Baud rate (default: 2000000)")
    args = parser.parse_args()

    ser = get_connection(args.serial, args.baud)
    kvm = KVMState(ser)

    server = ThreadingHTTPServer(("0.0.0.0", args.port), KVMHandler)
    print("=" * 70)
    print("  NanoMac Remote KVM Server (High Performance)")
    print(f"  URL:         http://localhost:{args.port}")
    print(f"  Serial:      {getattr(ser, 'port', args.serial)} @ {args.baud} baud")
    print("  Compatible:  VS Code Simple Browser, Safari, Chrome, Firefox")
    print("=" * 70)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down KVM server...")
        kvm.running = False
        server.server_close()


if __name__ == "__main__":
    main()
