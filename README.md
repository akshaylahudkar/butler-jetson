# butler-jetson# VILA VLM Setup Guide for Jetson Orin Nano Super

Complete step-by-step guide to set up VILA 1.5 3B Vision-Language Model on your Jetson Orin Nano.

---

## Prerequisites Check

### 1. Hardware Requirements
- ✅ Jetson Orin Nano Super (8GB)
- ✅ MicroSD card (128GB+ recommended) or NVMe SSD
- ✅ USB camera or CSI camera
- ✅ Internet connection
- ✅ Host computer for initial setup (optional)

### 2. Software Requirements
```bash
# Check your JetPack version
cat /etc/nv_tegra_release

# Should show: R36.x.x (JetPack 6.x) or R35.x.x (JetPack 5.x)
# Minimum: JetPack 5.1.2 or later
# Recommended: JetPack 6.0 or later
```

### 3. Free Space Check
```bash
df -h /

# You need:
# - At least 50GB free for models and containers
# - Recommend 100GB+ for comfort
```

---

## Step 1: System Preparation (15 minutes)

### 1.1 Update System
```bash
# Update package lists
sudo apt update

# Upgrade existing packages (optional but recommended)
sudo apt upgrade -y

# Install essential tools
sudo apt install -y \
    git \
    cmake \
    build-essential \
    python3-pip \
    python3-dev \
    curl \
    wget \
    nano \
    htop
```

### 1.2 Increase Swap Space (Important!)
```bash
# Check current swap
free -h

# If swap is less than 8GB, create more
sudo systemctl disable nvzramconfig

# Create 8GB swap file
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify
free -h
# Should show ~8GB swap
```

### 1.3 Set Power Mode (Maximum Performance)
```bash
# Check available power modes
sudo nvpmodel -q

# Set to maximum performance (mode 0)
sudo nvpmodel -m 0

# Enable jetson_clocks for max frequency
sudo jetson_clocks

# Verify
sudo jetson_clocks --show
```

### 1.4 Install Docker (If Not Already Installed)
```bash
# Check if Docker is installed
docker --version

# If not installed, install it
sudo apt install -y docker.io

# Add your user to docker group
sudo usermod -aG docker $USER

# Apply group changes (or logout/login)
newgrp docker

# Verify
docker run hello-world
```

---

## Step 2: Install jetson-containers (20 minutes)

### 2.1 Clone Repository
```bash
# Navigate to home directory
cd ~

# Clone jetson-containers
git clone https://github.com/dusty-nv/jetson-containers

cd jetson-containers

# Check it's working
./run.sh --help
```

### 2.2 Install Dependencies
```bash
# Install Python requirements
pip3 install -r requirements.txt

# Install jetson-containers package
pip3 install --upgrade jetson-containers
```

### 2.3 Test Container System
```bash
# Pull a small test container
./autotag l4t-pytorch

# This will show available containers
# Don't worry if it takes a minute
```

---

## Step 3: Download and Run VILA VLM (30-60 minutes first time)

### 3.1 Basic VILA Setup (Text Chat)

```bash
# Pull and run VILA 1.5 3B model
# First run will download ~5-10GB, be patient!

cd ~/jetson-containers

./run.sh $(./autotag nano_llm) \
  python3 -m nano_llm.chat \
  --model VILA-1.5-3B \
  --api mlc \
  --quantization q4f16_ft
```

**What's happening:**
- Downloads VILA 1.5 3B model (~3GB)
- Downloads container image (~5-7GB)
- Compiles model for TensorRT
- Starts interactive chat

**Expected output:**
```
Downloading VILA-1.5-3B model...
Building container...
Loading model into memory...
Chat ready! Type your message:
```

### 3.2 Test the Model
```
# In the chat interface:
>> Hello, who are you?

# Expected response:
"I am an AI assistant. How can I help you today?"

>> What is the capital of France?

# Test it responds correctly
```

Press `CTRL+C` to exit when done.

---

## Step 4: VILA with Camera (Live Vision)

### 4.1 Find Your Camera
```bash
# List video devices
ls /dev/video*

# Should show: /dev/video0 (or video1, video2, etc.)

# Test camera with simple capture
v4l2-ctl --list-devices

# Or test with OpenCV
python3 << EOF
import cv2
cap = cv2.VideoCapture(0)
ret, frame = cap.read()
print(f"Camera working: {ret}")
print(f"Resolution: {frame.shape if ret else 'N/A'}")
cap.release()
EOF
```

### 4.2 Run Live VILA (Image Chat)
```bash
cd ~/jetson-containers

# Run with camera - single image mode
./run.sh --volume /dev/video0:/dev/video0 \
  $(./autotag nano_llm) \
  python3 -m nano_llm.chat \
  --model VILA-1.5-3B \
  --api mlc \
  --quantization q4f16_ft \
  --camera /dev/video0
```

**Test it:**
```
# Hold an object in front of camera
>> What do you see?

# VILA should describe the object!
```

### 4.3 Run Live LLaVA (Continuous Vision)
```bash
# This runs continuous vision processing
./run.sh --volume /dev/video0:/dev/video0 \
  $(./autotag nano_llm) \
  python3 -m nano_llm.agents.live_llava \
  --model VILA-1.5-3B \
  --camera /dev/video0 \
  --prompt "Describe what you see in one sentence."
```

**What you'll see:**
- Live camera feed
- Continuous descriptions every few seconds
- Real-time scene understanding

Press `CTRL+C` to stop.

---

## Step 5: Performance Monitoring

### 5.1 Check Resource Usage

**Terminal 1 - Run VILA:**
```bash
./run.sh $(./autotag nano_llm) \
  python3 -m nano_llm.chat \
  --model VILA-1.5-3B
```

**Terminal 2 - Monitor (SSH or second terminal):**
```bash
# GPU stats
sudo tegrastats

# Or use jtop (better visualization)
sudo pip3 install jetson-stats
sudo jtop

# System resources
htop
```

**Expected Usage:**
- RAM: 4-5GB (with model loaded)
- GPU: 50-80% utilization during inference
- CPU: 20-40% average
- Temp: 50-70°C under load

---

## Step 6: Save Common Commands

Create helper scripts for easy access:

### 6.1 Create Launch Script
```bash
nano ~/start_vila_chat.sh
```

**Paste this:**
```bash
#!/bin/bash
cd ~/jetson-containers
./run.sh $(./autotag nano_llm) \
  python3 -m nano_llm.chat \
  --model VILA-1.5-3B \
  --api mlc \
  --quantization q4f16_ft
```

**Make executable:**
```bash
chmod +x ~/start_vila_chat.sh
```

**Run anytime:**
```bash
~/start_vila_chat.sh
```

### 6.2 Create Camera Script
```bash
nano ~/start_vila_camera.sh
```

**Paste this:**
```bash
#!/bin/bash
cd ~/jetson-containers
./run.sh --volume /dev/video0:/dev/video0 \
  $(./autotag nano_llm) \
  python3 -m nano_llm.agents.live_llava \
  --model VILA-1.5-3B \
  --camera /dev/video0 \
  --prompt "Describe what you see."
```

**Make executable:**
```bash
chmod +x ~/start_vila_camera.sh
```

---

## Step 7: Test Different VILA Features

### 7.1 Image File Input
```bash
# Download test image
wget https://images.unsplash.com/photo-1518791841217-8f162f1e1131 -O cat.jpg

# Run VILA with image
./run.sh $(./autotag nano_llm) \
  python3 -m nano_llm.chat \
  --model VILA-1.5-3B \
  --image cat.jpg \
  --prompt "Describe this image in detail"
```

### 7.2 Streaming Mode (For Robot)
```bash
# This mode is perfect for your robot
./run.sh --volume /dev/video0:/dev/video0 \
  $(./autotag nano_llm) \
  python3 << 'EOF'
from nano_llm import NanoLLM
from nano_llm.vision import VideoSource
import time

# Load model
model = NanoLLM.from_pretrained(
    "VILA-1.5-3B",
    api='mlc',
    quantization='q4f16_ft'
)

# Setup camera
camera = VideoSource('/dev/video0')

print("Starting vision loop. Press CTRL+C to stop.")

try:
    while True:
        # Capture frame
        frame = camera.capture()
        
        # Ask VILA
        response = model.generate(
            "What do you see? Reply in one sentence.",
            image=frame,
            streaming=True
        )
        
        print(f"\nVILA: {response}")
        time.sleep(3)  # Update every 3 seconds
        
except KeyboardInterrupt:
    print("\nStopped.")
EOF
```

### 7.3 Object Detection Mode
```bash
./run.sh --volume /dev/video0:/dev/video0 \
  $(./autotag nano_llm) \
  python3 << 'EOF'
from nano_llm import NanoLLM
from nano_llm.vision import VideoSource

model = NanoLLM.from_pretrained("VILA-1.5-3B", api='mlc')
camera = VideoSource('/dev/video0')

while True:
    frame = camera.capture()
    
    # Detect obstacles
    response = model.generate(
        "List any obstacles in front of me. Just names, comma separated.",
        image=frame
    )
    
    print(f"Obstacles: {response}")
    
    if "person" in response.lower():
        print("⚠️  ALERT: Person detected!")
EOF
```

---

## Step 8: Integration with Your Robot

### 8.1 Python API Example
Create `~/robot_vision.py`:

```python
#!/usr/bin/env python3
from nano_llm import NanoLLM
from nano_llm.vision import VideoSource
import time

class RobotVision:
    def __init__(self):
        print("Loading VILA model...")
        self.model = NanoLLM.from_pretrained(
            "VILA-1.5-3B",
            api='mlc',
            quantization='q4f16_ft'
        )
        
        print("Starting camera...")
        self.camera = VideoSource('/dev/video0')
        
        print("✅ Robot vision ready!")
    
    def see(self, question="What do you see?"):
        """Ask VILA about current camera view"""
        frame = self.camera.capture()
        response = self.model.generate(question, image=frame)
        return response
    
    def check_obstacles(self):
        """Check for obstacles ahead"""
        response = self.see("Are there any obstacles in front? Reply yes or no.")
        return "yes" in response.lower()
    
    def find_person(self):
        """Check if person is visible"""
        response = self.see("Do you see a person? Reply yes or no.")
        return "yes" in response.lower()
    
    def describe_scene(self):
        """Get detailed scene description"""
        return self.see("Describe what you see in detail.")

# Test it
if __name__ == "__main__":
    vision = RobotVision()
    
    while True:
        print("\n" + "="*50)
        print(vision.describe_scene())
        time.sleep(3)
```

**Run it:**
```bash
cd ~/jetson-containers
./run.sh --volume /dev/video0:/dev/video0 \
  $(./autotag nano_llm) \
  python3 ~/robot_vision.py
```

### 8.2 Integration with Robot Control
```python
# In your robot code:
from robot_vision import RobotVision
import asyncio

vision = RobotVision()
robot = RobotController()  # Your LEGO hub controller

async def navigate():
    while True:
        # Check for obstacles
        if vision.check_obstacles():
            print("Obstacle detected! Stopping.")
            robot.stop()
            
            # Get details
            scene = vision.describe_scene()
            print(f"I see: {scene}")
            
            # Decide action
            if "left" in scene.lower():
                await robot.turn('right', 45)
            else:
                await robot.turn('left', 45)
        else:
            await robot.move_forward()
        
        await asyncio.sleep(0.5)
```

---

## Troubleshooting

### Issue 1: "Out of Memory" Error
```bash
# Increase swap
sudo swapoff /swapfile
sudo rm /swapfile
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Or use smaller model
# Instead of VILA-1.5-3B, try:
--model Obsidian-0.5B  # Uses only 800MB
```

### Issue 2: "Camera Not Found"
```bash
# Check camera permissions
sudo usermod -a -G video $USER
newgrp video

# Try different camera index
--camera /dev/video1  # Instead of video0

# Test camera manually
gst-launch-1.0 nvarguscamerasrc ! nvoverlaysink
```

### Issue 3: Slow Performance
```bash
# Make sure max performance mode
sudo nvpmodel -m 0
sudo jetson_clocks

# Reduce camera resolution
--camera /dev/video0 --width 640 --height 480

# Use smaller model
--model Obsidian-0.5B
```

### Issue 4: Container Build Fails
```bash
# Clean up old containers
docker system prune -a

# Update jetson-containers
cd ~/jetson-containers
git pull

# Try again
```

### Issue 5: Model Download Fails
```bash
# Check internet
ping -c 3 google.com

# Manual download
cd ~/.cache/huggingface
# Models will be cached here
```

---

## Performance Optimization

### 1. Reduce Latency
```bash
# Use int4 quantization (fastest)
--quantization q4f16_ft

# Reduce context length
--max-context-len 4096  # Default is 8192

# Lower camera resolution
--width 640 --height 480
```

### 2. Save Memory
```bash
# Unload model when not in use
# In Python:
del model
import gc; gc.collect()
```

### 3. Increase FPS
```bash
# Skip frames
--camera-skip 2  # Process every 2nd frame

# Reduce prompt length
# Use shorter questions
```

---

## Next Steps

### ✅ You've completed basic setup if:
- VILA responds to text queries
- Camera feed is working
- Vision + language working together

### 🚀 Ready for robot integration:
1. **Add speech** (Whisper + Piper) - See main design doc
2. **Connect LEGO hub** - Motor control integration
3. **Add navigation** - Obstacle avoidance with VILA
4. **Tool calling** - MCP integration for reminders/notes

### 📚 Learn more:
- NanoLLM docs: https://dusty-nv.github.io/NanoLLM/
- Jetson AI Lab: https://www.jetson-ai-lab.com/
- VILA paper: https://arxiv.org/abs/2312.07533

---

## Quick Reference

### Start VILA Chat
```bash
cd ~/jetson-containers
./run.sh $(./autotag nano_llm) python3 -m nano_llm.chat --model VILA-1.5-3B
```

### Start VILA with Camera
```bash
cd ~/jetson-containers
./run.sh --volume /dev/video0:/dev/video0 $(./autotag nano_llm) \
  python3 -m nano_llm.agents.live_llava --model VILA-1.5-3B --camera /dev/video0
```

### Monitor Performance
```bash
sudo jtop  # or sudo tegrastats
```

### Stop All Containers
```bash
docker stop $(docker ps -aq)
```

---

**🎉 Congratulations!** You now have VILA VLM running on your Jetson Orin Nano. Your robot can see and understand its environment!

**Next:** Integrate with your LEGO motors and add speech for full robot butler functionality.
