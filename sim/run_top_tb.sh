#!/bin/bash
set -e

# Gather all source files from the TCL build script (excluding the .cst/.sdc files and the Gowin primitives we mocked)
SRC_FILES=$(grep '^add_file' ../src/build.tcl | grep -v '.cst' | grep -v '.sdc' | grep -v 'gowin_clkdiv.v' | grep -v 'pll_80m.v' | grep -v '.mem' | awk '{print "../src/" $2}')

# We also need to exclude the SPI flash and DPB (block ram) primitives if they contain Gowin primitives, 
# or we'll need to mock them too. For now, we'll try to compile them.

if [ -f "plusrom.bin" ]; then
    echo "Generating plusrom.hex from plusrom.bin for INT_ROM simulation..."
    xxd -c2 -p plusrom.bin > plusrom.hex
fi

echo "Running Verilator..."
verilator --cc --exe --build -j 0 -Wall -Wno-fatal -Wno-BLKANDNBLK -Wno-MULTIDRIVEN -Wno-SYNCASYNCNET -Wno-COMBDLY -Wno-UNOPTFLAT --no-timing \
    -DINT_ROM \
    --top-module top \
    -I../src \
    -I../src/macplus \
    -I../src/fx68k \
    -I../src/companion \
    -I../src/misc \
    -I../src/hdmi \
    -I../src/tang/nano20k \
    gowin_mocks.v \
    $SRC_FILES \
    top_tb.cpp

echo "Running Simulation..."
./obj_dir/Vtop
