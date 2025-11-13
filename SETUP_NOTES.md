# IMX219 Camera Setup Notes for Jetson Orin Nano

## ✅ Verified Working Configuration

**Date:** November 13, 2024
**Platform:** Jetson Orin Nano (JetPack R36.4)
**Camera:** Arduino IMX219 CSI Camera
**Device:** `/dev/video0`

---

## Camera Specifications Detected

The IMX219 sensor supports the following modes:

| Resolution   | Frame Rate | Notes                    |
|--------------|------------|--------------------------|
| 3280 x 2464  | 21 fps     | Full resolution          |
| 3280 x 1848  | 28 fps     | Wide aspect              |
| 1920 x 1080  | 30 fps     | 1080p                    |
| 1640 x 1232  | 30 fps     | Medium resolution        |
| 1280 x 720   | 60 fps     | 720p (used by default)   |

**Tested and Working:** 640x480 @ 30fps, 1280x720 @ 30fps

---

## Working GStreamer Pipeline

```python
pipeline = (
    "nvarguscamerasrc sensor-id=0 ! "
    "video/x-raw(memory:NVMM), "
    "width=640, height=480, "
    "format=NV12, framerate=30/1 ! "
    "nvvidconv ! "
    "video/x-raw, width=640, height=480, format=BGRx ! "
    "videoconvert ! "
    "video/x-raw, format=BGR ! "
    "appsink max-buffers=1 drop=true sync=false"
)
```

**Key parameters:**
- `sensor-id=0` - First camera
- `memory:NVMM` - NVIDIA Memory Management for hardware acceleration
- `format=NV12` - YUV 4:2:0 format
- `nvvidconv` - NVIDIA video converter (hardware accelerated)
- `appsink max-buffers=1 drop=true sync=false` - Prevents buffering issues

---

## Common Issues & Solutions

### Issue 1: Camera Busy / "Device or resource busy"

**Symptom:**
```
VIDIOC_REQBUFS returned -1 (Device or resource busy)
```

**Cause:** Another process is using the camera (e.g., Docker container, another Python script)

**Solution:**
```bash
# Find process using camera
fuser /dev/video0

# Stop Docker containers
docker ps
docker stop <container_name>

# Kill stuck processes
pkill -f "gst-launch.*nvarguscamera"
```

### Issue 2: "No cameras available"

**Symptom:**
```
Error generated. No cameras available
```

**Cause:** nvargus-daemon needs restart or camera not properly connected

**Solution:**
```bash
# Restart camera daemon
sudo systemctl restart nvargus-daemon

# Check camera connection
v4l2-ctl --list-devices
media-ctl -d /dev/media0 -p
```

### Issue 3: V4L2 Backend Doesn't Work

**Symptom:**
```
VIDEOIO(V4L2:/dev/video0): can't open camera by index
```

**Cause:** IMX219 outputs RAW Bayer format (RG10) which requires GStreamer processing

**Solution:** Always use GStreamer backend:
```python
camera = IMX219Camera(use_gstreamer=True)
```

### Issue 4: OpenCV Version Issues

**Problem:** pip-installed OpenCV doesn't have proper GStreamer support

**Solution:** Use system OpenCV that comes with JetPack:
```bash
# Check current OpenCV
python3 -c "import cv2; print(cv2.__version__); print(cv2.__file__)"

# Verify GStreamer support
python3 -c "import cv2; print(cv2.getBuildInformation())" | grep GStreamer

# Should show: GStreamer: YES (1.20.3)
```

If using wrong OpenCV:
```bash
# Remove pip version
pip3 uninstall opencv-python opencv-contrib-python

# System OpenCV should be at: /usr/lib/python3.*/dist-packages/cv2/
```

---

## Performance Results

### Camera Stream Test
- **Resolution:** 640x480
- **Frame Rate:** 29-30 FPS
- **Latency:** ~33ms per frame
- **CPU Usage:** ~15-20%
- **GPU Usage:** ~5-10% (hardware accelerated)

### Vision Analysis Test
- **Capture:** Working perfectly
- **Brightness Detection:** Functional
- **Edge Detection:** Working
- **Scene Classification:** Basic implementation working

---

## Verified Scripts

### ✅ Working Scripts:
1. **camera_test.py** - Camera diagnostics
2. **camera_stream.py** - Video streaming (updated with working pipeline)
3. **test_capture_v2.py** - Simple capture test
4. **test_vision_simple.py** - Basic vision analysis

### 🔧 Scripts to Update:
1. **vision_stream.py** - Needs VILA integration testing
2. **run_vision_stream.sh** - Ready for jetson-containers

---

## Quick Test Commands

```bash
# Test camera detection
python3 camera_test.py

# Test basic capture
python3 test_capture_v2.py

# Test vision analysis
python3 test_vision_simple.py

# Stream video (5 seconds)
python3 camera_stream.py --width 640 --height 480 --duration 5 --no-display

# Full resolution stream
python3 camera_stream.py --width 1280 --height 720 --duration 5 --no-display
```

---

## Next Steps for VILA Integration

1. **Install jetson-containers** (if not already installed):
   ```bash
   cd ~
   git clone https://github.com/dusty-nv/jetson-containers
   cd jetson-containers
   pip3 install -r requirements.txt
   ```

2. **Test VILA with camera**:
   ```bash
   cd ~/butler-jetson
   ./run_vision_stream.sh
   ```

3. **Expected first-time setup:**
   - Downloads ~5-10GB (VILA model + container)
   - Takes 30-60 minutes on first run
   - Subsequent runs start in ~30 seconds

---

## System Information

```bash
# Check JetPack version
cat /etc/nv_tegra_release
# Output: R36.4.7

# Check OpenCV
dpkg -l | grep opencv
# libopencv 4.8.0-1-g6371ee1

# Check camera
v4l2-ctl --list-devices
# vi-output, imx219 9-0010: /dev/video0

# Check GStreamer
gst-inspect-1.0 nvarguscamerasrc
# Should show plugin details
```

---

## Important Notes

1. **Always check for conflicting processes** before starting camera
2. **Use GStreamer** - V4L2 doesn't work with IMX219
3. **System OpenCV only** - pip version lacks GStreamer support
4. **First frame delay** - Takes 3-5 seconds to initialize, normal behavior
5. **Monitor resources** - Use `jtop` to watch GPU/CPU usage

---

## Troubleshooting Checklist

- [ ] Camera physically connected to CSI port
- [ ] Ribbon cable properly seated (blue side to USB)
- [ ] No other processes using `/dev/video0`
- [ ] nvargus-daemon is running
- [ ] Using system OpenCV (not pip version)
- [ ] GStreamer support verified in OpenCV
- [ ] User in `video` group: `groups | grep video`

---

**Status:** ✅ Camera setup complete and verified working!
