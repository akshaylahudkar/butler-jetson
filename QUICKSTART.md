# Quick Start Guide - Vision Setup for IMX219 Camera

Get your Jetson Orin Nano seeing with VILA VLM in 5 minutes!

## 🚀 Ultra Quick Start

### Step 1: Test Camera (1 minute)
```bash
./test_camera.sh
```

✅ If you see "All tests passed!" → Continue to Step 2
❌ If tests fail → Check camera connection and see [Troubleshooting](#troubleshooting)

### Step 2: Test Camera Stream (2 minutes)
```bash
./run_camera_stream.sh
```

You should see live video. Press 'q' to quit, 's' to save snapshot.

### Step 3: Run Vision Stream with VILA (2+ minutes first time)
```bash
./run_vision_stream.sh
```

**First run:** Downloads ~5-10GB (be patient!)
**After first run:** Starts in ~30 seconds

---

## 📁 What's Included

### Python Scripts

| File | Purpose |
|------|---------|
| `camera_test.py` | Camera detection & diagnostic tests |
| `camera_stream.py` | IMX219 camera handler with GStreamer support |
| `vision_stream.py` | VILA VLM integration for real-time vision |

### Shell Scripts

| File | Purpose |
|------|---------|
| `test_camera.sh` | Quick camera test |
| `run_camera_stream.sh` | Start camera stream |
| `run_vision_stream.sh` | Start VILA vision stream |

---

## 🎯 Usage Examples

### Basic Camera Test
```bash
# Test camera detection
python3 camera_test.py
```

### Camera Streaming
```bash
# Stream with default settings (1280x720 @ 30fps)
./run_camera_stream.sh

# Custom resolution
./run_camera_stream.sh --width 640 --height 480

# Run for 30 seconds
./run_camera_stream.sh --duration 30

# Use V4L2 instead of GStreamer
./run_camera_stream.sh --no-gstreamer
```

### Vision Processing with VILA

```bash
# Basic usage - describe what's seen
./run_vision_stream.sh

# Custom prompt
./run_vision_stream.sh --prompt "Are there any people in the scene?"

# Faster updates (every 1 second)
./run_vision_stream.sh --interval 1.0

# Lower resolution for speed
./run_vision_stream.sh --width 320 --height 240

# Mock mode (no VILA, just basic vision)
./run_vision_stream.sh --mock
```

---

## 🔧 Advanced Usage

### Custom VILA Prompts

```bash
# Object detection
./run_vision_stream.sh --prompt "List all objects you see, comma separated"

# Obstacle detection
./run_vision_stream.sh --prompt "Are there obstacles ahead? Reply yes or no."

# Person detection
./run_vision_stream.sh --prompt "Do you see a person? If yes, describe them."

# Scene description
./run_vision_stream.sh --prompt "Describe the scene in detail"
```

### Using Different Camera Devices

```bash
# If your camera is on /dev/video1
export CAMERA_DEVICE=/dev/video1
./run_vision_stream.sh

# Or pass directly
./run_vision_stream.sh --device /dev/video1
```

### Python API Usage

```python
from camera_stream import IMX219Camera
from vision_stream import VisionStream

# Option 1: Basic camera
camera = IMX219Camera(device="/dev/video0", width=640, height=480)
camera.open()
ret, frame = camera.read()
camera.close()

# Option 2: Vision stream (requires jetson-containers)
stream = VisionStream(
    model_name="VILA-1.5-3B",
    camera_device="/dev/video0",
    update_interval=2.0
)
stream.load_model()
stream.open_camera()
stream.run("What do you see?")
```

---

## 🏗️ Integration with Robot Code

### Example: Obstacle Detection

```python
from vision_stream import VisionStream
import time

# Initialize vision
vision = VisionStream(
    model_name="VILA-1.5-3B",
    camera_device="/dev/video0",
    update_interval=1.0  # Check every second
)

vision.load_model()
vision.open_camera()

# In your robot loop
while robot_is_running:
    ret, frame = vision.camera.read()

    # Ask about obstacles
    response = vision.query_vision(
        frame,
        "Are there any obstacles in front? Reply yes or no."
    )

    if "yes" in response.lower():
        print("⚠️  Obstacle detected!")
        robot.stop()
    else:
        robot.move_forward()

    time.sleep(1.0)
```

### Example: Person Following

```python
while True:
    ret, frame = vision.camera.read()

    response = vision.query_vision(
        frame,
        "Do you see a person? If yes, are they on the left, center, or right?"
    )

    if "left" in response.lower():
        robot.turn_left(10)
    elif "right" in response.lower():
        robot.turn_right(10)
    elif "center" in response.lower():
        robot.move_forward()
    else:
        robot.stop()
        robot.say("I don't see anyone to follow")

    time.sleep(0.5)
```

---

## 🐛 Troubleshooting

### Camera Not Found

**Symptoms:** `ls /dev/video*` shows nothing

**Fixes:**
1. Check physical connection (ribbon cable)
2. Check cable orientation (blue side to USB side)
3. Reboot: `sudo reboot`
4. Check with: `v4l2-ctl --list-devices`

### Camera Permissions

**Symptoms:** "Permission denied" error

**Fix:**
```bash
sudo usermod -a -G video $USER
newgrp video
```

### Out of Memory

**Symptoms:** Model crashes during load

**Fixes:**
```bash
# Increase swap space
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Or use smaller model
./run_vision_stream.sh --model Obsidian-0.5B
```

### Slow Performance

**Solutions:**
```bash
# Enable max performance mode
sudo nvpmodel -m 0
sudo jetson_clocks

# Lower resolution
./run_vision_stream.sh --width 320 --height 240

# Increase update interval
./run_vision_stream.sh --interval 3.0
```

### GStreamer Errors

**Symptoms:** "nvarguscamerasrc" errors

**Fix:** Use V4L2 instead:
```bash
./run_camera_stream.sh --no-gstreamer
```

### Container Download Fails

**Symptoms:** Network errors during first run

**Fixes:**
1. Check internet: `ping google.com`
2. Free up space: `df -h`
3. Clean Docker: `docker system prune -a`

---

## 📊 Performance Tips

### For Maximum Speed
- Use 320x240 or 640x480 resolution
- Increase update interval to 3-5 seconds
- Use `--model Obsidian-0.5B` (smaller model)
- Enable max performance: `sudo jetson_clocks`

### For Best Quality
- Use 1280x720 resolution
- Decrease update interval to 1-2 seconds
- Use `--model VILA-1.5-3B` (default)
- Use GStreamer (hardware accelerated)

### Battery Life (for portable robots)
- Lower resolution (320x240)
- Longer update intervals (5+ seconds)
- Disable GStreamer if not needed
- Consider motion-triggered vision

---

## 🔄 Next Steps

Once your vision is working:

1. **Add Speech**: Integrate Whisper (speech-to-text) and Piper (text-to-speech)
2. **LEGO Control**: Connect LEGO hub for motor control
3. **Navigation**: Use VILA for obstacle avoidance
4. **Tool Calling**: Add MCP for reminders and notes

See main [README.md](README.md) for full VILA setup guide.

---

## 💡 Tips

- **Test incrementally**: Camera → Stream → Vision
- **Start simple**: Use mock mode first, then VILA
- **Monitor resources**: Use `jtop` to watch memory/GPU
- **Save prompts**: Create shell scripts for common tasks
- **Check logs**: If stuck, check Docker logs

---

## 📚 Additional Resources

- [VILA Paper](https://arxiv.org/abs/2312.07533)
- [NanoLLM Docs](https://dusty-nv.github.io/NanoLLM/)
- [Jetson AI Lab](https://www.jetson-ai-lab.com/)
- [IMX219 Datasheet](https://www.arducam.com/docs/cameras-for-jetson-nano/native-jetson-cameras-imx219-imx477/imx219/)

---

**✅ Ready!** Your Jetson can now see and understand the world with VILA VLM.
