#!/bin/bash

OUTPUT_DIR="output_dir2"
mkdir -p "$OUTPUT_DIR"  # Ensure output directory exists

# Define the input file and resolution
INPUT_FILE="rollercoaster.yuv"
RESOLUTION="1024x540"
INPUT_DIR="../Sequences"
INPUT_PATH="$INPUT_DIR/$INPUT_FILE"

# Define QP values and presets to loop through
QP_VALUES=(24 30 36 38 42)
PRESETS=("superfast" "medium")

# Loop through presets and QP values
for PRESET in "${PRESETS[@]}"; do
    for QP in "${QP_VALUES[@]}"; do
        ENCODED_FILE="${OUTPUT_DIR}/rollercoaster_${PRESET}_qp${QP}.mp4"
        VMAF_OUTPUT="${OUTPUT_DIR}/VMAF_rollercoaster_${PRESET}_qp${QP}.txt"

        echo "Processing $INPUT_FILE with preset=$PRESET and QP=$QP..."
        
        # Encode video
        ffmpeg -s "$RESOLUTION" -i "$INPUT_PATH" -c:v libx265 -preset "$PRESET" -x265-params "qp=${QP}:psnr=1" -f mp4 "$ENCODED_FILE" -y
        
        # Calculate VMAF
        echo "Calculating VMAF for $ENCODED_FILE..."
        ffmpeg -s "$RESOLUTION" -i "$INPUT_PATH" -i "$ENCODED_FILE" -lavfi "[0:v]settb=AVTB,setpts=PTS-STARTPTS[main];[1:v]settb=AVTB,setpts=PTS-STARTPTS[ref];[main][ref]libvmaf" -f null - 2> "$VMAF_OUTPUT" -y
    done
done

echo "All videos processed and VMAF metrics calculated."
