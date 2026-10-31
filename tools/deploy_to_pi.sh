#!/bin/bash
# Helper script to deploy updated game and bridge code to the Raspberry Pi

PI_HOST="${1:-10.10.2.20}"
PI_USER="${2:-colin}"

echo "=================================================="
echo " Deploying to Raspberry Pi at ${PI_USER}@${PI_HOST}"
echo "=================================================="

# Check ping
if ! ping -c 1 -W 2 "$PI_HOST" >/dev/null 2>&1; then
    echo "⚠️  Warning: Cannot ping $PI_HOST. Ensure the Pi is powered on and connected to the network."
    echo "Usage: ./tools/deploy_to_pi.sh <PI_IP>"
    exit 1
fi

echo "1. Syncing game files..."
rsync -avz --exclude '.godot' game/ "${PI_USER}@${PI_HOST}:~/game/"

echo "2. Syncing lidar-bridge..."
rsync -avz lidar-bridge/ "${PI_USER}@${PI_HOST}:~/lidar-bridge/"

echo "3. Updating launcher script..."
ssh "${PI_USER}@${PI_HOST}" "cp ~/lidar-bridge/start_game.sh ~/start_game.sh && chmod +x ~/start_game.sh"

echo "=================================================="
echo " Deployment successful!"
echo "=================================================="
