#!/bin/bash
EXT=
if [ "$#" -eq 1 ]; then
    EXT=_$1
fi

# Clean up lingering Gowin EDA processes to prevent local license server lock errors ("Server not responding")
killall -9 gw_sh.bin gw_sh 2>/dev/null || true
sleep 1

export PATH="/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/bin:$PATH"

if command -v grc >/dev/null 2>&1; then
    grc --config=gw_sh.grc gw_sh ./build${EXT}.tcl
else
    gw_sh ./build${EXT}.tcl
fi
