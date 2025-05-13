#!/bin/bash
# algo3 takes one mp4 input and uses an array of 
# frame indices to determine frames to keep
# This dynamically calculates the frames to keep
# through removal of frames in the SITI calculation, 
# that is not used. Eg. frame 10 is kept, but the 
# relation between frame 10 and 11 does not meet conditions.
# Therefore SITI between frame 10 and 12 is calculated
threshold=21
start_frame=1
frame_dir="picture_output_L"
frame_pattern="frame%04d.jpg"

OUTPUT_BASE_DIR="output_dir/algo3"
mkdir -p "$OUTPUT_BASE_DIR" # Ensure the output directory exists

# Generate timestamp and subfolder
TIMESTAMP=$(date +"%Y-%m-%d__%H-%M-%S")
PICTURE_OUTPUT_SUBDIR="${OUTPUT_BASE_DIR}/${TIMESTAMP}__threshold=${threshold}/frames"
#rm -rf "$PICTURE_OUTPUT_SUBDIR"
mkdir -p "$PICTURE_OUTPUT_SUBDIR"

# Get sorted list of frame numbers
frame_numbers=($(ls "$frame_dir"/frame*.jpg | sed -E 's/.*frame([0-9]+)\.jpg/\1/' | sort -n))
frame_count=${#frame_numbers[@]}
last_frame=${frame_numbers[$((frame_count - 1))]}

while [ $start_frame -lt ${frame_numbers[$((frame_count - 1))]} ]; do
  next_frame=$((start_frame + 1))
  found=0

  while [ $next_frame -le $frame_count ]; do
    frame0=$(printf "$frame_dir/$frame_pattern" $start_frame)
    frameX=$(printf "$frame_dir/$frame_pattern" $next_frame)

    echo "Checking frames $start_frame and $next_frame:"
    #echo "  Frame0: $frame0"
    #echo "  FrameX: $frameX"

    # Prepare temp dir with sequential names
    temp_dir="$PICTURE_OUTPUT_SUBDIR/temp_frames"
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    cp "$frame0" "$temp_dir/frame0001.jpg"
    cp "$frameX" "$temp_dir/frame0002.jpg"

    # Extract TI value using SITI
    ti=$(ffmpeg -framerate 1 -t 2 -i "$temp_dir/frame%04d.jpg" \
      -vf "siti=print_summary=1" -f null - 2>&1 \
      | grep "Temporal Information:" -A3 | grep "Average:" \
      | awk '($2 != "-nan" && $2 != ""){print $2; exit}')

    # Compare TI with threshold using bc
    if (( $(echo "$ti >= $threshold" | bc -l) )); then
      echo "  ✅ Accepted: TI $ti >= threshold $threshold"
      #echo "  📁 Saving frames $start_frame and $next_frame"
      cp "$frame0" "$PICTURE_OUTPUT_SUBDIR/$(basename "$frame0")"
      cp "$frameX" "$PICTURE_OUTPUT_SUBDIR/$(basename "$frameX")"
      start_frame=$next_frame
      found=1
      break
    else
      echo "  ❌ Rejected: TI $ti < threshold $threshold"
    fi

    next_frame=$((next_frame + 1))
  done

  if [ $found -eq 0 ]; then
    echo "❌ No TI > $threshold found after frame $start_frame. Exiting."
    break
  fi
done


echo "Generating recreated video..."
ffmpeg -y -pattern_type glob -i "$PICTURE_OUTPUT_SUBDIR/*.jpg" -c:v libx265 -r 24 "$output_dir/recreated_video_threshold=${threshold}.h265"
