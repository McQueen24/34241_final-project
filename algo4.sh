#!/bin/bash
# algo4 takes two .h265 input and uses an array of 
# frame indices to determine frames to keep
# This dynamically calculates the frames to keep
# through removal of frames in the SITI calculation, 
# that is not used. Eg. frame 10 is kept, but the 
# relation between frame 10 and 11 does not meet conditions.
# Therefore SITI between frame 10 and 12 is calculated

# Define input and output file 
INPUT_FILE_L="video__2025-04-24__15-14-57__CAMB.h265"
INPUT_FILE_R="video__2025-04-24__15-14-57__CAMC.h265"
INPUT_DIR="sample_data/Lawnmower_Pattern"
INPUT_PATH_L="$INPUT_DIR/$INPUT_FILE_L"
INPUT_PATH_R="$INPUT_DIR/$INPUT_FILE_R"
RESOLUTION="1920x1200"

OUTPUT_PATH_PICS_L="${INPUT_PATH_L}_frames"
OUTPUT_PATH_PICS_R="${INPUT_PATH_R}_frames"
mkdir -p "$OUTPUT_PATH_PICS_L" "$OUTPUT_PATH_PICS_R"

# Check if frames already exist
if ls "$OUTPUT_PATH_PICS_L"/frame*.jpg 1> /dev/null 2>&1; then
  echo "✅ Frames already extracted in '$OUTPUT_PATH_PICS_L'. Skipping extraction."
else
  echo "🎞️ Extracting frames from video..."
  ffmpeg -i "$INPUT_PATH_L" -qscale:v 2 "$OUTPUT_PATH_PICS_L/frame%04d.jpg"
fi


if ls "$OUTPUT_PATH_PICS_R"/frame*.jpg 1> /dev/null 2>&1; then
  echo "✅ Frames already extracted in '$OUTPUT_PATH_PICS_R'. Skipping extraction."
else
  echo "🎞️ Extracting frames from right video..."
  ffmpeg -i "$INPUT_PATH_R" -qscale:v 2 "$OUTPUT_PATH_PICS_R/frame%04d.jpg"
fi

threshold=23
start_frame=1
frame_dir_L="$OUTPUT_PATH_PICS_L"
frame_dir_R="$OUTPUT_PATH_PICS_R"
frame_pattern="frame%04d.jpg"

OUTPUT_BASE_DIR="output_dir/algo4"
mkdir -p "$OUTPUT_BASE_DIR" # Ensure the output directory exists

# Generate timestamp and subfolder
TIMESTAMP=$(date +"%Y-%m-%d__%H-%M-%S")
PICTURE_OUTPUT_SUBDIR_MAIN="${OUTPUT_BASE_DIR}/$TIMESTAMP}__threshold=${threshold}"
PICTURE_OUTPUT_SUBDIR_L="${PICTURE_OUTPUT_SUBDIR_MAIN}/L"
PICTURE_OUTPUT_SUBDIR_R="${PICTURE_OUTPUT_SUBDIR_MAIN}/R"
mkdir -p "$PICTURE_OUTPUT_SUBDIR_L" "$PICTURE_OUTPUT_SUBDIR_R"

# Get sorted list of frame numbers
frame_numbers=($(ls "$frame_dir_L"/frame*.jpg | sed -E 's/.*frame([0-9]+)\.jpg/\1/' | sort -n))
frame_count=${#frame_numbers[@]}
last_frame=${frame_numbers[$((frame_count - 1))]}

while [ $start_frame -lt ${frame_numbers[$((frame_count - 1))]} ]; do
  next_frame=$((start_frame + 1))
  found=0

  while [ $next_frame -le $frame_count ]; do
    frame0_L=$(printf "$frame_dir_L/$frame_pattern" $start_frame)
    frameX_L=$(printf "$frame_dir_L/$frame_pattern" $next_frame)
    frame0_R=$(printf "$frame_dir_R/$frame_pattern" $start_frame)
    frameX_R=$(printf "$frame_dir_R/$frame_pattern" $next_frame)

    echo "Checking frames $start_frame and $next_frame:"

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

    keep=0
    if (( $(echo "$ti_L >= $threshold" | bc -l) )); then
      echo "  ✅ Left TI $ti_L >= $threshold"
      keep=1
    fi
    if (( $(echo "$ti_R >= $threshold" | bc -l) )); then
      echo "  ✅ Right TI $ti_R >= $threshold"
      keep=1
    fi

    if [ $keep -eq 1 ]; then
      cp "$frame0_L" "$PICTURE_OUTPUT_SUBDIR_L/$(basename "$frame0_L")"
      cp "$frameX_L" "$PICTURE_OUTPUT_SUBDIR_L/$(basename "$frameX_L")"
      cp "$frame0_R" "$PICTURE_OUTPUT_SUBDIR_R/$(basename "$frame0_R")"
      cp "$frameX_R" "$PICTURE_OUTPUT_SUBDIR_R/$(basename "$frameX_R")"
      start_frame=$next_frame
      found=1
      break
    else
      echo "  ❌ Neither TI passed threshold ($threshold). TI_L=$ti_L, TI_R=$ti_R"
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
ffmpeg -y -pattern_type glob -i "$PICTURE_OUTPUT_SUBDIR_L"'/*.jpg' -c:v libx265 -r 24 "$OUTPUT_BASE_DIR/recreated_video_threshold=${threshold}_L.h265"
ffmpeg -y -pattern_type glob -i "$PICTURE_OUTPUT_SUBDIR_R"'/*.jpg' -c:v libx265 -r 24 "$OUTPUT_BASE_DIR/recreated_video_threshold=${threshold}_R.h265"
