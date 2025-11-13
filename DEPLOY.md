# VILA Vision Deployment Guide

**Quick deployment guide for getting VILA running on Jetson Orin Nano with IMX219 camera**

---

## 🚀 Quick Deploy (5 Steps)

### Step 1: Clone Repository on Jetson

```bash
# On your Jetson Orin Nano
cd ~
git clone <your-repo-url> butler-jetson
cd butler-jetson
```

### Step 2: Run Setup Script

```bash
chmod +x *.sh
./setup_vila.sh
```

**What this does:**
- Checks disk space and memory
- Installs Docker (if needed)
- Clones jetson-containers
- Configures swap space
- Tests camera
- Sets performance mode

**Time:** ~10-15 minutes

### Step 3: Run Pre-flight Check

```bash
./preflight_check.sh
```

**Expected output:** All green checkmarks ✅

If you see ❌ errors, the script will tell you how to fix them.

### Step 4: Quick Test

```bash
./test_vila.sh
```

**What this tests:**
- Camera capture
- Vision processing (mock mode)

**Time:** ~30 seconds

### Step 5: Run VILA!

```bash
./run_vision_stream.sh
```

**First run:**
- Downloads ~5-10GB (VILA model + container)
- Takes 30-60 minutes
- ⏳ Be patient!

**Subsequent runs:**
- Starts in ~30 seconds

---

## 📋 Deployment Workflow

```
┌─────────────────────┐
│  Clone Repository   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   ./setup_vila.sh   │  ← Install dependencies
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ ./preflight_check.sh│  ← Validate setup
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   ./test_vila.sh    │  ← Quick test
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│./run_vision_stream.sh│ ← Run VILA!
└─────────────────────┘
```

---

## 🔍 Detailed Deployment Steps

### Prerequisites

**Hardware:**
- ✅ Jetson Orin Nano (8GB recommended)
- ✅ IMX219 camera connected to CSI port
- ✅ 128GB+ storage (SD card or NVMe)
- ✅ Internet connection

**Software:**
- ✅ JetPack 5.1.2+ or 6.0+ installed
- ✅ Default Jetson setup completed

### Option A: Automated Setup (Recommended)

```bash
# 1. Clone repo
cd ~
git clone <your-repo> butler-jetson
cd butler-jetson

# 2. Run setup (handles everything)
./setup_vila.sh

# 3. Verify
./preflight_check.sh

# 4. Test
./test_vila.sh

# 5. Run VILA
./run_vision_stream.sh
```

### Option B: Manual Setup

If you prefer manual control:

#### 1. Install Docker

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
newgrp docker
```

#### 2. Create Swap (if needed)

```bash
# Check current swap
free -h

# Create 8GB swap if needed
sudo systemctl disable nvzramconfig
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

#### 3. Install jetson-containers

```bash
cd ~
git clone https://github.com/dusty-nv/jetson-containers
cd jetson-containers
pip3 install -r requirements.txt
```

#### 4. Set Performance Mode

```bash
sudo nvpmodel -m 0
sudo jetson_clocks
```

#### 5. Test Camera

```bash
cd ~/butler-jetson
python3 camera_test.py
```

#### 6. Run VILA

```bash
./run_vision_stream.sh
```

---

## 🧪 Testing VILA

### Quick Test (30 seconds)

Tests camera and basic vision without VILA:

```bash
./test_vila.sh
```

### Full Test (5-10 minutes)

Tests complete VILA pipeline:

```bash
./test_vila.sh --full
```

This includes:
1. Camera capture
2. Mock vision stream
3. VILA model loading
4. VILA vision with camera

---

## 🎛️ Configuration Options

### Basic Usage

```bash
# Default settings (640x480, 2s interval)
./run_vision_stream.sh
```

### Custom Resolution

```bash
# Lower resolution for speed
./run_vision_stream.sh --width 320 --height 240

# Higher resolution for quality
./run_vision_stream.sh --width 1280 --height 720
```

### Custom Update Interval

```bash
# Faster updates (every 1 second)
./run_vision_stream.sh --interval 1.0

# Slower updates (every 5 seconds, saves power)
./run_vision_stream.sh --interval 5.0
```

### Custom Prompts

```bash
# Object detection
./run_vision_stream.sh --prompt "List all objects you see"

# Obstacle detection
./run_vision_stream.sh --prompt "Are there obstacles ahead? Yes or no."

# Person detection
./run_vision_stream.sh --prompt "Do you see a person?"
```

### Different Models

```bash
# Default (VILA-1.5-3B)
./run_vision_stream.sh

# Smaller/faster model
./run_vision_stream.sh --model Obsidian-0.5B
```

### Mock Mode (No VILA)

```bash
# Test without VILA (uses simple vision)
./run_vision_stream.sh --mock
```

---

## 📊 Performance Expectations

### First Run
- **Download time:** 30-60 minutes (5-10GB)
- **Model compilation:** 5-10 minutes
- **Total setup:** ~1 hour

### Subsequent Runs
- **Startup time:** ~30 seconds
- **FPS:** 25-30 FPS camera
- **Vision updates:** Every 2-3 seconds (configurable)
- **RAM usage:** 4-6GB
- **GPU usage:** 60-80%

### Optimization Tips

**For Speed:**
- Lower resolution: `--width 320 --height 240`
- Longer interval: `--interval 5.0`
- Smaller model: `--model Obsidian-0.5B`

**For Quality:**
- Higher resolution: `--width 1280 --height 720`
- Shorter interval: `--interval 1.0`
- Default model: VILA-1.5-3B

**For Battery Life (portable robots):**
- Motion-triggered vision
- Longer intervals (10+ seconds)
- Power saving mode: `sudo nvpmodel -m 1`

---

## 🐛 Troubleshooting

### Issue 1: Camera Not Found

**Error:** `Camera not found at /dev/video0`

**Solutions:**
1. Check physical connection
2. Verify ribbon cable orientation (blue to USB side)
3. Restart: `sudo reboot`
4. Check with: `v4l2-ctl --list-devices`

### Issue 2: Docker Permission Denied

**Error:** `permission denied while trying to connect to Docker`

**Solution:**
```bash
sudo usermod -aG docker $USER
newgrp docker
# Or logout/login
```

### Issue 3: Out of Memory

**Error:** Model fails to load or crashes

**Solutions:**
```bash
# Increase swap
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Or use smaller model
./run_vision_stream.sh --model Obsidian-0.5B
```

### Issue 4: Camera Busy

**Error:** `Device or resource busy`

**Solution:**
```bash
# Find process using camera
fuser /dev/video0

# Kill it
fuser -k /dev/video0

# Or stop Docker containers
docker stop $(docker ps -aq)
```

### Issue 5: Slow Download

**Error:** Download takes very long or times out

**Solutions:**
1. Check internet: `ping google.com`
2. Use wired connection if possible
3. Free up disk space: `docker system prune -a`
4. Try during off-peak hours

### Issue 6: Model Download Fails

**Error:** Network errors during model download

**Solution:**
```bash
# Clean Docker and retry
docker system prune -a
./run_vision_stream.sh
```

---

## 🔄 Common Commands

### Check System Status

```bash
# Check all requirements
./preflight_check.sh

# Monitor resources
sudo jtop

# Check camera
v4l2-ctl --list-devices

# Check Docker containers
docker ps
```

### Restart Services

```bash
# Restart camera daemon
sudo systemctl restart nvargus-daemon

# Restart Docker
sudo systemctl restart docker

# Kill stuck camera processes
fuser -k /dev/video0
```

### Performance Monitoring

```bash
# Real-time stats
sudo tegrastats

# Or better visualization
sudo jtop

# Check GPU usage
sudo jetson_clocks --show
```

### Clean Up

```bash
# Stop all containers
docker stop $(docker ps -aq)

# Clean Docker cache
docker system prune -a

# Free disk space
sudo apt clean
```

---

## 📝 Production Checklist

Before deploying to production robot:

- [ ] Camera tested and working
- [ ] VILA responds correctly to prompts
- [ ] Performance acceptable (FPS, latency)
- [ ] Memory usage stable (no leaks)
- [ ] Error handling tested
- [ ] Power consumption acceptable
- [ ] Integration with robot control tested
- [ ] Recovery from failures tested

---

## 🎯 Next Steps After Deployment

1. **Integration**: Connect to robot control system
2. **Optimization**: Tune resolution and update intervals
3. **Features**: Add obstacle detection, person following
4. **Speech**: Add Whisper (STT) and Piper (TTS)
5. **Tools**: Integrate MCP for reminders/notes

See [README.md](README.md) for full documentation.

---

## 💬 Support

**Issues?**
- Check [SETUP_NOTES.md](SETUP_NOTES.md) for camera troubleshooting
- Run `./preflight_check.sh` to diagnose
- See [QUICKSTART.md](QUICKSTART.md) for usage examples

**Performance Problems?**
- Monitor with `sudo jtop`
- Check [SETUP_NOTES.md](SETUP_NOTES.md) performance section
- Try lower resolution or longer intervals

---

**Status:** Ready for deployment! 🚀

Last updated: November 13, 2024
