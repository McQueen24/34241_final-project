#!/usr/bin/env python3
import sys
import cv2
import numpy as np
from siti_tools.siti import SiTiCalculator  # Make sure you're using the GitHub version

def load_grayscale_frame_from_video(video_path, frame_index):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise IOError(f"Could not open video file: {video_path}")

    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
    ret, frame = cap.read()
    cap.release()

    if not ret or frame is None:
        raise ValueError(f"Could not read frame {frame_index} from {video_path}")

    gray_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    return gray_frame.astype(np.float32)

def main(video_path, frame_idx1, frame_idx2):
    frame1 = load_grayscale_frame_from_video(video_path, frame_idx1)
    frame2 = load_grayscale_frame_from_video(video_path, frame_idx2)

    if frame1.shape != frame2.shape:
        raise ValueError("Frames do not have the same dimensions.")

    ti = SiTiCalculator.ti(frame2, frame1)  # frame2 is current, frame1 is previous
    print(f"{ti:.4f}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: compute_ti.py <video.h265> <frame_index_1> <frame_index_2>", file=sys.stderr)
        sys.exit(1)

    video_path = sys.argv[1]
    frame_idx1 = int(sys.argv[2])
    frame_idx2 = int(sys.argv[3])

    try:
        main(video_path, frame_idx1, frame_idx2)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
