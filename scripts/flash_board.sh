#!/bin/bash
# scripts/flash_board.sh

BITSTREAM="${1:-src/impl/pnr/nanomac.fs}"
MODE="${2:--f}" # -f for SPI flash, -m for instant SRAM

if [ ! -f "$BITSTREAM" ]; then
    echo "ERROR: Bitstream file not found: $BITSTREAM"
    exit 1
fi

echo "Flashing bitstream $BITSTREAM to Tang Nano 20K (Mode: $MODE with -r reset)..."
OUTPUT=$(openFPGALoader -b tangnano20k $MODE "$BITSTREAM" -r --verbose-level 2 --freq 2500000 2>&1)
EXIT_CODE=$?

echo "$OUTPUT"

if [ $EXIT_CODE -eq 0 ] && echo "$OUTPUT" | grep -q "100.00%"; then
   echo "SUCCESS: FPGA program operation confirmed 100% complete!"
   exit 0
fi

echo "WARNING: Initial programming attempt did not confirm 100% completion. Retrying in 2 seconds..."
sleep 2

OUTPUT_RETRY=$(openFPGALoader -b tangnano20k $MODE "$BITSTREAM" -r --verbose-level 2 --freq 2500000 2>&1)
EXIT_CODE_RETRY=$?

echo "$OUTPUT_RETRY"

if [ $EXIT_CODE_RETRY -eq 0 ] && echo "$OUTPUT_RETRY" | grep -q "100.00%"; then
   echo "SUCCESS: FPGA program retry confirmed 100% complete!"
   exit 0
else
   echo "ERROR: FPGA programming failed!"
   exit 1
fi