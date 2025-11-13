#!/bin/bash
#
# Pre-flight Check for VILA Vision System
# Validates all requirements before running VILA
#

echo "=========================================="
echo "VILA Vision System - Pre-flight Check"
echo "=========================================="
echo ""

# Track issues
ISSUES=0
WARNINGS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((ISSUES++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARNINGS++))
}

# 1. Platform Check
echo "1. Platform Check"
echo "-----------------------------------"
if [ -f /etc/nv_tegra_release ]; then
    JETPACK_VERSION=$(cat /etc/nv_tegra_release | grep -oP 'R\d+\.\d+')
    check_pass "Jetson platform detected: $JETPACK_VERSION"
else
    check_warn "Not running on Jetson (tests may be limited)"
fi
echo ""

# 2. Camera Check
echo "2. Camera Check"
echo "-----------------------------------"
if [ -c /dev/video0 ]; then
    check_pass "Camera device found: /dev/video0"

    # Check camera permissions
    if [ -r /dev/video0 ] && [ -w /dev/video0 ]; then
        check_pass "Camera permissions OK"
    else
        check_fail "Camera permissions issue"
        echo "   Fix: sudo usermod -a -G video $USER && newgrp video"
    fi

    # Check if camera is busy
    if fuser /dev/video0 2>/dev/null; then
        USING_PID=$(fuser /dev/video0 2>/dev/null)
        check_warn "Camera in use by process: $USING_PID"
        echo "   Fix: fuser -k /dev/video0 (to kill process)"
    else
        check_pass "Camera available (not in use)"
    fi
else
    check_fail "Camera not found at /dev/video0"
    echo "   Fix: Check physical connection and restart"
fi
echo ""

# 3. Docker Check
echo "3. Docker Check"
echo "-----------------------------------"
if command -v docker &> /dev/null; then
    check_pass "Docker installed: $(docker --version | cut -d' ' -f3 | tr -d ',')"

    # Check Docker daemon
    if docker ps &> /dev/null; then
        check_pass "Docker daemon running"

        # Check Docker permissions
        if groups | grep -q docker; then
            check_pass "User in docker group"
        else
            check_fail "User not in docker group"
            echo "   Fix: sudo usermod -aG docker $USER && newgrp docker"
        fi
    else
        check_fail "Docker daemon not accessible"
        echo "   Fix: sudo systemctl start docker"
    fi
else
    check_fail "Docker not installed"
    echo "   Fix: sudo apt install docker.io"
fi
echo ""

# 4. jetson-containers Check
echo "4. jetson-containers Check"
echo "-----------------------------------"
JETSON_CONTAINERS_DIR="${HOME}/jetson-containers"
if [ -d "$JETSON_CONTAINERS_DIR" ]; then
    check_pass "jetson-containers found: $JETSON_CONTAINERS_DIR"

    if [ -f "$JETSON_CONTAINERS_DIR/run.sh" ]; then
        check_pass "run.sh script present"
    else
        check_fail "run.sh script missing"
    fi
else
    check_fail "jetson-containers not found"
    echo "   Fix: Run ./setup_vila.sh"
fi
echo ""

# 5. Disk Space Check
echo "5. Disk Space Check"
echo "-----------------------------------"
AVAILABLE_GB=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
echo "Available: ${AVAILABLE_GB}GB"

if [ "$AVAILABLE_GB" -ge 50 ]; then
    check_pass "Sufficient disk space (${AVAILABLE_GB}GB)"
elif [ "$AVAILABLE_GB" -ge 30 ]; then
    check_warn "Low disk space (${AVAILABLE_GB}GB, recommend 50GB+)"
else
    check_fail "Insufficient disk space (${AVAILABLE_GB}GB, need 50GB+)"
    echo "   Fix: Free up space or use external storage"
fi
echo ""

# 6. Memory Check
echo "6. Memory Check"
echo "-----------------------------------"
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
SWAP=$(free -g | awk '/^Swap:/{print $2}')

echo "RAM: ${TOTAL_MEM}GB, Swap: ${SWAP}GB"

if [ "$TOTAL_MEM" -ge 8 ]; then
    check_pass "Sufficient RAM (${TOTAL_MEM}GB)"
elif [ "$SWAP" -ge 8 ]; then
    check_pass "RAM + Swap OK (${TOTAL_MEM}GB + ${SWAP}GB swap)"
else
    check_warn "Low memory (${TOTAL_MEM}GB RAM, ${SWAP}GB swap)"
    echo "   Recommend: 8GB swap for model loading"
    echo "   Fix: Run ./setup_vila.sh to create swap"
fi
echo ""

# 7. Python Dependencies Check
echo "7. Python Dependencies Check"
echo "-----------------------------------"
python3 -c "import cv2; print(f'OpenCV: {cv2.__version__}')" 2>/dev/null && check_pass "OpenCV installed" || check_fail "OpenCV missing"

python3 -c "import numpy; print(f'NumPy: {numpy.__version__}')" 2>/dev/null && check_pass "NumPy installed" || check_fail "NumPy missing"

# Check OpenCV GStreamer support
if python3 -c "import cv2; import sys; sys.exit(0 if 'GStreamer: YES' in cv2.getBuildInformation() else 1)" 2>/dev/null; then
    check_pass "OpenCV has GStreamer support"
else
    check_warn "OpenCV may lack GStreamer support"
    echo "   This may cause camera issues with IMX219"
fi
echo ""

# 8. Performance Mode Check
echo "8. Performance Mode Check"
echo "-----------------------------------"
if command -v nvpmodel &> /dev/null; then
    CURRENT_MODE=$(sudo nvpmodel -q 2>/dev/null | grep "NV Power Mode" | cut -d':' -f2 | xargs)
    echo "Current mode: $CURRENT_MODE"

    if [[ "$CURRENT_MODE" == *"MAXN"* ]] || [[ "$CURRENT_MODE" == *"0"* ]]; then
        check_pass "Max performance mode enabled"
    else
        check_warn "Not in max performance mode"
        echo "   Fix: sudo nvpmodel -m 0 && sudo jetson_clocks"
    fi
else
    check_warn "nvpmodel not found (not on Jetson?)"
fi
echo ""

# 9. Network Check
echo "9. Network Check"
echo "-----------------------------------"
if ping -c 1 google.com &> /dev/null; then
    check_pass "Internet connection OK"
else
    check_warn "No internet connection"
    echo "   Required for first-time model download"
fi
echo ""

# 10. Script Files Check
echo "10. Project Files Check"
echo "-----------------------------------"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for file in camera_test.py camera_stream.py vision_stream.py run_vision_stream.sh; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        check_pass "$file present"
    else
        check_fail "$file missing"
    fi
done
echo ""

# Summary
echo "=========================================="
echo "Pre-flight Check Summary"
echo "=========================================="
echo ""

if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}🎉 All checks passed! Ready to run VILA.${NC}"
    echo ""
    echo "Next step:"
    echo "  ./run_vision_stream.sh"
    exit 0
elif [ $ISSUES -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found, but OK to proceed${NC}"
    echo ""
    echo "You can continue with:"
    echo "  ./run_vision_stream.sh"
    exit 0
else
    echo -e "${RED}❌ $ISSUES critical issue(s) found${NC}"
    echo -e "${YELLOW}⚠️  $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please fix the issues above before proceeding."
    echo ""
    echo "Run this to fix most issues:"
    echo "  ./setup_vila.sh"
    exit 1
fi
