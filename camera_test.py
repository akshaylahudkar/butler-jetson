#!/usr/bin/env python3
"""
IMX219 Camera Test Script for Jetson Orin Nano
Tests camera detection and basic capture functionality
"""

import sys
import os

def test_camera_device():
    """Check if /dev/video0 exists"""
    print("=" * 60)
    print("IMX219 Camera Detection Test")
    print("=" * 60)

    video_device = "/dev/video0"

    if os.path.exists(video_device):
        print(f"✅ Camera device found: {video_device}")
        return True
    else:
        print(f"❌ Camera device not found: {video_device}")
        print("\nTroubleshooting:")
        print("1. Check camera is physically connected")
        print("2. Run: ls -l /dev/video*")
        print("3. Run: v4l2-ctl --list-devices")
        return False

def test_opencv_capture():
    """Test OpenCV camera capture"""
    print("\n" + "=" * 60)
    print("OpenCV Capture Test")
    print("=" * 60)

    try:
        import cv2
        print("✅ OpenCV imported successfully")

        # Try to open camera
        cap = cv2.VideoCapture(0)

        if not cap.isOpened():
            print("❌ Failed to open camera")
            cap.release()
            return False

        print("✅ Camera opened successfully")

        # Try to read a frame
        ret, frame = cap.read()

        if not ret:
            print("❌ Failed to read frame from camera")
            cap.release()
            return False

        print("✅ Successfully captured frame")
        print(f"   Resolution: {frame.shape[1]}x{frame.shape[0]}")
        print(f"   Channels: {frame.shape[2]}")
        print(f"   Data type: {frame.dtype}")

        cap.release()
        return True

    except ImportError:
        print("❌ OpenCV not installed")
        print("   Install with: sudo apt install python3-opencv")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_gstreamer_pipeline():
    """Test GStreamer pipeline (Jetson optimized)"""
    print("\n" + "=" * 60)
    print("GStreamer Pipeline Test")
    print("=" * 60)

    try:
        import cv2

        # IMX219 optimized GStreamer pipeline for Jetson
        gst_pipeline = (
            "nvarguscamerasrc sensor-id=0 ! "
            "video/x-raw(memory:NVMM), width=1280, height=720, format=NV12, framerate=30/1 ! "
            "nvvidconv ! "
            "video/x-raw, format=BGRx ! "
            "videoconvert ! "
            "video/x-raw, format=BGR ! "
            "appsink"
        )

        print("Testing Jetson-optimized GStreamer pipeline...")
        print(f"Pipeline: {gst_pipeline}")

        cap = cv2.VideoCapture(gst_pipeline, cv2.CAP_GSTREAMER)

        if not cap.isOpened():
            print("❌ GStreamer pipeline failed to open")
            print("   This is normal if not on Jetson hardware")
            cap.release()
            return False

        print("✅ GStreamer pipeline opened successfully")

        ret, frame = cap.read()
        if ret:
            print("✅ Successfully captured frame via GStreamer")
            print(f"   Resolution: {frame.shape[1]}x{frame.shape[0]}")
        else:
            print("❌ Failed to capture frame")

        cap.release()
        return ret

    except Exception as e:
        print(f"❌ GStreamer test error: {e}")
        return False

def test_v4l2():
    """Test v4l2 camera info"""
    print("\n" + "=" * 60)
    print("V4L2 Camera Information")
    print("=" * 60)

    import subprocess

    try:
        result = subprocess.run(
            ['v4l2-ctl', '--list-devices'],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            print("✅ v4l2-ctl available")
            print("\nAvailable devices:")
            print(result.stdout)
        else:
            print("❌ v4l2-ctl command failed")

    except FileNotFoundError:
        print("❌ v4l2-ctl not installed")
        print("   Install with: sudo apt install v4l-utils")
    except subprocess.TimeoutExpired:
        print("❌ v4l2-ctl command timed out")
    except Exception as e:
        print(f"❌ Error running v4l2-ctl: {e}")

def main():
    """Run all camera tests"""
    print("\n🔍 Starting IMX219 Camera Tests...\n")

    results = {
        "Device Detection": test_camera_device(),
        "OpenCV Capture": test_opencv_capture(),
        "GStreamer Pipeline": test_gstreamer_pipeline(),
    }

    test_v4l2()

    # Summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)

    for test_name, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{test_name}: {status}")

    all_passed = all(results.values())

    print("\n" + "=" * 60)
    if all_passed:
        print("🎉 All tests passed! Camera is ready.")
        print("\nNext steps:")
        print("1. Run: python3 camera_stream.py")
        print("2. Run: python3 vision_stream.py")
    else:
        print("⚠️  Some tests failed. Check errors above.")
        print("\nCommon fixes:")
        print("1. Ensure camera is connected to CSI port")
        print("2. Check camera ribbon cable orientation")
        print("3. Reboot Jetson: sudo reboot")
    print("=" * 60)

    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())
