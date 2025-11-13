#!/usr/bin/env python3
"""
Alternative IMX219 capture test with different pipeline
"""

import cv2
import sys
import time

print("Testing IMX219 Camera Capture - V2")
print("=" * 60)

# Alternative pipeline without NVMM memory
pipeline = (
    "nvarguscamerasrc ! "
    "video/x-raw(memory:NVMM), width=640, height=480, format=NV12, framerate=30/1 ! "
    "nvvidconv ! "
    "video/x-raw, width=640, height=480, format=BGRx ! "
    "videoconvert ! "
    "video/x-raw, format=BGR ! "
    "appsink max-buffers=1 drop=true sync=false"
)

print(f"Pipeline: {pipeline}\n")
print("Opening camera...")

try:
    cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER)

    if not cap.isOpened():
        print("❌ Failed to open camera")
        sys.exit(1)

    print("✅ Camera opened!")
    print("Waiting for camera to stabilize (3 seconds)...")
    time.sleep(3)

    print("Reading frames...")

    # Try to read frames
    success_count = 0
    for i in range(10):
        ret, frame = cap.read()

        if ret and frame is not None:
            success_count += 1
            print(f"✅ Frame {i+1}: {frame.shape[1]}x{frame.shape[0]}")

            # Save first good frame
            if success_count == 1:
                cv2.imwrite('test_frame.jpg', frame)
                print("   Saved test_frame.jpg")
        else:
            print(f"⏭️  Skipped frame {i+1}")

        time.sleep(0.1)

    cap.release()

    print(f"\n✅ Test complete! Successfully captured {success_count}/10 frames")

    if success_count > 0:
        sys.exit(0)
    else:
        sys.exit(1)

except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
