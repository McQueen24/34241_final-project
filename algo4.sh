#!/bin/bash
# algo4 takes two .h265 input and uses an array of 
# frame indices to determine frames to keep
# This dynamically calculates the frames to keep
# through removal of frames in the SITI calculation, 
# that is not used. Eg. frame 10 is kept, but the 
# relation between frame 10 and 11 does not meet conditions.
# Therefore SITI between frame 10 and 12 is calculated

QUIET=0

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    -quiet)
      QUIET=1
      ;;
  esac
done

# Define functions here:
get_avg_ti() {
  local input_path="$1"
  local ti_cache_file="${input_path}_ti.txt"

  if [[ -f "$ti_cache_file" ]]; then
    echo "✅ Cached average TI found for $input_path" >&2  # log to stderr
    cat "$ti_cache_file"
  else
    echo "🧮 Calculating average TI for $input_path..." >&2  # log to stderr
    avg_ti=$(ffmpeg -i "$input_path" -vf "siti=print_summary=1" -f null - 2>&1 \
      | grep "Temporal Information:" -A3 | grep "Average:" \
      | awk '($2 != "-nan" && $2 != ""){print $2; exit}')
    echo "$avg_ti" > "$ti_cache_file"
    echo "$avg_ti"
  fi
}

# Define input and output file 
INPUT_FILE_L="CAMB.h265"
INPUT_FILE_R="CAMC.h265"
INPUT_DIR="sample_data/Lawnmower_Pattern"
INPUT_PATH_L="$INPUT_DIR/$INPUT_FILE_L"
INPUT_PATH_R="$INPUT_DIR/$INPUT_FILE_R"
RESOLUTION="1920x1200"

OUTPUT_PATH_PICS_L="${INPUT_PATH_L}_frames_Q2"
OUTPUT_PATH_PICS_R="${INPUT_PATH_R}_frames_Q2"
mkdir -p "$OUTPUT_PATH_PICS_L" "$OUTPUT_PATH_PICS_R"

# Check if frames already exist
if ls "$OUTPUT_PATH_PICS_L"/frame*.jpg 1> /dev/null 2>&1; then
  echo "✅ Frames already extracted in '$OUTPUT_PATH_PICS_L'. Skipping extraction."
else
  echo "🎞️ Extracting frames from video..."
  ffmpeg -i "$INPUT_PATH_L" -qscale:v 31 "$OUTPUT_PATH_PICS_L/frame%04d.jpg"
fi


if ls "$OUTPUT_PATH_PICS_R"/frame*.jpg 1> /dev/null 2>&1; then
  echo "✅ Frames already extracted in '$OUTPUT_PATH_PICS_R'. Skipping extraction."
else
  echo "🎞️ Extracting frames from right video..."
  ffmpeg -i "$INPUT_PATH_R" -qscale:v 31 "$OUTPUT_PATH_PICS_R/frame%04d.jpg"
fi

#read -p "Press enter to continue"
echo "Finding average TI for full videos..."

avg_ti_L=$(get_avg_ti "$INPUT_PATH_L")
avg_ti_R=$(get_avg_ti "$INPUT_PATH_R")

echo "Average TI for Left is: $avg_ti_L"
echo "Average TI for Right is: $avg_ti_R"

threshold_L="$avg_ti_L"
threshold_R="$avg_ti_R"
threshold_multiplier="0.67"
threshold=$(echo "scale=4; (($avg_ti_L + $avg_ti_R) / 2) * $threshold_multiplier" | bc) # scale is decimal places for the threshold
echo "📏 Combined average threshold after multiplier: $threshold"
#read -p "Press enter to continue"

# Check if cumulative TI exceeds x times threshold
maxcum_multiplier="5"
maxcum=$(echo "$threshold * $maxcum_multiplier" | bc)
count_normal_threshold=0
count_normal_threshold_L=0
count_normal_threshold_R=0
count_cumsum_threshold=0
count_cumsum_threshold_L=0
count_cumsum_threshold_R=0
start_frame=1
frame_dir_L="$OUTPUT_PATH_PICS_L"
frame_dir_R="$OUTPUT_PATH_PICS_R"
frame_pattern="frame%04d.jpg"

OUTPUT_BASE_DIR="output_dir/algo4"
mkdir -p "$OUTPUT_BASE_DIR" # Ensure the output directory exists


# Generate timestamp and subfolder
TIMESTAMP=$(date +"%Y-%m-%d__%H-%M-%S")
PICTURE_OUTPUT_SUBDIR_MAIN="${OUTPUT_BASE_DIR}/${INPUT_FILE_L}__threshold=${threshold}_maxcum=${maxcum_multiplier}*threshold"
PICTURE_OUTPUT_SUBDIR_L="${PICTURE_OUTPUT_SUBDIR_MAIN}/L"
PICTURE_OUTPUT_SUBDIR_R="${PICTURE_OUTPUT_SUBDIR_MAIN}/R"
rm -rf "$PICTURE_OUTPUT_SUBDIR_L" "$PICTURE_OUTPUT_SUBDIR_R"
mkdir -p "$PICTURE_OUTPUT_SUBDIR_L" "$PICTURE_OUTPUT_SUBDIR_R"

CSV_OUTPUT_DIR="$OUTPUT_BASE_DIR/csv_output_dir"
mkdir -p "$CSV_OUTPUT_DIR"
CSV_FILE="$CSV_OUTPUT_DIR/${INPUT_FILE_L}__threshold=${threshold}_maxcum=${maxcum_multiplier}*threshold.csv"

# Get sorted list of frame numbers
frame_numbers=($(ls "$frame_dir_L"/frame*.jpg | sed -E 's/.*frame([0-9]+)\.jpg/\1/' | sort -n))
frame_count=${#frame_numbers[@]}
last_frame=${frame_numbers[$((frame_count - 1))]}

# Initialize cumsum of left and right
cum_ti_L=0
cum_ti_R=0

while [ $start_frame -lt ${frame_numbers[$((frame_count - 1))]} ]; do
  next_frame=$((start_frame + 1))
  found=0

  while [ $next_frame -le $frame_count ]; do
    frame0_L=$(printf "$frame_dir_L/$frame_pattern" $start_frame)
    frameX_L=$(printf "$frame_dir_L/$frame_pattern" $next_frame)
    frame0_R=$(printf "$frame_dir_R/$frame_pattern" $start_frame)
    frameX_R=$(printf "$frame_dir_R/$frame_pattern" $next_frame)

    [ "$QUIET" -eq 0 ] && echo "Checking frames $start_frame and $next_frame:"
    #echo "Checking frames $start_frame and $next_frame:"

    temp_base_L="$PICTURE_OUTPUT_SUBDIR_L/temp"
    temp_base_R="$PICTURE_OUTPUT_SUBDIR_R/temp"
    rm -rf "$temp_base_L"
    rm -rf "$temp_base_R"
    mkdir -p "$temp_base_L" "$temp_base_R"
    cp "$frame0_L" "$temp_base_L/frame0001.jpg"
    cp "$frameX_L" "$temp_base_L/frame0002.jpg"
    cp "$frame0_R" "$temp_base_R/frame0001.jpg"
    cp "$frameX_R" "$temp_base_R/frame0002.jpg"

    # Extract TI for Left
    ti_L=$(ffmpeg -framerate 1 -t 2 -i "$temp_base_L/frame%04d.jpg"\
      -vf "siti=print_summary=1" -f null - 2>&1 \
      | grep "Temporal Information:" -A3 | grep "Average:" \
      | awk '($2 != "-nan" && $2 != ""){print $2; exit}')

    # Extract TI for Right
    ti_R=$(ffmpeg -framerate 1 -t 2 -i "$temp_base_R/frame%04d.jpg" \
      -vf "siti=print_summary=1" -f null - 2>&1 \
      | grep "Temporal Information:" -A3 | grep "Average:" \
      | awk '($2 != "-nan" && $2 != ""){print $2; exit}')

    # NEW: Accumulate TI values
    cum_ti_L=$(echo "$cum_ti_L + $ti_L" | bc)
    cum_ti_R=$(echo "$cum_ti_R + $ti_R" | bc)

    keep=0
    keep_reason=""
    # Check normal threshold for Left or Right
    if (( $(echo "$ti_L >= $threshold" | bc -l) )) || (( $(echo "$ti_R >= $threshold" | bc -l) )); then
      if (( $(echo "$ti_L >= $threshold" | bc -l) )) && (( $(echo "$ti_R >= $threshold" | bc -l) )); then
        echo "  ✅ Both ti above max TI! Left TI $ti_R >= $threshold & Left TI $ti_L >= $threshold"
        count_normal_threshold=$((count_normal_threshold + 1))
      elif (( $(echo "$ti_L >= $threshold" | bc -l) )); then
        echo "  ✅ Left TI $ti_L >= $threshold"
        count_normal_threshold_L=$((count_normal_threshold_L + 1))
      
      elif (( $(echo "$ti_R >= $threshold" | bc -l) )); then
        echo "  ✅ Right TI $ti_R >= $threshold"
        count_normal_threshold_R=$((count_normal_threshold_R + 1))
      fi
      keep=1
      keep_reason="normal"
      # Check cumulative threshold for Left or Right
    elif (( $(echo "$cum_ti_L >= $maxcum" | bc -l) )) || (( $(echo "$cum_ti_R >= $maxcum" | bc -l) )); then
      if (( $(echo "$cum_ti_L >= $maxcum" | bc -l) )) && (( $(echo "$cum_ti_R >= $maxcum" | bc -l) )); then
        echo "  ✅ Both cumsum above threshold! Left TI $cum_ti_L >= $maxcum & Right TI $cum_ti_R >= $maxcum"
        count_cumsum_threshold=$((count_cumsum_threshold + 1))
      elif (( $(echo "$cum_ti_L >= $maxcum" | bc -l) )); then
        echo "  ✅ Cumulative Left TI $cum_ti_L >= $maxcum"
        count_cumsum_threshold_L=$((count_cumsum_threshold_L + 1))
      elif (( $(echo "$cum_ti_R >= $maxcum" | bc -l) )); then
        echo "  ✅ Cumulative Right TI $cum_ti_R >= $maxcum"
        count_cumsum_threshold_R=$((count_cumsum_threshold_R + 1))
      fi
      keep=1
      keep_reason="cumsum"
    fi



    if [ $keep -eq 1 ]; then
      cp "$frame0_L" "$PICTURE_OUTPUT_SUBDIR_L/$(basename "$frame0_L")"
      cp "$frameX_L" "$PICTURE_OUTPUT_SUBDIR_L/$(basename "$frameX_L")"
      cp "$frame0_R" "$PICTURE_OUTPUT_SUBDIR_R/$(basename "$frame0_R")"
      cp "$frameX_R" "$PICTURE_OUTPUT_SUBDIR_R/$(basename "$frameX_R")"
      start_frame=$next_frame
      found=1
      # Reset cumulative TI after keeping frames
      cum_ti_L=0
      cum_ti_R=0
      break
    else
      echo "  ❌ No thresholds passed, skipping frame $next_frame"
      echo "     max_ti threshold ($threshold). TI_L=$ti_L, TI_R=$ti_R"
      echo "     cumsum threshold ($maxcum). cum_ti_L=$cum_ti_L, cum_ti_R=$cum_ti_R"
    fi

    next_frame=$((next_frame + 1))
  done

  if [ $found -eq 0 ]; then
    echo "❌ No TI > $threshold found after frame $start_frame. Exiting."
    break
  fi
done

echo "Removing temp directories..."
rm -rf "$temp_base_L"
rm -rf "$temp_base_R"

echo "Generating recreated video..."
ffmpeg -y -pattern_type glob -i "$PICTURE_OUTPUT_SUBDIR_L"'/*.jpg' -c:v libx265 -r 24 "$PICTURE_OUTPUT_SUBDIR_MAIN/recreated_video_threshold=${threshold}_maxcum=${maxcum_multiplier}*threshold_L.mp4"
#ffmpeg -y -pattern_type glob -i "$PICTURE_OUTPUT_SUBDIR_R"'/*.jpg' -c:v libx265 -r 24 "$PICTURE_OUTPUT_SUBDIR_MAIN/recreated_video_threshold=${threshold}_maxcum=${maxcum_multiplier}*threshold_R.mp4"

# Count original and recreated frames
original_frames=$(ls "$frame_dir_L"/frame*.jpg | wc -l)
recreated_frames_L=$(ls "$PICTURE_OUTPUT_SUBDIR_L"/frame*.jpg | wc -l)
recreated_frames_R=$(ls "$PICTURE_OUTPUT_SUBDIR_R"/frame*.jpg | wc -l)

SUMMARY_FILE="$PICTURE_OUTPUT_SUBDIR_MAIN/summary.txt"


# Print summary once to console and save to summary.txt
{
  echo ""
  echo "=== Summary ==="
  echo "Original number of frames: $original_frames"
  echo "Recreated frames in Left video: $recreated_frames_L"
  echo "Recreated frames in Right video: $recreated_frames_R"
  echo "Frames kept due to both normal TI threshold exceeded: $count_normal_threshold"
  echo "Frames kept due to normal TI threshold (Left): $count_normal_threshold_L"
  echo "Frames kept due to normal TI threshold (Right): $count_normal_threshold_R"
  echo "Frames kept due to both cumsum TI threshold exceeded: $count_cumsum_threshold"
  echo "Frames kept due to cumulative TI threshold (Left): $count_cumsum_threshold_L"
  echo "Frames kept due to cumulative TI threshold (Right): $count_cumsum_threshold_R"
  echo "Cumsum multiplier set to ${maxcum_multiplier}"
  echo "TI threshold multiplier set to ${threshold_multiplier}"
  echo "TI threshold was $threshold"
} | tee "$SUMMARY_FILE"

# Create CSV summary file separately (no console output)
{
  echo "Description,Value"
  echo "Original number of frames,$original_frames"
  echo "Recreated frames in Left video,$recreated_frames_L"
  echo "Recreated frames in Right video,$recreated_frames_R"
  echo "Frames kept due to both normal TI threshold exceeded,$count_normal_threshold"
  echo "Frames kept due to normal TI threshold (Left),$count_normal_threshold_L"
  echo "Frames kept due to normal TI threshold (Right),$count_normal_threshold_R"
  echo "Frames kept due to both cumsum TI threshold exceeded,$count_cumsum_threshold"
  echo "Frames kept due to cumulative TI threshold (Left),$count_cumsum_threshold_L"
  echo "Frames kept due to cumulative TI threshold (Right),$count_cumsum_threshold_R"
  echo "Cumsum multiplier set,$maxcum_multiplier"
  echo "TI threshold multiplier set,$threshold_multiplier"
  echo "TI threshold,$threshold"
} > "$CSV_FILE"
