#!/bin/bash
set -e
cd "$(dirname "$0")"

rm -rf obj_dir_storm
echo "Compiling via_irq_storm testbench with Verilator..."
verilator --cc --exe -Wall -Wno-fatal \
    -Wno-BLKANDNBLK -Wno-MULTIDRIVEN -Wno-SYNCASYNCNET -Wno-COMBDLY \
    -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE -Wno-CASEOVERLAP -Wno-CASEX \
    -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-PROCASSINIT -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC -Wno-BLKSEQ -Wno-ALWCOMBORDER -Wno-UNDRIVEN \
    -Wno-PINCONNECTEMPTY -Wno-PINMISSING -Wno-DECLFILENAME -Wno-VARHIDDEN \
    -Wno-DEFOVERRIDE \
    --no-timing --no-assert \
    -DUSE_E_CLKEN \
    --top-module tb_via_irq_storm \
    --Mdir obj_dir_storm \
    -I../src \
    -I../src/macplus \
    -I./fx68k \
    tb_via_irq_storm.sv \
    ../src/macplus/via6522.v \
    ./fx68k/fx68k.sv \
    ./fx68k/fx68kAlu.sv \
    ./fx68k/uaddrPla.sv \
    tb_via_irq_storm.cpp

VERILATOR_INC="/Users/Jeff/workspace/oss-cad-suite/share/verilator/include"

echo "Compiling with clang++..."
clang++ -O2 -std=c++14 \
    -Iobj_dir_storm -I"$VERILATOR_INC" -I"$VERILATOR_INC/vltstd" \
    "$VERILATOR_INC/verilated.cpp" \
    "$VERILATOR_INC/verilated_threads.cpp" \
    obj_dir_storm/*.cpp \
    tb_via_irq_storm.cpp \
    -o obj_dir_storm/Vtb_via_irq_storm

echo "Running simulation..."
./obj_dir_storm/Vtb_via_irq_storm
