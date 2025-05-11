#!/bin/bash
# Capture start time
start_time=$(date +%s)

# Define input and output file 
INPUT_FILE="video__2025-04-24__15-12-25__CAMB.h265"  # Use the desired input video file
#ORIGINAL_INPUT_FILE="$INPUT_FILE"
INPUT_DIR="sample_data/Horizontal_Pattern"
INPUT_PATH="$INPUT_DIR/$INPUT_FILE"
RESOLUTION="1920x1200"

# Define a directory to store JSON files
JSON_OUTPUT_DIR="output_dir/json_output_dir"
mkdir -p "$JSON_OUTPUT_DIR"  # Ensure JSON output directory exists

# If the input is a .h265 file, check for existing .mp4 conversion
if [[ "$INPUT_FILE" == *.h265 ]]; then
    CONVERTED_FILE="${INPUT_FILE%.h265}.mp4"
    CONVERTED_PATH="$INPUT_DIR/$CONVERTED_FILE"

    if [[ -f "$CONVERTED_PATH" ]]; then
        echo "MP4 version already exists: $CONVERTED_FILE"
    else
        echo "Converting $INPUT_FILE to $CONVERTED_FILE..."
        ffmpeg -y -i "$INPUT_PATH" -c:v libx265 "$CONVERTED_PATH"
    fi

    # Update input path to the converted file, but we will still use ORIGINAL_INPUT_FILE for JSON
    INPUT_FILE="$CONVERTED_FILE"
    INPUT_PATH="$CONVERTED_PATH"
fi

# **Here**: Use the original filename for the JSON output (without .h265 or .mp4)
JSON_FILE="sitiCR${INPUT_FILE}.json"  # Remove extension from the filename
JSON_PATH="$JSON_OUTPUT_DIR/$JSON_FILE"
echo "Looking for JSON path: $JSON_PATH"  # Print the full path of the JSON file

if [[ ! -f "$JSON_PATH" ]]; then
    echo "JSON file not found in $JSON_PATH. Running siti-tools..."
    
    # Run the second script to generate the JSON file
    ./export_SITI_frame_by_frame.sh "$INPUT_PATH" "$JSON_OUTPUT_DIR" "$RESOLUTION"  # Pass the input file and output directory to the second script
    
    # Pause and wait for user to press Enter
    echo "Press Enter to continue..."
    read
else
    echo "JSON file found in $JSON_OUTPUT_DIR for $INPUT_FILE. Skipping using siti-tools."
fi


OUTPUT_BASE_DIR="output_dir"
mkdir -p "$OUTPUT_BASE_DIR" # Ensure the output directory exists

# Generate timestamp and subfolder
TIMESTAMP=$(date +"%Y-%m-%d__%H-%M-%S")
VIDEO_BASENAME="${INPUT_FILE%.*}"
OUTPUT_SUBDIR="${VIDEO_BASENAME}__${TIMESTAMP}"
OUTPUT_PATH="${OUTPUT_BASE_DIR}/${OUTPUT_SUBDIR}"
mkdir -p "$OUTPUT_PATH/picture_output"

# Output text file for frame sizes
OUTPUT_FILE_SIZE="frame_sizes.txt"
OUTPUT_PATH_SIZE="$OUTPUT_PATH/$OUTPUT_FILE_SIZE"
echo "Frame Number, File Size (bytes), File Size (kB)" > "$OUTPUT_PATH_SIZE"  # Header for the output file

# Clear old pictures before running
OUTPUT_PATH_PICS="$OUTPUT_PATH/picture_output"
find "$OUTPUT_PATH_PICS" -mindepth 1 -delete

# Run Python script to get frame indices
frame_indices=$(python3 extract_frames.py from_bash "$INPUT_FILE")
echo -e "Frame indices:\n$frame_indices"

# Extract all frames
ffmpeg -i "$INPUT_PATH" -qscale:v 2 "$OUTPUT_PATH_PICS/frame%04d.jpg"

# Convert frame_indices into a bash associative array (whitelist)
declare -A keep_frames
for FRAME_NO in $frame_indices; do
    FRAME_NO_Padded=$(printf "%04d" $FRAME_NO)
    keep_frames["frame${FRAME_NO_Padded}.jpg"]=1
done

# Iterate over all extracted frames and delete those not in keep list
for file in "$OUTPUT_PATH_PICS"/*.jpg; do
    filename=$(basename "$file")
    if [[ -z "${keep_frames[$filename]}" ]]; then
        rm "$file"
    fi
done

# Loop to extract frames 0 to 4
for FRAME_NO in $frame_indices; do
    FRAME_NO_Padded=$(printf "%04d" $FRAME_NO)
    OUTPUT_FILE="frame${FRAME_NO_Padded}.jpg"  # Output image file name
    OUTPUT_FILE_PICS="${OUTPUT_PATH_PICS}/${OUTPUT_FILE}"

    # Check if the extraction was successful
    if [ $? -eq 0 ]; then
        # Get the file size of the newly generated image in bytes
        filesize=$(stat -c%s "$OUTPUT_FILE_PICS")
        
        # Convert file size to kilobytes (KB)
        filesize_kb=$(echo "scale=2; $filesize / 1024" | bc)
        
        echo "The size of the extracted image '$OUTPUT_FILE_PICS' is: $filesize bytes ($filesize_kb KB)"
        
        # Print frame number, file size in bytes, and file size in KB to the text file
        echo "$FRAME_NO, $filesize, $filesize_kb" >> "$OUTPUT_PATH_SIZE"
    else
        echo "Failed to extract frame $FRAME_NO."
    fi
done

ffmpeg -y -pattern_type glob -i "$OUTPUT_PATH_PICS/*.jpg" -c:v libx265 -r 24 $OUTPUT_PATH/recreated_video_"$INPUT_FILE"

# Capture the end time
end_time=$(date +%s)

# Calculate and print the total execution time
total_time=$((end_time - start_time))
echo "Total time taken: $total_time seconds"
