#!/bin/bash

VIDEO_PATH="$1"
TI_THRESHOLD=20
PYTHON_SCRIPT="compute_ti.py"

if [[ -z "$VIDEO_PATH" || ! -f "$VIDEO_PATH" ]]; then
    echo "Usage: $0 <video_file>"
    exit 1
fi

# Output log file
OUTPUT_LOG="ti_scan_results.txt"
echo "TI Scan Results for $VIDEO_PATH" > "$OUTPUT_LOG"
echo "Threshold: $TI_THRESHOLD" >> "$OUTPUT_LOG"
echo "------------------------------" >> "$OUTPUT_LOG"

# Start from frame 0
CURRENT_KEY_FRAME=0
TOTAL_FRAMES=$(ffprobe -v error -select_streams v:0 -count_frames \
    -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 "$VIDEO_PATH")

if [[ -z "$TOTAL_FRAMES" ]]; then
    echo "Could not get total frame count. Is this a raw .h265? Try re-wrapping it in .mp4"
    exit 1
fi

# Total frames to process
TOTAL_FRAMES=$((TOTAL_FRAMES - 1))  # Exclude frame 0 since it's the starting point
echo "Total frames to process: $TOTAL_FRAMES"

# Loop through frames 1 to TOTAL_FRAMES
for ((i = 1; i <= TOTAL_FRAMES; i++)); do
    TI_VALUE=$(python3 "$PYTHON_SCRIPT" "$VIDEO_PATH" "$CURRENT_KEY_FRAME" "$i" 2>/dev/null)

    # If Python script failed, skip
    if [[ $? -ne 0 || -z "$TI_VALUE" ]]; then
        echo "Skipping frame $i due to error"
        continue
    fi

    TI_NUM=$(printf "%.4f" "$TI_VALUE")

    # Display progress
    echo -n "Checking frame $i/$TOTAL_FRAMES (TI: $TI_NUM) ... "

    if (( $(echo "$TI_NUM > $TI_THRESHOLD" | bc -l) )); then
        echo "TI threshold exceeded at frame $i (TI=$TI_NUM)"
        echo "TI threshold exceeded at frame $i (TI=$TI_NUM)" >> "$OUTPUT_LOG"
        CURRENT_KEY_FRAME=$i
    else
        echo "Passed (TI=$TI_NUM)"
    fi
done

echo "Done. Results saved to $OUTPUT_LOG"
