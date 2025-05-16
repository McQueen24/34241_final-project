#!/usr/bin/env python3
import depthai as dai
import os
from datetime import datetime, timedelta

def calculate_bitrate(file_path, frame_count, fps):
    """
    Calculate the actual bitrate based on file size and recording time
    
    Args:
        file_path (str): Path to the video file
        frame_count (int): Number of frames recorded
        fps (int): Frames per second
        
    Returns:
        float: Bitrate in Mbps
    """
    filesize = os.path.getsize(file_path)  # in bytes
    duration = frame_count / fps  # recording duration in seconds
    
    # Calculate actual bitrate (bits per second)
    bitrate = (filesize * 8) / duration if duration > 0 else 0
    
    # Convert to more readable units (Mbps)
    return bitrate / 1_000_000

FPS = 10

# Create pipeline
pipeline = dai.Pipeline()

# Define nodes
camB = pipeline.create(dai.node.ColorCamera)
videoEncB = pipeline.create(dai.node.VideoEncoder)
camC = pipeline.create(dai.node.ColorCamera)
videoEncC = pipeline.create(dai.node.VideoEncoder)
sync = pipeline.create(dai.node.Sync)
demux = pipeline.create(dai.node.MessageDemux)
xoutB = pipeline.create(dai.node.XLinkOut)
xoutC = pipeline.create(dai.node.XLinkOut)

# Set stream names for XLinkOut
xoutB.setStreamName("CAM_B")
xoutC.setStreamName("CAM_C")

# Camera Properties
camB.setBoardSocket(dai.CameraBoardSocket.CAM_B)
camB.setResolution(dai.ColorCameraProperties.SensorResolution.THE_1200_P)
camB.setFps(FPS)
camB.setInterleaved(False)
camB.initialControl.setAutoExposureLimit(maxExposureTimeUs=10_000) # 10_000 us or 10ms
# camB.initialControl.setAutoExposureCompensation(-1) 

camC.setBoardSocket(dai.CameraBoardSocket.CAM_C)
camC.setResolution(dai.ColorCameraProperties.SensorResolution.THE_1200_P)
camC.setFps(FPS)
camC.setInterleaved(False)
camC.initialControl.setAutoExposureLimit(maxExposureTimeUs=10_000) # 10_000 us or 10ms
# camC.initialControl.setAutoExposureCompensation(-1) 

# Encoder settings
videoEncB.setDefaultProfilePreset(FPS, dai.VideoEncoderProperties.Profile.H265_MAIN)
videoEncC.setDefaultProfilePreset(FPS, dai.VideoEncoderProperties.Profile.H265_MAIN)
videoEncB.setRateControlMode(dai.VideoEncoderProperties.RateControlMode.VBR) # Variable Bit Rate for consistent quality
videoEncC.setRateControlMode(dai.VideoEncoderProperties.RateControlMode.VBR)
videoEncB.setKeyframeFrequency(FPS)
videoEncC.setKeyframeFrequency(FPS)
videoEncB.setQuality(50)
videoEncC.setQuality(50)

# Linking no encoder
camB.video.link(sync.inputs["CAM_B"])
camC.video.link(sync.inputs["CAM_C"])

# Sync configuration
sync.setSyncThreshold(timedelta(milliseconds=10))
sync.setSyncAttempts(5)

# Demux configuration
sync.out.link(demux.input)
demux.outputs["CAM_B"].link(videoEncB.input)
demux.outputs["CAM_C"].link(videoEncC.input)

# Link encoders to XLinkOut
videoEncB.bitstream.link(xoutB.input)
videoEncC.bitstream.link(xoutC.input)

with dai.Device(pipeline) as device:
    # Get output queues for each camera stream
    qB = device.getOutputQueue(name="CAM_B", maxSize=4, blocking=True)
    qC = device.getOutputQueue(name="CAM_C", maxSize=4, blocking=True)

    # Get current datetime in human-readable format
    now = datetime.now()
    timestamp = now.strftime("%Y-%m-%d__%H-%M-%S")

    raw_video_path_B = f'videos/video__{timestamp}__CAMB.h265'
    raw_video_path_C = f'videos/video__{timestamp}__CAMC.h265'
    
    for path in [raw_video_path_C, raw_video_path_B]:
        if os.path.exists(path):
            os.remove(path)
    
    frame_count_B = 0
    frame_count_C = 0

    with open(raw_video_path_B, 'wb') as videoFileB, open(raw_video_path_C, 'wb') as videoFileC:
            print("Press Ctrl+C to stop encoding...")
            try:
                while True:
                    # Get messages from both queues (blocking)
                    msgB = qB.get()  # Blocking get
                    msgC = qC.get()  # Blocking get
                    
                    # Process frame from camera B
                    dataB = msgB.getData()
                    videoFileB.write(dataB)
                    frame_count_B += 1
                    
                    # Process frame from camera C
                    dataC = msgC.getData()
                    videoFileC.write(dataC)
                    frame_count_C += 1
                    
            except KeyboardInterrupt:
                # Summary
                print(f"\nStopped. Final frame counts: B={frame_count_B}, C={frame_count_C}")

                # Calculate and display bitrates
                bitrate_B_mbps = calculate_bitrate(raw_video_path_B, frame_count_B, FPS)
                bitrate_C_mbps = calculate_bitrate(raw_video_path_C, frame_count_C, FPS)
                print(f"Actual bitrate - Camera B: {bitrate_B_mbps:.2f} Mbps, Camera C: {bitrate_C_mbps:.2f} Mbps")

                # Close video files
                videoFileB.flush()
                videoFileC.flush()
                videoFileB.close()
                videoFileC.close()