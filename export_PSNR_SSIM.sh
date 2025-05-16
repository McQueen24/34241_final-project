#!/bin/bash
# Takes list of frames frame%04d and finds PSNR and SSIM

# Define functions here:


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

# Output log files
PSNR_LOG="psnr_metrics.log"
SSIM_LOG="ssim_metrics.log"
> "$PSNR_LOG"
> "$SSIM_LOG"

echo "📊 Calculating PSNR and SSIM between frames..."
for frame_path_l in "$OUTPUT_PATH_PICS_L"/frame*.jpg; do
  frame_filename=$(basename "$frame_path_l")
  frame_path_r="$OUTPUT_PATH_PICS_R/$frame_filename"

  if [[ -f "$frame_path_r" ]]; then
    echo "🧪 Comparing $frame_filename"

    psnr_output=$(ffmpeg -i "$frame_path_l" -i "$frame_path_r" \
      -filter_complex "psnr" -f null - 2>&1 | grep "PSNR ")
    ssim_output=$(ffmpeg -i "$frame_path_l" -i "$frame_path_r" \
      -filter_complex "ssim" -f null - 2>&1 | grep "SSIM ")

    #ffmpeg -i "$frame_path_l" -i "$frame_path_r" \
    #  -filter_complex "ssim" -f null - 2>> "$SSIM_LOG"

    echo "$frame_filename $psnr_output" >> "$PSNR_LOG"
    echo "$frame_filename $ssim_output" >> "$SSIM_LOG"
  else
    echo "⚠️ Warning: Matching frame not found for $frame_filename in right directory."
  fi
done
