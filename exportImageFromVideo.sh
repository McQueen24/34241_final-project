#!/bin/bash

# Define 

# Define input and output file 
INPUT_FILE="still_walking_still.mp4"  # Use the desired input video file
INPUT_DIR="sample_data"
INPUT_PATH="$INPUT_DIR/$INPUT_FILE"

OUTPUT_DIR="output_dir"
mkdir -p "$OUTPUT_DIR" # Ensure the output directory exists

# Output text file for frame sizes
OUTPUT_SIZE_FILE="frame_sizes.txt"
OUTPUT_SIZE_PATH="$OUTPUT_DIR/$OUTPUT_SIZE_FILE"
echo "Frame Number, File Size (bytes), File Size (kB)" > "$OUTPUT_SIZE_PATH"  # Header for the output file

# Run Python script to get frame indices
frame_indices=$(python3 extract_frames.py)
echo -e "Frame indices:\n$frame_indices"

# Loop to extract frames 0 to 4
for FRAME_NO in $frame_indices; do
    OUTPUT_FILE="frame${FRAME_NO}.jpg"  # Output image file name
    OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_FILE}"

    # Extract the specified frame
    ffmpeg -i "$INPUT_PATH" -vf "select=eq(n\,${FRAME_NO})" -frames:v 1 -q:v 31 -loglevel quiet -y "$OUTPUT_PATH"    

    # Check if the extraction was successful
    if [ $? -eq 0 ]; then
        # Get the file size of the newly generated image in bytes
        filesize=$(stat -c%s "$OUTPUT_PATH")
        
        # Convert file size to kilobytes (KB)
        filesize_kb=$(echo "scale=2; $filesize / 1024" | bc)
        
        echo "The size of the extracted image '$OUTPUT_PATH' is: $filesize bytes ($filesize_kb KB)"
        
        # Print frame number, file size in bytes, and file size in KB to the text file
        echo "$FRAME_NO, $filesize, $filesize_kb" >> "$OUTPUT_SIZE_PATH"
    else
        echo "Failed to extract frame $FRAME_NO."
    fi
done
