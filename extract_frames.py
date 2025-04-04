import json

# Load the JSON file
with open("output_dir/sitiCRstill_walking_still.h265.json", "r") as file:
    data = json.load(file)

# Extract the "ti" values
ti_values = data["ti"]

# Set a threshold
cumsum = 0
threshold = 80

# Create list to store frame indices
frame_indices = []

# Iterate through the "ti" values
#print(f"Frames (0-indexed) where cumulative 'ti' exceeds {threshold}:")
for index, value in enumerate(ti_values):
    cumsum += value
    if cumsum > threshold:
        #print(f"Frame {index}: Cumulative ti = {cumsum}")
        print(index)
        frame_indices.append(index)
        cumsum = 0  # Reset the cumulative sum after printing
    elif value > 25:
        #print(f"Frame {index} value: {value}")
        print(index)
        frame_indices.append(index)
        cumsum = 0

exit()

# Find and print the frames where ti > threshold
print(f"Frames where 'ti' > {threshold}:")
for index, value in enumerate(ti_values):
    if value > threshold:
        print(f"Frame {index}: {value}")
