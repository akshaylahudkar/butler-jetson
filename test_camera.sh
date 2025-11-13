#!/bin/bash
#
# IMX219 Camera Test Script
# Quick camera detection and functionality test
#

set -e

echo "=========================================="
echo "IMX219 Camera Test"
echo "=========================================="
echo ""

# Check if running on Jetson
if [ -f /etc/nv_tegra_release ]; then
    echo "✅ Running on Jetson platform"
    cat /etc/nv_tegra_release
else
    echo "⚠️  Not running on Jetson (tests may fail)"
fi

echo ""
echo "Running Python camera tests..."
echo ""

python3 camera_test.py

echo ""
echo "=========================================="
echo "Test complete!"
echo "=========================================="
