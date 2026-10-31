#!/bin/bash
# Raspberry Pi 4 All-in-One Floor Appliance Launcher

# 1. Start the LiDAR Bridge in background if not already running
if ! pgrep -x "lidar_bridge" > /dev/null; then
    echo "[Launcher] Starting LiDAR Bridge..."
    /home/colin/lidar-bridge/lidar_bridge > /home/colin/bridge.log 2>&1 &
    sleep 1
fi

# 2. Launch Godot in Fullscreen Kiosk Mode via Cage using native Wayland
echo "[Launcher] Launching Godot Floor Game on HDMI..."
exec cage -s -d -- /home/colin/Godot_v4.7.2-stable_linux.arm64 \
    --display-driver wayland \
    --rendering-driver opengl3_es \
    --path /home/colin/game \
    -f
