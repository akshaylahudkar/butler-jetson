#!/bin/bash
#
# Run VILA Vision Stream with IMX219 Camera
# Full vision processing with VILA VLM
#

set -e

echo "=========================================="
echo "VILA Vision Stream for IMX219"
echo "=========================================="
echo ""

# Check if we need to use jetson-containers
JETSON_CONTAINERS_DIR="${JETSON_CONTAINERS_DIR:-$HOME/jetson-containers}"

if [ ! -d "$JETSON_CONTAINERS_DIR" ]; then
    echo "⚠️  jetson-containers not found at: $JETSON_CONTAINERS_DIR"
    echo ""
    echo "To install jetson-containers:"
    echo "  cd ~"
    echo "  git clone https://github.com/dusty-nv/jetson-containers"
    echo "  cd jetson-containers"
    echo "  pip3 install -r requirements.txt"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Default parameters
DEVICE="${CAMERA_DEVICE:-/dev/video0}"
WIDTH="${CAMERA_WIDTH:-640}"
HEIGHT="${CAMERA_HEIGHT:-480}"
INTERVAL="${UPDATE_INTERVAL:-2.0}"
MODEL="${VILA_MODEL:-VILA-1.5-3B}"
PROMPT="${VILA_PROMPT:-What do you see? Describe in one sentence.}"

# Parse arguments
USE_CONTAINER=true

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
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --prompt)
            PROMPT="$2"
            shift 2
            ;;
        --mock)
            USE_CONTAINER=false
            MOCK_FLAG="--mock"
            shift
            ;;
        --no-container)
            USE_CONTAINER=false
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --device PATH       Camera device (default: /dev/video0)"
            echo "  --width NUM         Frame width (default: 640)"
            echo "  --height NUM        Frame height (default: 480)"
            echo "  --interval SEC      Update interval (default: 2.0)"
            echo "  --model NAME        VILA model (default: VILA-1.5-3B)"
            echo "  --prompt TEXT       Vision prompt"
            echo "  --mock              Use mock mode (no VILA)"
            echo "  --no-container      Run without container"
            echo "  --help              Show this help"
            echo ""
            echo "Environment variables:"
            echo "  JETSON_CONTAINERS_DIR  Path to jetson-containers"
            echo "  CAMERA_DEVICE          Camera device path"
            echo "  VILA_MODEL             VILA model name"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Get absolute path to vision_stream.py
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VISION_SCRIPT="$SCRIPT_DIR/vision_stream.py"
CAMERA_SCRIPT="$SCRIPT_DIR/camera_stream.py"

if [ ! -f "$VISION_SCRIPT" ]; then
    echo "❌ Error: vision_stream.py not found at: $VISION_SCRIPT"
    exit 1
fi

# Build command
if [ "$USE_CONTAINER" = true ]; then
    echo "🐳 Running in jetson-containers..."
    echo ""

    cd "$JETSON_CONTAINERS_DIR"

    # Build container command
    CONTAINER_CMD="./run.sh --volume $DEVICE:$DEVICE --volume $SCRIPT_DIR:/workspace"
    CONTAINER_CMD="$CONTAINER_CMD \$(./autotag nano_llm)"
    CONTAINER_CMD="$CONTAINER_CMD python3 /workspace/vision_stream.py"
    CONTAINER_CMD="$CONTAINER_CMD --device $DEVICE --width $WIDTH --height $HEIGHT"
    CONTAINER_CMD="$CONTAINER_CMD --interval $INTERVAL --model $MODEL"
    CONTAINER_CMD="$CONTAINER_CMD --prompt \"$PROMPT\""

    echo "Command: $CONTAINER_CMD"
    echo ""
    echo "First run will download ~5-10GB (be patient!)"
    echo ""

    eval $CONTAINER_CMD

else
    echo "🔧 Running in mock mode (no container)..."
    echo ""

    cd "$SCRIPT_DIR"

    CMD="python3 vision_stream.py --device $DEVICE --width $WIDTH --height $HEIGHT"
    CMD="$CMD --interval $INTERVAL ${MOCK_FLAG:-}"

    echo "Command: $CMD"
    echo ""

    exec $CMD
fi
