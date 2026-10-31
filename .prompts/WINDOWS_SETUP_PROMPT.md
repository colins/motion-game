# Windows PC Setup & End-to-End Pipeline Verification

## Objective
Configure this Windows 10 PC (Dell OptiPlex 3010 with GTX 1050 Ti) to run the interactive floor game pipeline:
1. Run **Godot 4** in fullscreen floor projection (`/game`).
2. Receive player footprints directly from the **Raspberry Pi 4 LiDAR bridge** over Ethernet (UDP port 9000).
3. Use the in-engine 4-corner calibration (`C`) to align the projected image to the physical floor area.
4. Verify the end-to-end loop: Player steps on floor $\rightarrow$ RPLIDAR detects feet $\rightarrow$ Pi clusters centroids $\rightarrow$ OSC sent over Ethernet to port 9000 $\rightarrow$ Godot pops bubbles with sound & particles.

---

## Hardware Context & Assumptions
- **Host PC**: Dell OptiPlex 3010, Windows 10 64-bit, Nvidia GeForce GTX 1050 Ti.
- **Sensor**: Slamtec RPLIDAR S2L connected via USB to Raspberry Pi 4 (PoE powered at 192.168.1.51).
- **Network**: Direct Ethernet connection on local subnet (Gigabit UDP stream).
- **Display**: Projector connected to GTX 1050 Ti via HDMI/DP.
- **Repo Root**: Contains `/game` (Godot project), `/lidar-bridge` (Raspberry Pi C++ daemon), and `/tools` (developer simulator).

---

## Phase 1: Hardware & Driver Verification

### 1.1 Verify USB 3.0 Controller
Open PowerShell as Administrator and run:
```powershell
Get-PnpDevice -Class "USB" | Where-Object { $_.FriendlyName -match "xHCI|Renesas|NEC" }
```
- **Check**: Ensure the Renesas/NEC USB 3.0 eXtensible Host Controller is present with `Status: OK` and no yellow exclamation marks (Code 10/28).

### 1.2 Install Kinect for Windows SDK 2.0
1. Download and install the official Microsoft **Kinect for Windows SDK 2.0 (v1409)**:
   - Official Microsoft Download: https://www.microsoft.com/en-us/download/details.aspx?id=44561
   - Or install via winget (if available):
     ```powershell
     winget install --id Microsoft.KinectSDK -e
     ```
2. Connect the Kinect v2:
   - Plug the Kinect proprietary connector into the 12V PC adapter box.
   - Plug the AC power adapter into wall power.
   - Connect the USB 3.0 cable from the adapter directly into one of the **new PCIe USB ports** on the back of the PC.
3. Verify Kinect drivers in Device Manager:
   ```powershell
   Get-PnpDevice | Where-Object { $_.FriendlyName -match "Kinect" }
   ```
   You should see:
   - `WDF KinectSensor Interface 0`
   - `KinectSensor Devices -> Xbox NUI Sensor`
   - `Audio Processing Objects (APOs) -> Kinect Sensor Audio`

### 1.3 Smoke Test Kinect Video & Depth
1. Open the start menu and launch **"Kinect Studio v2.0"** or **"SDK Browser v2.0 (Kinect for Windows)"**.
2. Run the **"Depth Basics-D2D"** or **"Body Basics-D2D"** sample.
3. **Verification Gate**:
   - Confirm the depth camera streams at **30 FPS**.
   - Confirm there are no USB bandwidth warnings or dropped frames.

---

## Phase 2: Godot 4 Runtime Setup

### 2.1 Install Godot 4
In PowerShell:
```powershell
winget install --id GodotEngine.GodotEngine -e
```
*(Or download the official 64-bit Windows Godot 4 executable from https://godotengine.org and place it in your `PATH` as `godot.exe`)*.

### 2.2 Verify the Bubble Pop Game
1. Open a terminal in the project directory:
   ```powershell
   cd touchdesigner\game
   godot --path .
   ```
2. **Verification Gate**:
   - The game window opens at 1920x1080 (press `F11` for fullscreen).
   - Bubbles spawn and float upwards with sine wobbles.
   - Click and drag with the **Left Mouse Button**: A cyan glowing footprint should follow the cursor and pop bubbles with audio pops, particle bursts, and combo popups.
   - Close the window.

---

## Phase 3: Network LiDAR Connection (Raspberry Pi 4)

*Note: TouchDesigner has been eliminated from the architecture. The Raspberry Pi 4 processes LiDAR scans on-board and streams OSC directly over Ethernet to UDP port 9000.*

### 3.1 Verify Network Connection to Raspberry Pi
1. Test network ping from Windows PowerShell:
   ```powershell
   ping 192.168.1.51
   ```
2. Verify that UDP port 9000 is open in Windows Firewall:
   ```powershell
   New-NetFirewallRule -DisplayName "Godot OSC Port 9000" -Direction Inbound -LocalPort 9000 -Protocol UDP -Action Allow
   ```

---

## Phase 4: End-to-End Smoke Test & Floor Calibration

1. **Launch Godot Game**:
   ```powershell
   godot --path game -f
   ```
2. **Verify Footprints**:
   - The Raspberry Pi (`lidar_bridge`) streams player footprints over UDP.
   - Glowing circular footprints appear beneath active players.
3. **Calibrate Floor Projection**:
   - Press **`C`** on the keyboard to bring up the 4-Corner Calibration overlay.
   - Walk to and step on each highlighted corner target (Top-Left $\rightarrow$ Top-Right $\rightarrow$ Bottom-Right $\rightarrow$ Bottom-Left) and press **`SPACE`**.
   - The calibration matrix saves to disk and immediately aligns the game field with the physical floor area.

---

## Phase 5: Production Automation (Single-Click Startup)

Create a batch file `launch_game.bat` in the root folder so the system can be started without manually configuring windows:

```bat
@echo off
title Launching Floor Game...

echo Starting Godot Floor Game...
start "" godot.exe --path game -f

echo System Running! Press any key to exit launcher.
pause
```
