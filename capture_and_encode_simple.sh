#!/bin/bash

INPUT_DEVICE="/dev/video0"
OUTPUT_DIR="video_captures_simple"

mkdir -p $OUTPUT_DIR  # Ensure output directory exists

# Default settings with timestamp
ffmpeg -f video4linux2 -i $INPUT_DEVICE -t 3 -c:v libx264 \
-vf "drawtext=text='Default Capture':fontcolor=white:fontsize=24:x=50:y=50, \
drawtext=text='%{localtime}':fontcolor=yellow:fontsize=18:x=50:y=80" \
$OUTPUT_DIR/output.mp4 -y

# Default settings with timestamp and ms
ffmpeg -f video4linux2 -i $INPUT_DEVICE -t 3 -c:v libx264 \
-vf "drawtext=text='Default Capture':fontcolor=white:fontsize=24:x=50:y=50, \
drawtext=text='%{localtime\:%X.%3N}':fontcolor=yellow:fontsize=18:x=50:y=80" \
$OUTPUT_DIR/output_w_ms.mp4 -y
