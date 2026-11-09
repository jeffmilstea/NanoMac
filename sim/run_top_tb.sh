#!/bin/bash
set -e

# Gather all source files from the TCL build script (excluding the .cst/.sdc files and the Gowin primitives we mocked)
SRC_FILES=$(grep '^add_file' ../src/build.tcl | grep -v '.cst' | grep -v '.sdc' | grep -v 'gowin_clkdiv.v' | grep -v 'pll_80m.v' | grep -v '.mem' | awk '{print "../src/" $2}' | sed 's|\.\./src/fx68k/|\./fx68k/|g')

if [ ! -d "./fx68k" ]; then
    mkdir -p ./fx68k
    cp -a ../src/fx68k/*.sv ./fx68k/
    patch -p1 < fx68k_sim.patch || true
fi
cp -f ../src/fx68k/*.mem . 2>/dev/null || true
cp -f ../src/companion/macplus_xml.hex . 2>/dev/null || true

if [ -f "plusrom.bin" ]; then
    echo "Generating plusrom.hex from plusrom.bin for INT_ROM simulation..."
    xxd -c2 -p plusrom.bin > plusrom.hex
fi

rm -rf obj_dir

echo "Running Verilator..."
verilator --cc --exe -Wall -Wno-fatal -Wno-ENUMVALUE \
    -Wno-BLKANDNBLK -Wno-MULTIDRIVEN -Wno-SYNCASYNCNET -Wno-COMBDLY \
    -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE -Wno-CASEOVERLAP -Wno-CASEX \
    -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-PROCASSINIT -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC -Wno-BLKSEQ -Wno-ALWCOMBORDER -Wno-UNDRIVEN \
    --no-timing --no-assert \
    -DINT_ROM \
    --top-module top \
    -I../src \
    -I../src/macplus \
    -I./fx68k \
    -I../src/companion \
    -I../src/misc \
    -I../src/hdmi \
    -I../src/tang/nano20k \
    gowin_mocks.v \
    $SRC_FILES \
    top_tb.cpp

echo "Compiling C++ simulation model..."
VERILATOR_INC=""
if command -v verilator >/dev/null 2>&1; then
    VERILATOR_ROOT_DIR=$(verilator -getenv VERILATOR_ROOT 2>/dev/null || true)
    if [ -n "$VERILATOR_ROOT_DIR" ] && [ -d "$VERILATOR_ROOT_DIR/include" ]; then
        VERILATOR_INC="$VERILATOR_ROOT_DIR/include"
    else
        VERILATOR_INC="$(dirname $(dirname $(which verilator)))/share/verilator/include"
    fi
fi

if [ -n "$VERILATOR_INC" ] && [ -d "$VERILATOR_INC" ]; then
    clang++ -O2 -std=gnu++20 \
        -Iobj_dir -I"$VERILATOR_INC" -I"$VERILATOR_INC/vltstd" \
        "$VERILATOR_INC/verilated.cpp" \
        "$VERILATOR_INC/verilated_threads.cpp" \
        obj_dir/*.cpp \
        top_tb.cpp \
        -o obj_dir/Vtop
else
    # Fallback to make if include path cannot be located
    make -C obj_dir -f Vtop.mk
fi

echo "Running Simulation..."
./obj_dir/Vtop

