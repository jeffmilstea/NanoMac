#!/bin/bash
# scripts/capture_frame.sh
# Captures a single frame from the USB3 Video HDMI digitizer using ffmpeg.

OUTPUT_FILE="$1"

if [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: $0 <output_file.png>"
    exit 1
fi

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Capture 1 frame at 60fps from "USB3 Video" device using avfoundation on macOS
ffmpeg -y -loglevel error -f avfoundation -pixel_format uyvy422 -framerate 60 -i "USB3 Video" -vframes 1 -update 1 "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "Frame successfully captured to $OUTPUT_FILE"
else
    echo "Error capturing frame via ffmpeg"
    exit 1
fi
