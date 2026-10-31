#!/bin/bash
set -e

echo "=================================================="
echo " Setting up Raspberry Pi 4 Floor Appliance"
echo "=================================================="

# Install kiosk display compositor and libraries
echo "[1/3] Installing Cage (Wayland Kiosk Compositor) and system libraries..."
sudo apt-get update
sudo apt-get install -y cage libfontconfig1 libasound2-plugins xwayland

# Ensure colin user has access to input, video, and render groups
echo "[2/3] Configuring user permissions..."
sudo usermod -aG video,render,input colin

# Install systemd service for automatic launch on boot (optional)
echo "[3/3] Setting up start script..."
chmod +x /home/colin/start_game.sh

echo "=================================================="
echo " Setup complete!"
echo " Test launch with: /home/colin/start_game.sh"
echo "=================================================="
