import json
import sys
import os
import pathlib

from_bash = False

if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "from_bash":
        os.environ["FROM_BASH"] = "1"
        from_bash = True

    if len(sys.argv) >= 3:
        input_file = sys.argv[2]
    else:
        print("Error: No input path provided.")
        sys.exit(1)

# Derive the .json path from the video input
basename = pathlib.Path(input_file).stem  # e.g., "video__2025-04-24__15-12-25__CAMB"
json_path = f"output_dir/json_output_dir/sitiCR{basename}.h265.json"

# Load the JSON file
try:
    with open(json_path, "r") as file:
        data = json.load(file)
except FileNotFoundError:
    print(f"Error: Could not find JSON file at '{json_path}'")
    sys.exit(1)

# Extract the "ti" values
ti_values = data["ti"]

# Processing logic
cumsum = 0
threshold = 50
max_ti = 10
frame_indices = []

if not from_bash:
    print(f"Frames (0-indexed) where cumulative 'ti' exceeds {threshold} or ti exceeds {max_ti}:")

for index, value in enumerate(ti_values):
    cumsum += value
    if cumsum > threshold or value > max_ti:
        if from_bash:
            print(index)
        else:
            print(f"Frame {index}: Cumulative ti = {cumsum}, Value = {value}")
        frame_indices.append(index)
        cumsum = 0

if not from_bash:
    print(f"Frames noted: {frame_indices}")
    print(f"# of frames found: {len(frame_indices)}")
    print(f"# of original frames: {len(ti_values)}")
    print(f"# of frames removed: {len(ti_values)-len(frame_indices)}")
