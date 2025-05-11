#!/bin/bash
# Capture start time
start_time=$(date +%s)

# Get input file and output directory from arguments
INPUT_PATH="$1"
JSON_OUTPUT_DIR="$2"
RESOLUTION="$3"

# Correct JSON file naming
ORIGINAL_INPUT_FILE=$(basename "$INPUT_PATH")
JSON_FILE="sitiCR${ORIGINAL_INPUT_FILE}.json"
OUTPUT_FILE="${JSON_OUTPUT_DIR}/${JSON_FILE}"

# Define number of frames
NUMBER_OF_FRAMES="0" # if < 2, all frames will be used

# Activate the virtual environment
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
