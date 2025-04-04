#!/bin/bash

OUTPUT_DIR="output_dir"
mkdir -p "$OUTPUT_DIR"  # Ensure output directory exists

# Declare an associative array with filenames as keys and resolutions as values
declare -A INPUT_FILES=(
    ["chair_test.h265"]="1920x1200"
    #["riverbed540p.yuv"]="960x540"
    #["rollercoaster.yuv"]="1024x540"
    #["sintel1024p.yuv"]="1024x436"
)

# Define the input directory
INPUT_DIR="sample_data"

# Loop through each file and process it with ffmpeg
for INPUT_FILE in "${!INPUT_FILES[@]}"; do
    INPUT_PATH="$INPUT_DIR/$INPUT_FILE"
    OUTPUT_FILE="${OUTPUT_DIR}/sitiCR${INPUT_FILE}.txt"
    RESOLUTION="${INPUT_FILES[$INPUT_FILE]}"

    echo "Processing $INPUT_FILE with resolution $RESOLUTION..."
    ffmpeg -s 1920x1200 -pix_fmt yuv420p -i "$INPUT_PATH" -vf siti=print_summary=1 -f null - 2> output.txt


    #ffmpeg -s "$RESOLUTION" -i "$INPUT_PATH" -vf siti=print_summary=1 -f null - 2> "$OUTPUT_FILE"
done

echo "All videos processed."
