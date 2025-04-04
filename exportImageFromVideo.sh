#!/bin/bash
# Capture start time
start_time=$(date +%s)

# Define input and output file 
INPUT_FILE="still_walking_still.mp4"  # Use the desired input video file
INPUT_DIR="sample_data"
INPUT_PATH="$INPUT_DIR/$INPUT_FILE"

OUTPUT_PATH="output_dir"
mkdir -p "$OUTPUT_PATH" # Ensure the output directory exists

# Output text file for frame sizes
OUTPUT_FILE_SIZE="frame_sizes.txt"
OUTPUT_PATH_SIZE="$OUTPUT_PATH/$OUTPUT_FILE_SIZE"
echo "Frame Number, File Size (bytes), File Size (kB)" > "$OUTPUT_PATH_SIZE"  # Header for the output file

# Clear old pictures before running
OUTPUT_PATH_PICS="$OUTPUT_PATH/picture_output"
find "$OUTPUT_PATH_PICS" -mindepth 1 -delete

# Run Python script to get frame indices
frame_indices=$(python3 extract_frames.py from_bash)
echo -e "Frame indices:\n$frame_indices"

# Loop to extract frames 0 to 4
for FRAME_NO in $frame_indices; do
    FRAME_NO_Padded=$(printf "%03d" $FRAME_NO)
    OUTPUT_FILE="frame${FRAME_NO_Padded}.jpg"  # Output image file name
    OUTPUT_FILE_PICS="${OUTPUT_PATH_PICS}/${OUTPUT_FILE}"

    # Extract the specified frame
    ffmpeg -i "$INPUT_PATH" -vf "select=eq(n\,${FRAME_NO})" -frames:v 1 -q:v 31 -loglevel quiet -y "$OUTPUT_FILE_PICS"    

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

ffmpeg -y -pattern_type glob -i "$OUTPUT_PATH_PICS/*.jpg" -c:v libx265 -r 24 $OUTPUT_PATH/recreated_video.mp4

# Capture the end time
end_time=$(date +%s)

# Calculate and print the total execution time
total_time=$((end_time - start_time))
echo "Total time taken: $total_time seconds"