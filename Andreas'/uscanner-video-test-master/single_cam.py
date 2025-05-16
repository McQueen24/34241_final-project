#!/usr/bin/env python3

import depthai as dai
import os

# Create pipeline
pipeline = dai.Pipeline()

# Define sources and output
camB = pipeline.create(dai.node.ColorCamera)
videoEncB = pipeline.create(dai.node.VideoEncoder)
xoutB = pipeline.create(dai.node.XLinkOut)
xoutB.setStreamName('h265B')

# Properties
camB.setBoardSocket(dai.CameraBoardSocket.CAM_B)
camB.setResolution(dai.ColorCameraProperties.SensorResolution.THE_1200_P)
camB.setFps(24)
videoEncB.setDefaultProfilePreset(24, dai.VideoEncoderProperties.Profile.H265_MAIN)  # MAIN profile is more compatible

# Linking
camB.video.link(videoEncB.input)
videoEncB.bitstream.link(xoutB.input)

# Connect to device and start pipeline
with dai.Device(pipeline) as device:
    # Output queue will be used to get the encoded data from the output defined above
    q = device.getOutputQueue(name="h265B", maxSize=24, blocking=True)

    # First create a raw H.265 file
    raw_video_path = 'video.h265'

    # Remove the file if it already exists
    if os.path.exists(raw_video_path):
        os.remove(raw_video_path)
    with open(raw_video_path, 'wb') as videoFile:
        print("Press Ctrl+C to stop encoding...")
        try:
            while True:
                h265Packet = q.get()  # Blocking call, will wait until a new data has arrived
                h265Packet.getData().tofile(videoFile)  # Appends the packet data to the opened file
        except KeyboardInterrupt:
            # Keyboard interrupt (Ctrl + C) detected
            pass