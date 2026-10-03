# Windows PC Setup & End-to-End Pipeline Verification

## Objective
Configure this Windows 10 PC (Dell OptiPlex 3010 with GTX 1050 Ti) to run the interactive floor game pipeline:
1. Detect and verify the **PCIe USB 3.0 card** and **Microsoft Kinect v2** depth sensor.
2. Install and configure **Godot 4** to run the Bubble Pop game (`/game`).
3. Install **TouchDesigner** and configure the minimal vision network (`/vision`) to track footprints and stream OSC coordinates to Godot.
4. Verify the end-to-end loop: Player steps on floor $\rightarrow$ Kinect captures depth $\rightarrow$ TouchDesigner extracts blobs $\rightarrow$ OSC sent to `127.0.0.1:9000` $\rightarrow$ Godot pops bubbles with sound & particles.

---

## Hardware Context & Assumptions
- **Host PC**: Dell OptiPlex 3010, Windows 10 64-bit, Nvidia GeForce GTX 1050 Ti.
- **PCIe USB Card**: GLOTRENDS U3023 (Renesas / NEC uPD720202) installed in PCIe x1 slot.
- **Sensor**: Kinect for Xbox One (Model 1520) with 12V AC PC adapter plugged into the PCIe USB 3.0 port.
- **Display**: Primary monitor or projector connected to GTX 1050 Ti via HDMI/DP.
- **Repo Root**: Contains `/game` (Godot project) and `/vision` (TouchDesigner assets).

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

## Phase 3: TouchDesigner Vision & Tracking Pipeline

### 3.1 Install TouchDesigner
1. Download and install **TouchDesigner** (Version 2023+ or 2024+):
   - https://derivative.ca/download
   - Non-Commercial license is free and fully supports Kinect v2 + OSC.
2. Sign in with a free Derivative account when prompted.

### 3.2 Build the Minimal Tracking Network
Open TouchDesigner and create the following lightweight node chain in `/project1`:

1. **`Kinect TOP`** (`kinect1`):
   - Set **Hardware Version** = `Kinect 2`.
   - Set **Image** = `Depth` (or `Player Index`).
2. **`Threshold TOP`** (`thresh1`):
   - Connect input to `kinect1`.
   - Set **Threshold** to isolate the floor slice (e.g. `0.85` to `0.98` depending on ceiling distance). Pixels where kids' feet touch the floor turn bright white; the bare floor is black.
3. **`Blob Track TOP`** (`blobtrack1`):
   - Connect input to `thresh1`.
   - Set **Min Area** and **Max Area** to match typical child foot/body sizes (e.g. Min: 0.005, Max: 0.15).
   - Set **Max Blobs** = `4`.
4. **`Stoner` or `Corner Pin TOP`** (`calibrate1`):
   - Used for 4-point homography calibration: maps the 4 corners of the Kinect floor view directly to the 4 corners of the projector output.
5. **`OSC Out CHOP`** (`oscout1`):
   - Ingest normalized `tx` and `ty` channels from the tracked blobs.
   - Set **Network Address** = `127.0.0.1`.
   - Set **Network Port** = `9000`.
   - Set address format = `/player/update` or `/player/[id]`.

*(Optional: Save this network into `/vision/kinect_tracker.toe`)*.

---

## Phase 4: End-to-End Smoke Test

1. **Launch Godot Game**:
   ```powershell
   godot --path game -f
   ```
2. **Launch TouchDesigner**:
   - Open `/vision/kinect_tracker.toe` and verify the OSC Out CHOP is sending packets.
3. **Physical Playtest**:
   - Step into the Kinect's field of view.
   - Look at the Godot window (or projection on floor).
   - **Success Criteria**:
     - A glowing foot circle appears beneath your foot.
     - Stepping on a bubble triggers a pop sound, score popup, and particle explosion.
     - Stepping out of view removes the footprint.

---

## Phase 5: Production Automation (Single-Click Startup)

Create a batch file `launch_game.bat` in the root folder so the system can be started without manually configuring windows:

```bat
@echo off
title Launching Floor Game...

echo Starting TouchDesigner Vision Engine...
start "" "C:\Program Files\Derivative\TouchDesigner\bin\TouchDesigner.exe" -p vision\kinect_tracker.toe

timeout /t 3 /nobreak > nul

echo Starting Godot Bubble Pop Game...
start "" godot.exe --path game -f

echo System Running! Press any key to exit launcher.
pause
```
