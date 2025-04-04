import json
import sys
import os

from_bash = 0
if __name__ == "__main__":
    # Set an environment variable when called from the bash script
    if len(sys.argv) > 1 and sys.argv[1] == "from_bash":
        os.environ["FROM_BASH"] = "1"
        from_bash = 1


# Load the JSON file
with open("output_dir/sitiCRstill_walking_still.h265.json", "r") as file:
    data = json.load(file)

# Extract the "ti" values
ti_values = data["ti"]

# Set a threshold
cumsum = 0
threshold = 50
max_ti = 10

# Create list to store frame indices
frame_indices = []

# Iterate through the "ti" values
if from_bash == 0:
    print(f"Frames (0-indexed) where cumulative 'ti' exceeds {threshold} or ti exceeds {max_ti}:")

for index, value in enumerate(ti_values):
    cumsum += value
    if cumsum > threshold:
        if from_bash:
            print(index)
        else:
            print(f"Frame {index}: Cumulative ti = {cumsum}")
        frame_indices.append(index)
        cumsum = 0  # Reset the cumulative sum after printing
    elif value > max_ti:
        if from_bash:
            print(index)
        else:
            print(f"Frame {index} value: {value}")
        frame_indices.append(index)
        cumsum = 0

if from_bash == 0:
    print(f"Frames noted: {frame_indices}")
exit()