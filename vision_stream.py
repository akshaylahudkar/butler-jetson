#!/usr/bin/env python3
"""
VILA Vision Stream for Jetson Orin Nano with IMX219 Camera
Processes video stream with VILA VLM for real-time scene understanding
"""

import sys
import time
import argparse
from typing import Optional
from camera_stream import IMX219Camera

# Check for NanoLLM availability
try:
    from nano_llm import NanoLLM
    from nano_llm.vision import VideoSource
    NANOLLM_AVAILABLE = True
except ImportError:
    NANOLLM_AVAILABLE = False
    print("⚠️  nano_llm not available. Install jetson-containers to use VILA.")


class VisionStream:
    """
    Real-time vision processing with VILA VLM
    """

    def __init__(
        self,
        model_name: str = "VILA-1.5-3B",
        camera_device: str = "/dev/video0",
        width: int = 640,
        height: int = 480,
        update_interval: float = 2.0,
        use_gstreamer: bool = True
    ):
        """
        Initialize vision stream

        Args:
            model_name: VILA model to use
            camera_device: Camera device path
            width: Frame width
            height: Frame height
            update_interval: Seconds between vision queries
            use_gstreamer: Use GStreamer for hardware acceleration
        """
        self.model_name = model_name
        self.camera_device = camera_device
        self.width = width
        self.height = height
        self.update_interval = update_interval
        self.use_gstreamer = use_gstreamer

        self.model = None
        self.camera = None
        self.last_response = ""
        self.frame_count = 0

    def load_model(self) -> bool:
        """Load VILA model"""
        if not NANOLLM_AVAILABLE:
            print("❌ NanoLLM not available. Cannot load model.")
            print("\nTo use VILA, run this script inside jetson-containers:")
            print("cd ~/jetson-containers")
            print("./run.sh --volume /dev/video0:/dev/video0 $(./autotag nano_llm) \\")
            print("  python3 vision_stream.py")
            return False

        print(f"Loading VILA model: {self.model_name}")
        print("This may take a few minutes on first run...")

        try:
            self.model = NanoLLM.from_pretrained(
                self.model_name,
                api='mlc',
                quantization='q4f16_ft'
            )
            print("✅ Model loaded successfully")
            return True

        except Exception as e:
            print(f"❌ Failed to load model: {e}")
            return False

    def open_camera(self) -> bool:
        """Open camera connection"""
        print(f"\nOpening camera: {self.camera_device}")

        self.camera = IMX219Camera(
            device=self.camera_device,
            width=self.width,
            height=self.height,
            framerate=30,
            use_gstreamer=self.use_gstreamer
        )

        return self.camera.open()

    def query_vision(self, frame, prompt: str) -> str:
        """
        Query VILA about the current frame

        Args:
            frame: Image frame (numpy array)
            prompt: Question to ask VILA

        Returns:
            VILA's response
        """
        if self.model is None:
            return "Model not loaded"

        try:
            response = self.model.generate(
                prompt,
                image=frame,
                streaming=False,
                max_tokens=100
            )
            return response

        except Exception as e:
            return f"Error: {e}"

    def run(self, prompt: str = "What do you see? Describe in one sentence."):
        """
        Run continuous vision stream

        Args:
            prompt: Default prompt for VILA
        """
        print("\n" + "=" * 60)
        print("VILA Vision Stream Active")
        print("=" * 60)
        print(f"Prompt: {prompt}")
        print(f"Update interval: {self.update_interval}s")
        print("\nPress Ctrl+C to stop\n")

        last_query_time = 0

        try:
            while True:
                # Read frame
                ret, frame = self.camera.read()

                if not ret:
                    print("Failed to read frame")
                    time.sleep(0.1)
                    continue

                self.frame_count += 1
                current_time = time.time()

                # Check if it's time for a new vision query
                if current_time - last_query_time >= self.update_interval:
                    print(f"\n[Frame {self.frame_count}] Processing...")

                    # Query VILA
                    response = self.query_vision(frame, prompt)
                    self.last_response = response

                    # Display response
                    print("=" * 60)
                    print(f"🤖 VILA: {response}")
                    print("=" * 60)

                    last_query_time = current_time

                # Small delay to prevent CPU spinning
                time.sleep(0.03)  # ~30 FPS max

        except KeyboardInterrupt:
            print("\n\n⚠️  Stopped by user")

        finally:
            self.cleanup()

    def cleanup(self):
        """Clean up resources"""
        if self.camera:
            self.camera.close()

        print("\n✅ Vision stream closed")

    def __enter__(self):
        """Context manager entry"""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.cleanup()


class MockVisionStream:
    """
    Mock vision stream for testing without VILA
    Simulates vision processing with simple frame analysis
    """

    def __init__(
        self,
        camera_device: str = "/dev/video0",
        width: int = 640,
        height: int = 480,
        update_interval: float = 2.0
    ):
        self.camera_device = camera_device
        self.width = width
        self.height = height
        self.update_interval = update_interval
        self.camera = None
        self.frame_count = 0

    def open_camera(self) -> bool:
        """Open camera connection"""
        print(f"Opening camera: {self.camera_device}")

        self.camera = IMX219Camera(
            device=self.camera_device,
            width=self.width,
            height=self.height,
            framerate=30,
            use_gstreamer=False  # Use V4L2 for simplicity in mock mode
        )

        return self.camera.open()

    def analyze_frame(self, frame) -> str:
        """Simple frame analysis without ML"""
        import cv2
        import numpy as np

        # Calculate brightness
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        brightness = np.mean(gray)

        # Detect motion (simple edge detection)
        edges = cv2.Canny(gray, 50, 150)
        edge_density = np.sum(edges > 0) / edges.size

        # Simple scene description
        if brightness < 50:
            light = "dark"
        elif brightness < 150:
            light = "moderately lit"
        else:
            light = "bright"

        if edge_density < 0.1:
            complexity = "simple scene with few details"
        elif edge_density < 0.3:
            complexity = "moderate complexity"
        else:
            complexity = "complex scene with many details"

        return f"I see a {light} scene with {complexity}."

    def run(self, prompt: str = "Analyzing scene..."):
        """Run mock vision stream"""
        print("\n" + "=" * 60)
        print("Mock Vision Stream Active (No VILA)")
        print("=" * 60)
        print("Using simple image analysis for demonstration")
        print(f"Update interval: {self.update_interval}s")
        print("\nPress Ctrl+C to stop\n")

        last_analysis_time = 0

        try:
            while True:
                ret, frame = self.camera.read()

                if not ret:
                    print("Failed to read frame")
                    time.sleep(0.1)
                    continue

                self.frame_count += 1
                current_time = time.time()

                if current_time - last_analysis_time >= self.update_interval:
                    print(f"\n[Frame {self.frame_count}] Analyzing...")

                    # Simple analysis
                    description = self.analyze_frame(frame)

                    print("=" * 60)
                    print(f"📷 Analysis: {description}")
                    print("=" * 60)

                    last_analysis_time = current_time

                time.sleep(0.03)

        except KeyboardInterrupt:
            print("\n\n⚠️  Stopped by user")

        finally:
            if self.camera:
                self.camera.close()


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="VILA Vision Stream for IMX219 Camera"
    )
    parser.add_argument(
        '--model',
        default='VILA-1.5-3B',
        help='VILA model to use (default: VILA-1.5-3B)'
    )
    parser.add_argument(
        '--device',
        default='/dev/video0',
        help='Camera device path (default: /dev/video0)'
    )
    parser.add_argument(
        '--width',
        type=int,
        default=640,
        help='Frame width (default: 640)'
    )
    parser.add_argument(
        '--height',
        type=int,
        default=480,
        help='Frame height (default: 480)'
    )
    parser.add_argument(
        '--interval',
        type=float,
        default=2.0,
        help='Seconds between vision queries (default: 2.0)'
    )
    parser.add_argument(
        '--prompt',
        default='What do you see? Describe in one sentence.',
        help='Prompt for VILA'
    )
    parser.add_argument(
        '--mock',
        action='store_true',
        help='Use mock mode without VILA'
    )
    parser.add_argument(
        '--no-gstreamer',
        action='store_true',
        help='Disable GStreamer hardware acceleration'
    )

    args = parser.parse_args()

    print("=" * 60)
    print("VILA Vision Stream for Jetson Orin Nano")
    print("=" * 60)

    # Check if we should use mock mode
    use_mock = args.mock or not NANOLLM_AVAILABLE

    if use_mock:
        print("\n🔧 Running in MOCK mode (no VILA)")
        stream = MockVisionStream(
            camera_device=args.device,
            width=args.width,
            height=args.height,
            update_interval=args.interval
        )

        if not stream.open_camera():
            print("Failed to open camera")
            return 1

        stream.run(args.prompt)

    else:
        print("\n🤖 Running with VILA VLM")
        stream = VisionStream(
            model_name=args.model,
            camera_device=args.device,
            width=args.width,
            height=args.height,
            update_interval=args.interval,
            use_gstreamer=not args.no_gstreamer
        )

        # Load model
        if not stream.load_model():
            print("\n⚠️  Failed to load VILA. Try mock mode with --mock")
            return 1

        # Open camera
        if not stream.open_camera():
            print("Failed to open camera")
            return 1

        # Run stream
        stream.run(args.prompt)

    return 0


if __name__ == "__main__":
    sys.exit(main())
