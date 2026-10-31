# Interactive Motion Floor Game

An open-source, low-latency interactive projection floor game designed for children to run, stomp, and cooperate.

---

## 1. System Architecture

The system supports two flexible operating modes, both using **OSC over UDP (Port 9000)**:

### Mode A: All-in-One Pi Appliance (Recommended)
Both the LiDAR Bridge daemon and Godot 4 run directly on the Raspberry Pi 4:
```
┌────────────────────────────────────────────────────────┐
│  All-in-One Floor Appliance (Ceiling / Corner Mount)   │
│                                                        │
│   [ RPLIDAR S2L ]                                      │
│         │ USB Serial (1,000,000 baud)                  │
│         ▼                                              │
│   [ Raspberry Pi 4 (PoE) ]                             │
│     ├─ lidar_bridge (C++ daemon, ~1% CPU)              │
│     │       │ Local UDP Loopback (127.0.0.1:9000)      │
│     │       ▼                                          │
│     └─ Godot 4.7 Game Engine (1080p @ 60 FPS)          │
│             │ Micro-HDMI                               │
└─────────────┼──────────────────────────────────────────┘
              ▼
      [ Floor Projector ]
```

### Mode B: Networked Host PC
The bridge runs on the Pi while Godot runs on a separate PC (e.g. Windows OptiPlex):
- The bridge daemon simultaneously broadcasts to `127.0.0.1` **and** the remote host IP (`192.168.1.34`), so monitoring and development tools work without touching the Pi.

### Key Advantages of this Architecture
- **Zero TouchDesigner overhead & $0 licensing**: No commercial licenses, no 1280×1280 resolution restrictions, and no background software conflicts.
- **Single Cable Run**: With a PoE+ HAT on the Raspberry Pi, a single Cat6 cable provides both power and Gigabit data across the room to the sensor.
- **Low Latency & High Fidelity**: Laser sweeps directly across shoes and balls with zero floor dead-zone, streaming at <1ms network delay.

---

---

## 2. Interactive Floor Game Suite

The project includes 4 physical LiDAR games designed to keep kids actively running, jumping, and cooperating:

### 1. 🫧 Bubble Pop (Free-Play & Holiday Themes)
- Casual, open-ended floating bubble popping with combo multipliers.
- Press **`T`** or **`1`–`4`** to switch holiday skins on the fly:
  - **🫧 Bubbles**: Classic iridescent spheres with cavitation pop sweeps.
  - **👻 Ghosts**: Floating sheet spirits with rippling skirts and spooky *"wooo!"* slide whistles.
  - **🦃 Turkeys**: 7-feather fanned turkeys with comical cartoon gobble chirps.
  - **⛄ Snowmen**: Winter top-hat snowmen with carrot noses and crystalline bell chimes.

### 2. ⚡ Line Jumper (Laser Jump Rope)
- A pulsing laser beam sweeps across the floor (top-to-bottom, bottom-to-top, left-to-right, right-to-left).
- **LiDAR Physics**: When kids jump, their feet elevate off the floor plane so the LiDAR passes harmlessly underneath!
- If the line strikes a grounded foot:
  - Exact **point of contact is dramatically highlighted** with electrical sparks, freeze shockwave, and a *"CONTACT! Player OUT!"* warning.
  - Plays an electric zap sound, pauses for 1.4s, then resumes the sweep.
- Speed escalates every 2 passes, challenging agility and group timing.

### 3. 🎯 Circle Scramble (Musical Spots)
- A **configurable number of circles (2 to 6)** appear scattered across the arena.
- Kids must sprint and each claim one circle before the countdown timer expires.
- **Rules**:
  - One kid per circle: holding a circle locks it in with a bright chime and checkmark.
  - Press **`[`** / **`]`** (or **`-`** / **`+`**) anytime to adjust circle count between 2 and 6.
- If all circles are occupied in time: **Fanfare celebration**, big score bonus, and freshly randomized circle positions!
- If timer expires: Low buzzer warning, missed circles highlight in red.

### 4. 💥 Speed Rush (Bouncing Circle Frenzy)
- Exactly **6 bouncy target circles** spawn into the arena.
- Features **full 4-wall elastic reflection physics**—circles bounce at high velocity like air hockey pucks / pinballs!
- Adopts the active Holiday Theme (bouncing ghosts, gobbling turkeys, rolling snowmen).
- **Round Escalation**:
  - Round 1: 240 px/s, 20s timer.
  - Round 2: 330 px/s (+38%), 18s timer.
  - Round 3: 420 px/s, 16s timer.
  - Round 4+: High-speed madness (up to 620+ px/s) requiring frantic team sprints and stomps.
- Clear all 6 before the timer expires to earn speed bonuses and advance to the next round!

---

## 3. Directory Structure

```
├── game/                    # Godot 4 project
│   ├── project.godot
│   ├── scenes/              # Scenes (Main, Bubble, Calibration, Pop Effect)
│   └── scripts/             # GDScript gameplay, game controllers, and audio
│       ├── game_manager.gd         # Master coordinator & mode switcher
│       ├── game_line_jumper.gd     # Game 2: Line Jumping
│       ├── game_circle_scramble.gd # Game 3: Circle Scramble
│       ├── game_speed_rush.gd      # Game 4: Speed Pop Frenzy
│       ├── bubble.gd               # Bouncy & floating holiday target
│       ├── player_footprint.gd     # Footprint tracking & jump physics
│       ├── audio_manager.gd        # 100% procedural sound synthesis
│       └── osc_receiver.gd         # UDP OSC port 9000 listener
├── lidar-bridge/            # C++ daemon for Raspberry Pi 4
│   ├── Makefile
│   ├── config.json          # Network and playfield configuration
│   ├── lidar-bridge.service # Systemd service for auto-start on boot
│   └── src/                 # Hardware driver, tracker, OSC, and mock simulator
├── tools/                   # Standalone developer tools
│   ├── osc_mouse_simulator.py # Python Tkinter GUI to simulate kids
│   └── deploy_to_pi.sh        # Single-command deploy script to Raspberry Pi
└── .prompts/                # Project plans and platform setup guides
```

---

## 4. Quickstart & Controls

### Running the Game (Godot 4)
1. Open the `/game` directory in **Godot 4.3+** (or run `godot --path game`).
2. Press **F5** to run the project.
3. Master Controls:
   - **G** or **M**: Cycle Game Modes (`Bubble Pop` $\rightarrow$ `Line Jumper` $\rightarrow$ `Circle Scramble` $\rightarrow$ `Speed Rush`).
   - **F1 / F2 / F3 / F4**: Direct switch to Game 1, 2, 3, or 4.
   - **[ / ]** or **- / +**: Adjust circle count (2 to 6) in Circle Scramble.
   - **Space** or **J**: Jump! (Airborne leap — immune to laser line in Line Jumper).
   - **Click & Drag**: Simulates kids' footprints directly with mouse (Left = Kid 1, Right = Kid 2).
   - **Double Click**: Stomp shockwave / jump.
   - **T / TAB**: Cycle Holiday Chase Themes (`🫧 Bubbles -> 👻 Ghosts -> 🦃 Turkeys -> ⛄ Snowmen`).
   - **1 / 2 / 3 / 4**: Quick select holiday theme.
   - **F11 / F**: Toggle Fullscreen projection.
   - **C**: Open **4-Corner Floor Calibration** (aligns projected rect with LiDAR coordinate space).
   - **R**: Reset current game / round.
   - **ESC / Q**: Exit game.

### Testing Without Hardware (OSC Simulator)
You can test the game using either:
1. **The Python GUI Simulator**:
   ```bash
   python3 tools/osc_mouse_simulator.py
   ```
2. **The Raspberry Pi Mock Mode**:
   ```bash
   ssh colin@192.168.1.51
   cd ~/lidar-bridge
   ./lidar_bridge --target <YOUR_PC_IP>
   ```
   *(When the physical S2L is not plugged in, the bridge automatically simulates a virtual room with wandering players).*

---

## 4. Raspberry Pi Deployment (`lidar-bridge`)

### Build
```bash
cd ~/lidar-bridge
make
```

### Run as a Service (Auto-Start on Boot)
```bash
sudo cp lidar-bridge.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now lidar-bridge.service
```

---

## 5. Floor Calibration

To align the projector's floor image with the physical room coordinates:
1. Project the game onto the floor in fullscreen (`F11`).
2. Press `C` to open the calibration overlay.
3. Step on each highlighted corner target in sequence (**Top-Left $\rightarrow$ Top-Right $\rightarrow$ Bottom-Right $\rightarrow$ Bottom-Left**) and press `SPACE`.
4. The matrix is saved automatically to `user://floor_calibration.json` and applied to all incoming player coordinates.
