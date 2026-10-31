# Slamtec RPLIDAR S2L to Godot 4 Bridge

High-performance C++ daemon running on a Raspberry Pi 4 that ingests 32,000 pts/sec from a Slamtec RPLIDAR S2L over USB serial (1,000,000 baud) and broadcasts low-latency OSC and UDP packets across the local network directly into Godot 4.

---

## Features

- **Hardware Acceleration**: Built in C++17 against the official Slamtec C++ SDK (`libsl_lidar_sdk.a`) with sub-millisecond latency and zero packet loss.
- **Built-in Player Tracking**: Clusters raw shoe/foot reflection points using Euclidean distance segmentation and tracks player centroids across frames.
- **Direct Godot OSC Output (Port 9000)**: Emits `/player/update [id, x, y]`, `/player/<id> [x, y]`, and `/player/remove [id]` directly consumable by Godot's `osc_receiver.gd` without any intermediate software.
- **Raw Point Cloud Stream (Port 7001)**: Compact binary UDP stream for diagnostics, coverage checks, and visual debugging.
- **Automatic Mock Mode**: When no physical LiDAR is connected, the bridge automatically falls back to an internal 15 Hz simulator broadcasting a virtual room and moving players for rapid software development.
- **Auto-Reconnect**: Safely recovers if the USB cable is unplugged or replugged.

---

## Directory Structure

```
lidar-bridge/
├── config.json              # Network and playfield parameters
├── Makefile                 # C++ compilation script
├── lidar-bridge.service     # Systemd background service definition
└── src/
    ├── main.cpp             # Daemon entry point & hardware loop
    ├── tracker.hpp          # Euclidean clustering & player tracking
    ├── osc_out.hpp          # Zero-dependency OSC packet builder
    └── mock_lidar.hpp       # Realistic 360° raycasting simulator
```

---

## Configuration (`config.json`)

```json
{
  "serial_port": "/dev/ttyUSB0",
  "baud_rate": 1000000,
  "target_ip": "192.168.1.34",
  "osc_port": 9000,
  "raw_port": 7001,
  "mock_mode": false,
  "min_x": -3.0,
  "max_x": 3.0,
  "min_y": 0.0,
  "max_y": 6.0
}
```

- `target_ip`: IP address of the machine running TouchDesigner or Godot.
- `min_x`, `max_x`, `min_y`, `max_y`: Playfield boundaries in meters relative to the sensor. Points outside these bounds are discarded.

---

## Building & Running on the Raspberry Pi

### 1. Build
```bash
cd ~/lidar-bridge
make
```

### 2. Manual Run
```bash
# Auto-detects hardware or starts mock mode:
./lidar_bridge

# Or specify custom destination IP on the fly:
./lidar_bridge --target 192.168.1.34
```

### 3. Install as a System Service (Auto-run on Boot)
```bash
sudo cp lidar-bridge.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now lidar-bridge.service

# View live logs:
journalctl -u lidar-bridge -f
```
