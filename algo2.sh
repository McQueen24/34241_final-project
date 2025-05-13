#!/bin/bash
# This algorithm takes two mp4 inputs and uses one array of 
# frame indices to determine frames to keep
# Capture start time
start_time=$(date +%s)

# Define input and output file 
INPUT_FILE_L="video__2025-04-24__15-14-57__CAMB.mp4"  # LEFT channel
INPUT_FILE_R="video__2025-04-24__15-14-57__CAMC.mp4"  # RIGHT channel
#ORIGINAL_INPUT_FILE="$INPUT_FILE"
INPUT_DIR="sample_data/Lawnmower_Pattern"
INPUT_PATH_L="$INPUT_DIR/$INPUT_FILE_L"
INPUT_PATH_R="$INPUT_DIR/$INPUT_FILE_R"
RESOLUTION="1920x1200"

# Define a directory for JSON files
JSON_OUTPUT_DIR="output_dir/json_output_dir"
mkdir -p "$JSON_OUTPUT_DIR"  # Ensure JSON output directory exists

# Use the original filename for the JSON output
JSON_FILE_L="sitiCR${INPUT_FILE_L}.json"  # Remove extension from the filename
JSON_FILE_R="sitiCR${INPUT_FILE_R}.json"  # Remove extension from the filename
JSON_PATH_L="$JSON_OUTPUT_DIR/$JSON_FILE_L"
JSON_PATH_R="$JSON_OUTPUT_DIR/$JSON_FILE_R"

if [[ ! -f "$JSON_PATH_L" ]]; then
    echo "JSON file not found in $JSON_PATH_L. Running siti-tools..."
    
    echo "Press Enter to continue..."
    read
    # Run the second script to generate the JSON file
    ./export_SITI_frame_by_frame.sh "$INPUT_PATH_L" "$JSON_OUTPUT_DIR" "$RESOLUTION"  # Pass the input file and output directory to the second script
else
    echo "JSON file found in $JSON_OUTPUT_DIR for $INPUT_FILE_L. Skipping using siti-tools."
fi

if [[ ! -f "$JSON_PATH_R" ]]; then
    echo "JSON file not found in $JSON_PATH_R. Running siti-tools..."
    
    echo "Press Enter to continue..."
    read
    # Run the second script to generate the JSON file
    ./export_SITI_frame_by_frame.sh "$INPUT_PATH_R" "$JSON_OUTPUT_DIR" "$RESOLUTION"  # Pass the input file and output directory to the second script
else
    echo "JSON file found in $JSON_OUTPUT_DIR for $INPUT_FILE_R. Skipping using siti-tools."
fi



OUTPUT_BASE_DIR="output_dir"
mkdir -p "$OUTPUT_BASE_DIR" # Ensure the output directory exists

# Generate timestamp and subfolder
TIMESTAMP=$(date +"%Y-%m-%d__%H-%M-%S")
VIDEO_BASENAME_L="${INPUT_FILE_L%.*}"
OUTPUT_SUBDIR="algo2_${TIMESTAMP}__${VIDEO_BASENAME_L}"
OUTPUT_PATH="${OUTPUT_BASE_DIR}/${OUTPUT_SUBDIR}"
mkdir -p "$OUTPUT_PATH/picture_output_L"
mkdir -p "$OUTPUT_PATH/picture_output_R"

# Output text file for frame sizes
OUTPUT_FILE_SIZE="frame_sizes.txt"
OUTPUT_PATH_SIZE="$OUTPUT_PATH/$OUTPUT_FILE_SIZE"
echo "Frame Number, File Size (bytes), File Size (kB)" > "$OUTPUT_PATH_SIZE"  # Header for the output file

# Output path for pictures
OUTPUT_PATH_PICS_L="$OUTPUT_PATH/picture_output_L"
OUTPUT_PATH_PICS_R="$OUTPUT_PATH/picture_output_R"

# Run Python script to get frame indices
frame_indices_L=$(python3 extract_frames.py from_bash "$INPUT_FILE_L")
frame_indices_R=$(python3 extract_frames.py from_bash "$INPUT_FILE_R")

echo -e "Frame indices(L):\n$frame_indices_L"
echo -e "Frame indices(R):\n$frame_indices_R"


# Extract all frames
ffmpeg -i "$INPUT_PATH_L" -qscale:v 2 "$OUTPUT_PATH_PICS_L/frame%04d.jpg"
ffmpeg -i "$INPUT_PATH_R" -qscale:v 2 "$OUTPUT_PATH_PICS_R/frame%04d.jpg"

# Convert frame_indices into a bash associative array (whitelist)
declare -A keep_frames_combined

# Add frames from left channel
for FRAME_NO in $frame_indices_L; do
    FRAME_NO_Padded=$(printf "%04d" $FRAME_NO)
    keep_frames_combined["frame${FRAME_NO_Padded}.jpg"]=1
done

# Add frames from right channel
for FRAME_NO in $frame_indices_R; do
    FRAME_NO_Padded=$(printf "%04d" $FRAME_NO)
    keep_frames_combined["frame${FRAME_NO_Padded}.jpg"]=1
done

# Iterate over all extracted frames in left channel and delete those not in keep list
for file in "$OUTPUT_PATH_PICS_L"/*.jpg; do
    filename=$(basename "$file")
    if [[ -z "${keep_frames_combined[$filename]}" ]]; then
        rm "$file"
    fi
done

# Iterate over all extracted frames in right channel and delete those not in keep list
for file in "$OUTPUT_PATH_PICS_R"/*.jpg; do
    filename=$(basename "$file")
    if [[ -z "${keep_frames_combined[$filename]}" ]]; then
        rm "$file"
    fi
done

# Loop to extract frames 0 to 4
for FRAME_NO in $frame_indices_L $frame_indices_R; do
    FRAME_NO_Padded=$(printf "%04d" $FRAME_NO)
    OUTPUT_FILE_L="frame${FRAME_NO_Padded}.jpg"  # Output image file name
    OUTPUT_FILE_R="frame${FRAME_NO_Padded}.jpg"  # Output image file name
    OUTPUT_FILE_PICS_L="${OUTPUT_PATH_PICS_L}/${OUTPUT_FILE_R}"
    OUTPUT_FILE_PICS_R="${OUTPUT_PATH_PICS_R}/${OUTPUT_FILE_R}"

    # Process left channel frames
    if [ -f "$OUTPUT_FILE_PICS_L" ]; then
        filesize=$(stat -c%s "$OUTPUT_FILE_PICS_L")
        filesize_kb=$(echo "scale=2; $filesize / 1024" | bc)
        echo "$FRAME_NO, $filesize, $filesize_kb, Left" >> "$OUTPUT_PATH_SIZE"
    else
        echo "Failed to extract frame $FRAME_NO from LEFT."
    fi

    # Process right channel frames
    if [ -f "$OUTPUT_FILE_PICS_R" ]; then
        filesize=$(stat -c%s "$OUTPUT_FILE_PICS_R")
        filesize_kb=$(echo "scale=2; $filesize / 1024" | bc)
        echo "$FRAME_NO, $filesize, $filesize_kb, Right" >> "$OUTPUT_PATH_SIZE"
    else
        echo "Failed to extract frame $FRAME_NO from RIGHT."
    fi
done

# Recreate L/R videos
ffmpeg -y -pattern_type glob -i "$OUTPUT_PATH_PICS_L/*.jpg" -c:v libx265 -r 10 "$OUTPUT_PATH/recreated_video_L_$INPUT_FILE_L"
ffmpeg -y -pattern_type glob -i "$OUTPUT_PATH_PICS_R/*.jpg" -c:v libx265 -r 10 "$OUTPUT_PATH/recreated_video_R_$INPUT_FILE_R"


# Comparison between original and recreated videos for both channels
echo -e "\n--- Comparison between original and recreated videos ---"

ORIGINAL_FILE_L="$INPUT_PATH_L"
ORIGINAL_FILE_R="$INPUT_PATH_R"
RECREATED_FILE_L="$OUTPUT_PATH/recreated_video_L_$INPUT_FILE_L"
RECREATED_FILE_R="$OUTPUT_PATH/recreated_video_R_$INPUT_FILE_R"

# File sizes
original_size_L=$(stat -c%s "$ORIGINAL_FILE_L")
recreated_size_L=$(stat -c%s "$RECREATED_FILE_L")
original_size_R=$(stat -c%s "$ORIGINAL_FILE_R")
recreated_size_R=$(stat -c%s "$RECREATED_FILE_R")

original_size_kb_L=$(echo "scale=2; $original_size_L / 1024" | bc)
recreated_size_kb_L=$(echo "scale=2; $recreated_size_L / 1024" | bc)
original_size_kb_R=$(echo "scale=2; $original_size_R / 1024" | bc)
recreated_size_kb_R=$(echo "scale=2; $recreated_size_R / 1024" | bc)

echo "Left Channel - Original video size   : $original_size_L bytes ($original_size_kb_L KB)"
echo "Left Channel - Recreated video size  : $recreated_size_L bytes ($recreated_size_kb_L KB)"
echo "Right Channel - Original video size  : $original_size_R bytes ($original_size_kb_R KB)"
echo "Right Channel - Recreated video size : $recreated_size_R bytes ($recreated_size_kb_R KB)"

# Durations
original_duration_L=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$ORIGINAL_FILE_L")
recreated_duration_L=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$RECREATED_FILE_L")
original_duration_R=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$ORIGINAL_FILE_R")
recreated_duration_R=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$RECREATED_FILE_R")

original_duration_sec_L=$(printf "%.2f" "$original_duration_L")
recreated_duration_sec_L=$(printf "%.2f" "$recreated_duration_L")
original_duration_sec_R=$(printf "%.2f" "$original_duration_R")
recreated_duration_sec_R=$(printf "%.2f" "$recreated_duration_R")

echo "Left Channel - Original video duration : $original_duration_sec_L seconds"
echo "Left Channel - Recreated video duration: $recreated_duration_sec_L seconds"
echo "Right Channel - Original video duration: $original_duration_sec_R seconds"
echo "Right Channel - Recreated video duration: $recreated_duration_sec_R seconds"

# Capture the end time
end_time=$(date +%s)

# Calculate and print the total execution time
total_time=$((end_time - start_time))
echo "Total time taken: $total_time seconds"


# Summary statistics output file
SUMMARY_STATS_FILE="$OUTPUT_PATH/summary_stats.txt"

# Count number of frames kept
frames_kept=$(printf "%s\n" $frame_indices_L $frame_indices_R | sort -u | wc -l)

# Write summary to file
{
    echo "--- Summary Statistics ---"
    echo "Frames kept (unique): $frames_kept"
    echo ""
    echo "Left Channel - Original video size   : $original_size_L bytes ($original_size_kb_L KB)"
    echo "Left Channel - Recreated video size  : $recreated_size_L bytes ($recreated_size_kb_L KB)"
    echo "Right Channel - Original video size  : $original_size_R bytes ($original_size_kb_R KB)"
    echo "Right Channel - Recreated video size : $recreated_size_R bytes ($recreated_size_kb_R KB)"
    echo ""
    echo "Left Channel - Original video duration : $original_duration_sec_L seconds"
    echo "Left Channel - Recreated video duration: $recreated_duration_sec_L seconds"
    echo "Right Channel - Original video duration: $original_duration_sec_R seconds"
    echo "Right Channel - Recreated video duration: $recreated_duration_sec_R seconds"
    echo ""
    echo "Total time taken: $total_time seconds"
} > "$SUMMARY_STATS_FILE"

echo -e "\nSummary statistics saved to: $SUMMARY_STATS_FILE"
