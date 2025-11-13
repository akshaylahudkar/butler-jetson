#!/usr/bin/env python3
"""
IMX219 Camera Stream Handler for Jetson Orin Nano
Provides optimized video capture with GStreamer hardware acceleration
"""

import cv2
import numpy as np
import time
import argparse
from typing import Optional, Tuple

class IMX219Camera:
    """
    IMX219 Camera handler optimized for Jetson Orin Nano
    Supports both V4L2 and GStreamer backends
    """

    def __init__(
        self,
        device: str = "/dev/video0",
        width: int = 1280,
        height: int = 720,
        framerate: int = 30,
        use_gstreamer: bool = True
    ):
        """
        Initialize IMX219 camera

        Args:
            device: Camera device path (default: /dev/video0)
            width: Frame width in pixels
            height: Frame height in pixels
            framerate: Frames per second
            use_gstreamer: Use GStreamer pipeline for hardware acceleration
        """
        self.device = device
        self.width = width
        self.height = height
        self.framerate = framerate
        self.use_gstreamer = use_gstreamer
        self.cap = None
        self.frame_count = 0
        self.start_time = None

    def _build_gstreamer_pipeline(self) -> str:
        """Build optimized GStreamer pipeline for IMX219 on Jetson"""
        pipeline = (
            f"nvarguscamerasrc sensor-id=0 ! "
            f"video/x-raw(memory:NVMM), "
            f"width={self.width}, height={self.height}, "
            f"format=NV12, framerate={self.framerate}/1 ! "
            f"nvvidconv ! "
            f"video/x-raw, width={self.width}, height={self.height}, format=BGRx ! "
            f"videoconvert ! "
            f"video/x-raw, format=BGR ! "
            f"appsink max-buffers=1 drop=true sync=false"
        )
        return pipeline

    def open(self) -> bool:
        """
        Open camera connection

        Returns:
            True if successful, False otherwise
        """
        print(f"Opening camera: {self.device}")
        print(f"Resolution: {self.width}x{self.height} @ {self.framerate}fps")

        try:
            if self.use_gstreamer:
                pipeline = self._build_gstreamer_pipeline()
                print(f"Using GStreamer pipeline (hardware accelerated)")
                self.cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER)
            else:
                print(f"Using V4L2 backend")
                self.cap = cv2.VideoCapture(self.device, cv2.CAP_V4L2)
                self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
                self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
                self.cap.set(cv2.CAP_PROP_FPS, self.framerate)

            if not self.cap.isOpened():
                print("❌ Failed to open camera")
                return False

            # Test frame capture
            ret, frame = self.cap.read()
            if not ret:
                print("❌ Failed to capture test frame")
                self.close()
                return False

            print(f"✅ Camera opened successfully")
            print(f"   Actual resolution: {frame.shape[1]}x{frame.shape[0]}")

            self.start_time = time.time()
            return True

        except Exception as e:
            print(f"❌ Error opening camera: {e}")
            return False

    def read(self) -> Tuple[bool, Optional[np.ndarray]]:
        """
        Read a frame from the camera

        Returns:
            Tuple of (success, frame)
        """
        if self.cap is None:
            return False, None

        ret, frame = self.cap.read()

        if ret:
            self.frame_count += 1

        return ret, frame

    def get_fps(self) -> float:
        """
        Calculate current FPS

        Returns:
            Current frames per second
        """
        if self.start_time is None or self.frame_count == 0:
            return 0.0

        elapsed = time.time() - self.start_time
        return self.frame_count / elapsed if elapsed > 0 else 0.0

    def close(self):
        """Release camera resources"""
        if self.cap is not None:
            self.cap.release()
            self.cap = None
        print("Camera closed")

    def __enter__(self):
        """Context manager entry"""
        self.open()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()


def main():
    """Test camera stream with live preview"""
    parser = argparse.ArgumentParser(description="IMX219 Camera Stream Test")
    parser.add_argument('--device', default='/dev/video0', help='Camera device path')
    parser.add_argument('--width', type=int, default=1280, help='Frame width')
    parser.add_argument('--height', type=int, default=720, help='Frame height')
    parser.add_argument('--fps', type=int, default=30, help='Frame rate')
    parser.add_argument('--no-gstreamer', action='store_true', help='Disable GStreamer')
    parser.add_argument('--no-display', action='store_true', help='Disable display window')
    parser.add_argument('--duration', type=int, default=0, help='Run duration in seconds (0=infinite)')
    args = parser.parse_args()

    print("=" * 60)
    print("IMX219 Camera Stream Test")
    print("=" * 60)

    # Create camera instance
    camera = IMX219Camera(
        device=args.device,
        width=args.width,
        height=args.height,
        framerate=args.fps,
        use_gstreamer=not args.no_gstreamer
    )

    # Open camera
    if not camera.open():
        print("Failed to open camera. Exiting.")
        return 1

    print("\n📹 Starting video stream...")
    print("Press 'q' to quit, 's' to save snapshot\n")

    start_time = time.time()
    snapshot_count = 0

    try:
        while True:
            # Read frame
            ret, frame = camera.read()

            if not ret:
                print("Failed to read frame")
                break

            # Add FPS overlay
            fps = camera.get_fps()
            cv2.putText(
                frame,
                f"FPS: {fps:.1f}",
                (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX,
                1,
                (0, 255, 0),
                2
            )

            # Display frame
            if not args.no_display:
                cv2.imshow('IMX219 Camera Stream', frame)

            # Handle keyboard input
            key = cv2.waitKey(1) & 0xFF

            if key == ord('q'):
                print("\nQuitting...")
                break
            elif key == ord('s'):
                snapshot_count += 1
                filename = f"snapshot_{snapshot_count:03d}.jpg"
                cv2.imwrite(filename, frame)
                print(f"📸 Saved: {filename}")

            # Check duration
            if args.duration > 0:
                if time.time() - start_time >= args.duration:
                    print(f"\n⏱️  Duration {args.duration}s reached. Stopping.")
                    break

            # Print status every 30 frames
            if camera.frame_count % 30 == 0:
                print(f"Frames: {camera.frame_count}, FPS: {fps:.2f}", end='\r')

    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")

    finally:
        camera.close()
        cv2.destroyAllWindows()

        # Print statistics
        print("\n" + "=" * 60)
        print("Stream Statistics")
        print("=" * 60)
        print(f"Total frames: {camera.frame_count}")
        print(f"Average FPS: {camera.get_fps():.2f}")
        print(f"Snapshots saved: {snapshot_count}")
        print("=" * 60)

    return 0


if __name__ == "__main__":
    exit(main())
