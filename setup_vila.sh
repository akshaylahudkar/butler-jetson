#!/bin/bash
#
# VILA Setup Script for Jetson Orin Nano
# Installs jetson-containers and prepares for VILA vision model
#

set -e

echo "=========================================="
echo "VILA Setup for Jetson Orin Nano"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on Jetson
if [ ! -f /etc/nv_tegra_release ]; then
    echo -e "${RED}⚠️  Warning: Not running on Jetson platform${NC}"
    echo "This script should be run on the Jetson Orin Nano"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Step 1: Checking prerequisites..."
echo "-----------------------------------"

# Check disk space
AVAILABLE_GB=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
echo "Available disk space: ${AVAILABLE_GB}GB"

if [ "$AVAILABLE_GB" -lt 50 ]; then
    echo -e "${RED}❌ Insufficient disk space${NC}"
    echo "You need at least 50GB free. Have: ${AVAILABLE_GB}GB"
    echo ""
    echo "To free up space:"
    echo "  sudo apt clean"
    echo "  docker system prune -a"
    exit 1
fi

echo -e "${GREEN}✅ Sufficient disk space${NC}"

# Check memory
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
echo "Total RAM: ${TOTAL_MEM}GB"

if [ "$TOTAL_MEM" -lt 7 ]; then
    echo -e "${YELLOW}⚠️  Low RAM detected (${TOTAL_MEM}GB)${NC}"
    echo "Checking swap..."

    SWAP=$(free -g | awk '/^Swap:/{print $2}')
    if [ "$SWAP" -lt 8 ]; then
        echo -e "${YELLOW}⚠️  Recommend increasing swap to 8GB${NC}"
        read -p "Create 8GB swap file? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Creating swap file..."
            sudo systemctl disable nvzramconfig || true
            sudo fallocate -l 8G /swapfile
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile
            echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
            echo -e "${GREEN}✅ Swap created${NC}"
        fi
    else
        echo -e "${GREEN}✅ Swap already configured (${SWAP}GB)${NC}"
    fi
fi

# Check Docker
echo ""
echo "Step 2: Checking Docker..."
echo "-----------------------------------"

if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}⚠️  Docker not found${NC}"
    read -p "Install Docker? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing Docker..."
        sudo apt update
        sudo apt install -y docker.io
        sudo systemctl enable docker
        sudo systemctl start docker
        echo -e "${GREEN}✅ Docker installed${NC}"
    else
        echo -e "${RED}❌ Docker is required. Exiting.${NC}"
        exit 1
    fi
fi

# Check Docker permissions
if ! docker ps &> /dev/null; then
    echo -e "${YELLOW}⚠️  Docker permissions issue${NC}"
    echo "Adding user to docker group..."
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}⚠️  Please log out and log back in for group changes to take effect${NC}"
    echo "Then run this script again."
    exit 1
fi

echo -e "${GREEN}✅ Docker ready${NC}"

# Check jetson-containers
echo ""
echo "Step 3: Installing jetson-containers..."
echo "-----------------------------------"

JETSON_CONTAINERS_DIR="${HOME}/jetson-containers"

if [ -d "$JETSON_CONTAINERS_DIR" ]; then
    echo "jetson-containers already exists"
    read -p "Update to latest version? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$JETSON_CONTAINERS_DIR"
        git pull
        echo -e "${GREEN}✅ Updated jetson-containers${NC}"
    fi
else
    echo "Cloning jetson-containers..."
    cd ~
    git clone https://github.com/dusty-nv/jetson-containers
    echo -e "${GREEN}✅ Cloned jetson-containers${NC}"
fi

# Install Python dependencies
echo ""
echo "Installing Python dependencies..."
cd "$JETSON_CONTAINERS_DIR"

if [ -f requirements.txt ]; then
    pip3 install -r requirements.txt
    echo -e "${GREEN}✅ Python dependencies installed${NC}"
fi

# Test jetson-containers
echo ""
echo "Testing jetson-containers..."
if ./run.sh --help &> /dev/null; then
    echo -e "${GREEN}✅ jetson-containers working${NC}"
else
    echo -e "${RED}❌ jetson-containers test failed${NC}"
    exit 1
fi

# Set performance mode
echo ""
echo "Step 4: Setting performance mode..."
echo "-----------------------------------"

if command -v nvpmodel &> /dev/null; then
    echo "Setting to max performance mode..."
    sudo nvpmodel -m 0
    sudo jetson_clocks
    echo -e "${GREEN}✅ Performance mode enabled${NC}"
else
    echo -e "${YELLOW}⚠️  nvpmodel not found (not on Jetson?)${NC}"
fi

# Test camera
echo ""
echo "Step 5: Testing camera..."
echo "-----------------------------------"

if [ -c /dev/video0 ]; then
    echo -e "${GREEN}✅ Camera device found: /dev/video0${NC}"

    # Quick camera test
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/test_capture_v2.py" ]; then
        echo "Running quick camera test..."
        python3 "$SCRIPT_DIR/test_capture_v2.py"
    fi
else
    echo -e "${RED}❌ Camera not found at /dev/video0${NC}"
    echo "Please check camera connection"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ VILA Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Test VILA vision stream:"
echo "   cd $(pwd)"
echo "   ./run_vision_stream.sh"
echo ""
echo "2. First run will download ~5-10GB (be patient!)"
echo ""
echo "3. Monitor resources with: sudo jtop"
echo ""
echo "=========================================="
