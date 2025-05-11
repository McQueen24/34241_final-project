#!/bin/bash
# Capture start time
start_time=$(date +%s)

# Get input file and output directory from arguments
INPUT_PATH="$1"
JSON_OUTPUT_DIR="$2"
RESOLUTION="$3"

OUTPUT_FILE="${JSON_OUTPUT_DIR}/sitiCR$(basename "$INPUT_PATH").json"

# Declare an associative array with filenames as keys and resolutions as values
#declare -A INPUT_FILES=(
#    ["other_sample_data/chair_test.h265"]="1920x1200"
    #["Horizontal_Pattern/video__2025-04-24__15-12-25__CAMB.h265"]="1920x1200"
    #["rollercoaster.yuv"]="1024x540"
    #["sintel1024p.yuv"]="1024x436"
#)

NUMBER_OF_FRAMES="0" # if < 2, all frames will be used

# Define the input directory
#INPUT_DIR="sample_data"

source ~/siti-venv-py311/bin/activate

# Process the video file and generate JSON output
echo "Processing $INPUT_PATH with resolution $RESOLUTION..."
siti-tools -r full -n "$NUMBER_OF_FRAMES" "$INPUT_PATH" > "$OUTPUT_FILE"

echo "Generated JSON file: $OUTPUT_FILE"

# Capture the end time
end_time=$(date +%s)

# Calculate and print the total execution time
total_time=$((end_time - start_time))
echo "Total time taken: $total_time seconds"
