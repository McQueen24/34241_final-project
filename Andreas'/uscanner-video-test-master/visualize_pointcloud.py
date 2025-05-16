#!/usr/bin/env python3

import depthai as dai
from time import sleep
import numpy as np
import cv2
import time
import sys
try:
    import open3d as o3d
except ImportError:
    sys.exit("Critical dependency missing: Open3D. Please install it using the command: '{} -m pip install open3d' and then rerun the script.".format(sys.executable))

FPS = 10
class FPSCounter:
    def __init__(self):
        self.frameCount = 0
        self.fps = 0
        self.startTime = time.time()

    def tick(self):
        self.frameCount += 1
        if self.frameCount % 10 == 0:
            elapsedTime = time.time() - self.startTime
            self.fps = self.frameCount / elapsedTime
            self.frameCount = 0
            self.startTime = time.time()
        return self.fps

pipeline = dai.Pipeline()

# Camera for CAM_B (right in stereo pair)
camB = pipeline.create(dai.node.ColorCamera)
camB.setBoardSocket(dai.CameraBoardSocket.CAM_B)
camB.setResolution(dai.ColorCameraProperties.SensorResolution.THE_1200_P)  # AR0234 supports 1920x1080
camB.setPreviewSize(640, 400)  # Match mono resolution in example
camB.setFps(FPS)

# Camera for CAM_C (left in stereo pair)
camC = pipeline.create(dai.node.ColorCamera)
camC.setBoardSocket(dai.CameraBoardSocket.CAM_C)
camC.setResolution(dai.ColorCameraProperties.SensorResolution.THE_1200_P)
camC.setPreviewSize(640, 400)
camC.setFps(FPS)

# Convert Color to Grayscale for depth calculation
# ImageManip for CAM_C (right)
manipRight = pipeline.create(dai.node.ImageManip)
manipRight.initialConfig.setFrameType(dai.ImgFrame.Type.GRAY8)  # Grayscale output
camC.preview.link(manipRight.inputImage)  # Use preview output

# ImageManip for CAM_B (left)
manipLeft = pipeline.create(dai.node.ImageManip)
manipLeft.initialConfig.setFrameType(dai.ImgFrame.Type.GRAY8)
camB.preview.link(manipLeft.inputImage)

depth = pipeline.create(dai.node.StereoDepth)
depth.setDefaultProfilePreset(dai.node.StereoDepth.PresetMode.HIGH_DENSITY)
depth.initialConfig.setMedianFilter(dai.MedianFilter.KERNEL_7x7)
depth.setLeftRightCheck(True)
depth.setExtendedDisparity(False)
depth.setSubpixel(True)
depth.setDepthAlign(dai.CameraBoardSocket.CAM_B)  # Align depth to CAM_B

# Link grayscale outputs to depth inputs
manipLeft.out.link(depth.left)
manipRight.out.link(depth.right)

pointcloud = pipeline.create(dai.node.PointCloud)
depth.depth.link(pointcloud.inputDepth)

sync = pipeline.create(dai.node.Sync)
camB.preview.link(sync.inputs["rgb"])  # Use CAM_B preview for color
pointcloud.outputPointCloud.link(sync.inputs["pcl"])

xOut = pipeline.create(dai.node.XLinkOut)
xOut.setStreamName("out")
sync.out.link(xOut.input)

with dai.Device(pipeline) as device:
    isRunning = True
    def key_callback(vis, action, mods):
        global isRunning
        if action == 0:
            isRunning = False

    q = device.getOutputQueue(name="out", maxSize=4, blocking=False)
    vis = o3d.visualization.VisualizerWithKeyCallback()
    vis.create_window()
    vis.register_key_action_callback(81, key_callback)
    pcd = o3d.geometry.PointCloud()
    coordinateFrame = o3d.geometry.TriangleMesh.create_coordinate_frame(size=1000, origin=[0,0,0])
    vis.add_geometry(coordinateFrame)

    first = True
    fpsCounter = FPSCounter()

    print("Remember to use mouse to rotate the point cloud and scroll to zoom in/out.")
    print("Press 'q' to exit.")
    while isRunning:
        inMessage = q.get()
        inColor = inMessage["rgb"]
        inPointCloud = inMessage["pcl"]
        cvColorFrame = inColor.getCvFrame()
        # Convert the frame to RGB
        cvRGBFrame = cv2.cvtColor(cvColorFrame, cv2.COLOR_BGR2RGB)
        fps = fpsCounter.tick()
        # Display the FPS on the frame
        cv2.putText(cvColorFrame, f"FPS: {fps:.2f}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
        cv2.imshow("color", cvColorFrame)
        key = cv2.waitKey(1)
        if key == ord('q'):
            break
        if inPointCloud:
            t_before = time.time()
            points = inPointCloud.getPoints().astype(np.float64)
            pcd.points = o3d.utility.Vector3dVector(points)
            colors = (cvRGBFrame.reshape(-1, 3) / 255.0).astype(np.float64)
            pcd.colors = o3d.utility.Vector3dVector(colors)
            if first:
                vis.add_geometry(pcd)
                first = False
            else:
                vis.update_geometry(pcd)
        vis.poll_events()
        vis.update_renderer()
    vis.destroy_window()
