#!/usr/bin/env python3
"""
Simple vision stream test
"""

import sys
import time
from camera_stream import IMX219Camera

print("Testing Vision Stream with IMX219")
print("=" * 60)

# Initialize camera
camera = IMX219Camera(
    device="/dev/video0",
    width=640,
    height=480,
    framerate=30,
    use_gstreamer=True
)

if not camera.open():
    print("Failed to open camera")
    sys.exit(1)

print("Camera opened successfully!")
print("Capturing frames and analyzing...\n")

try:
    for i in range(5):
        ret, frame = camera.read()

        if ret:
            # Simple analysis
            import cv2
            import numpy as np

            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            brightness = np.mean(gray)
            edges = cv2.Canny(gray, 50, 150)
            edge_density = np.sum(edges > 0) / edges.size

            print(f"Frame {i+1}:")
            print(f"  Resolution: {frame.shape[1]}x{frame.shape[0]}")
            print(f"  Brightness: {brightness:.1f}")
            print(f"  Edge density: {edge_density:.3f}")

            if brightness < 50:
                light = "dark"
            elif brightness < 150:
                light = "moderate"
            else:
                light = "bright"

            print(f"  Analysis: Scene is {light}")
            print()
        else:
            print(f"Failed to read frame {i+1}")

        time.sleep(1)

except KeyboardInterrupt:
    print("\nStopped by user")

finally:
    camera.close()
    print("Done!")
