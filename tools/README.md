# Developer Tools

## OSC Mouse Simulator (`osc_mouse_simulator.py`)

A standalone graphical tool for macOS/Windows/Linux to test the interactive floor game without needing a Kinect camera or physical rig.

### How to Run:
```bash
python3 tools/osc_mouse_simulator.py
```
*(No `pip install` required — runs with Python 3 standard library)*

### Controls:
- **Kid 1 (Cyan)**: Click and drag with **Left Mouse Button**
- **Kid 2 (Green)**: Click and drag with **Right Mouse Button**
- **Kid 3 (Pink)**: Click and drag with **Shift + Left Mouse Button**
- **Stomp Pulse**: **Double-click** anywhere on the canvas
- **🤖 Auto-Run Bots**: Check the box in the top bar to simulate 3 kids running and wandering around the room automatically.

### Network Output:
- Broadcasts UDP packets to `127.0.0.1:9000` at 60 FPS
- Emits OSC messages in two formats:
  - `/player/update [int id, float x, float y]` (normalized coordinates 0.0 to 1.0)
  - `/player/<id> [float x, float y]` (compact indexed channel format)
  - `/player/remove [int id]` when player steps off the floor
