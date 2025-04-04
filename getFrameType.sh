#!/bin/bash

# Define input file and resolution

INPUT_FILE="still_walking_still.mp4"
INPUT_DIR="sample_data"
INPUT_PATH="$INPUT_DIR/$INPUT_FILE"

OUTPUT_FILE="output.txt"
OUTPUT_DIR="output_dir"
mkdir -p "$OUTPUT_DIR" # Ensure dir exists
OUTPUT_PATH="${OUTPUT_DIR}/$OUTPUT_FILE"


ffmpeg -i $INPUT_PATH -vf "select='eq(pict_type,I)+eq(pict_type,P)+eq(pict_type,B)',showinfo" -f null - 2> >(grep "type:" > $OUTPUT_PATH)

