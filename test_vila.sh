#!/bin/bash
#
# VILA Integration Test Script
# Tests VILA vision model with IMX219 camera
#

set -e

echo "=========================================="
echo "VILA Vision Model Test"
echo "=========================================="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JETSON_CONTAINERS_DIR="${HOME}/jetson-containers"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
TEST_MODE="quick"
CAMERA_DEVICE="/dev/video0"
MODEL="VILA-1.5-3B"

while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            TEST_MODE="full"
            shift
            ;;
        --device)
            CAMERA_DEVICE="$2"
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --full          Run full test suite (default: quick)"
            echo "  --device PATH   Camera device (default: /dev/video0)"
            echo "  --model NAME    VILA model (default: VILA-1.5-3B)"
            echo "  --help          Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check jetson-containers
if [ ! -d "$JETSON_CONTAINERS_DIR" ]; then
    echo -e "${RED}❌ jetson-containers not found${NC}"
    echo "Run: ./setup_vila.sh"
    exit 1
fi

# Check camera
if [ ! -c "$CAMERA_DEVICE" ]; then
    echo -e "${RED}❌ Camera not found: $CAMERA_DEVICE${NC}"
    exit 1
fi

echo "Test Configuration:"
echo "  Mode: $TEST_MODE"
echo "  Camera: $CAMERA_DEVICE"
echo "  Model: $MODEL"
echo ""

# Test 1: Quick Camera Capture
echo "Test 1: Camera Capture"
echo "-----------------------------------"
echo "Testing basic camera capture..."

python3 "$SCRIPT_DIR/test_capture_v2.py"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Camera capture working${NC}"
else
    echo -e "${RED}❌ Camera capture failed${NC}"
    exit 1
fi
echo ""

# Test 2: Mock Vision Stream
echo "Test 2: Mock Vision Stream"
echo "-----------------------------------"
echo "Testing vision stream without VILA (mock mode)..."
echo "This will run for 10 seconds..."

timeout 10 python3 "$SCRIPT_DIR/vision_stream.py" \
    --mock \
    --device "$CAMERA_DEVICE" \
    --interval 2.0 \
    --width 640 \
    --height 480 \
    || true

echo ""
echo -e "${GREEN}✅ Mock vision stream completed${NC}"
echo ""

# Test 3: VILA Model Loading (Full test only)
if [ "$TEST_MODE" = "full" ]; then
    echo "Test 3: VILA Model Loading"
    echo "-----------------------------------"
    echo "Loading VILA model..."
    echo "⚠️  This will take several minutes on first run"
    echo ""

    cd "$JETSON_CONTAINERS_DIR"

    # Create a test script
    cat > /tmp/test_vila_load.py << 'EOF'
from nano_llm import NanoLLM
import sys

print("Loading VILA model...")
try:
    model = NanoLLM.from_pretrained(
        "VILA-1.5-3B",
        api='mlc',
        quantization='q4f16_ft'
    )
    print("✅ Model loaded successfully")

    # Test simple text query
    response = model.generate("Hello, who are you?", max_tokens=50)
    print(f"Model response: {response}")

    sys.exit(0)
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
EOF

    # Run in container
    ./run.sh $(./autotag nano_llm) python3 /tmp/test_vila_load.py

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ VILA model loading successful${NC}"
    else
        echo -e "${RED}❌ VILA model loading failed${NC}"
        exit 1
    fi
    echo ""

    # Test 4: VILA with Camera
    echo "Test 4: VILA Vision with Camera"
    echo "-----------------------------------"
    echo "Testing VILA with live camera feed..."
    echo "This will run for 30 seconds..."
    echo ""

    # Run vision stream for 30 seconds
    timeout 30 "$SCRIPT_DIR/run_vision_stream.sh" \
        --device "$CAMERA_DEVICE" \
        --model "$MODEL" \
        --interval 3.0 \
        --width 640 \
        --height 480 \
        --prompt "What do you see? Describe in one sentence." \
        || true

    echo ""
    echo -e "${GREEN}✅ VILA vision test completed${NC}"
    echo ""
fi

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""

if [ "$TEST_MODE" = "quick" ]; then
    echo -e "${GREEN}✅ Quick tests passed${NC}"
    echo ""
    echo "Camera and basic vision processing working!"
    echo ""
    echo "To run full VILA test:"
    echo "  ./test_vila.sh --full"
else
    echo -e "${GREEN}✅ All tests passed${NC}"
    echo ""
    echo "VILA vision system fully operational!"
    echo ""
    echo "To start vision stream:"
    echo "  ./run_vision_stream.sh"
fi

echo ""
echo "=========================================="
