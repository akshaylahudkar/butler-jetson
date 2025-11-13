#!/bin/bash
#
# Run IMX219 Camera Stream
# Basic camera streaming without vision model
#

set -e

echo "=========================================="
echo "Starting IMX219 Camera Stream"
echo "=========================================="
echo ""
echo "Controls:"
echo "  'q' - Quit"
echo "  's' - Save snapshot"
echo ""

# Default parameters
DEVICE="${CAMERA_DEVICE:-/dev/video0}"
WIDTH="${CAMERA_WIDTH:-1280}"
HEIGHT="${CAMERA_HEIGHT:-720}"
FPS="${CAMERA_FPS:-30}"

# Parse arguments
USE_GSTREAMER=true
DURATION=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --device)
            DEVICE="$2"
            shift 2
            ;;
        --width)
            WIDTH="$2"
            shift 2
            ;;
        --height)
            HEIGHT="$2"
            shift 2
            ;;
        --fps)
            FPS="$2"
            shift 2
            ;;
        --no-gstreamer)
            USE_GSTREAMER=false
            shift
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --device PATH       Camera device (default: /dev/video0)"
            echo "  --width NUM         Frame width (default: 1280)"
            echo "  --height NUM        Frame height (default: 720)"
            echo "  --fps NUM           Frame rate (default: 30)"
            echo "  --no-gstreamer      Disable GStreamer (use V4L2)"
            echo "  --duration SEC      Run for SEC seconds (0=infinite)"
            echo "  --help              Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Build command
CMD="python3 camera_stream.py --device $DEVICE --width $WIDTH --height $HEIGHT --fps $FPS"

if [ "$USE_GSTREAMER" = false ]; then
    CMD="$CMD --no-gstreamer"
fi

if [ "$DURATION" -gt 0 ]; then
    CMD="$CMD --duration $DURATION"
fi

echo "Running: $CMD"
echo ""

# Run camera stream
exec $CMD
