# Interactive Floor Game: Project Specification & Phased Execution Plan

## 1. Project Overview & Vision
- **Objective**: Design an engaging, physically active floor projection game for kids aged 8–10 to chase and capture virtual beasts.
- **Physical Concept**: Top-down projection onto the floor with real-time motion/depth tracking of children running, stomping, and cooperating.
- **Developer Profile**: Software engineer with strong code/Git background, no prior TouchDesigner experience, seeking an automated or code-centric development workflow with minimal manual node-graph manipulation.

---

## 2. Hardware Inventory & Physical Environment

### Available Hardware
| Component | Model / Specs | Key Role | Initial Notes / Concerns |
| :--- | :--- | :--- | :--- |
| **Host PC** | Dell OptiPlex 3010, Win 10<br>Intel Core (Ivy Bridge), 8GB RAM<br>Nvidia GeForce GTX 1050 Ti (4GB) | Runtime & Tracking Engine | Motherboard (H61) lacks native USB 3.0; 8GB RAM is modest.<br>**Update**: PCIe USB 3.0 card ordered (GLOTRENDS U3023 - Renesas uPD720202). |
| **Depth Sensor** | Microsoft Kinect for Xbox One (Model 1520) | Player Tracking / Vision | Requires Kinect PC Adapter (12V) + dedicated USB 3.0 controller. |
| **Standard Projector**| Putrims K12 (Budget LED/LCD) | Floor Projection (Option A) | Standard throw (~1.3:1); vertical mount thermal concerns. |
| **UST Projector** | Vava VA-LT002 (4K Laser UST) | Floor Projection (Option B) | Ultra-short-throw (~0.23:1); floor placement vs. ceiling rigging challenges. |

### Environment Specifications
- **Dimensions**: 20 ft × 20 ft (400 sq ft)
- **Ceiling Structure**: Suspended (drop) ceiling with acoustic tiles at 8 ft. Space/structure above grid allows projector and sensor mounting up to **9 ft from the floor** (by recessing into/replacing a tile or anchoring to the true ceiling structure above).
- **Floor Surface**: TBD (requires matte, light surface for visibility and traction for running kids)

---

## 3. Critical Technical Feasibility & Watchouts

1. **OptiPlex 3010 USB 3.0 Constraint**:
   - The OptiPlex 3010 does not have native USB 3.0 on its H61 motherboard. Kinect v2 demands high-bandwidth isochronous transfers. A dedicated PCIe USB 3.0 card (Renesas/NEC or FL1100 chipset) is mandatory.
2. **Kinect v2 Top-Down Optics (8–9ft Height)**:
   - At a 9 ft mounting height, Kinect v2 FOV (70° H × 60° V) expands the active tracking area to **~12.6 ft × 10.4 ft** (~131 sq ft), a ~45% coverage increase over an 7.5 ft mount.
   - Skeletal tracking will not work pointing straight down. The tracking pipeline must use **depth thresholding + 2D blob tracking** (detecting player footprints/body masses).
3. **Projector Optics & Throw Constraints**:
   - **Putrims K12**: At 8.5–9 ft drop, throw ratio 1.3:1 yields an image roughly **~6.5–6.9 ft wide by ~3.7–3.9 ft deep** (16:9). Still modest relative to the room, but larger than at 7 ft. Thermal ventilation remains critical if pointing vertically downward.
   - **Vava UST**: Floor placement risks tripping/kicking by 8–10-year-olds; ceiling mount requires custom bracket/mirror and strict keystone adjustment.
   - **Drop Ceiling Mounting**: Suspended ceilings provide convenient routing space for cables and the ability to mount via standard 2×2 / 2×4 drop-ceiling projector plates (or scissor clamps on the T-bar grid for lightweight hardware).
4. **Architecture Synergy (Direct LiDAR to Godot Pipeline - TouchDesigner Eliminated)**:
   - **Raspberry Pi 4 + RPLIDAR S2L**: Handles sensor-level processing at the edge. The C++ `lidar_bridge` daemon consumes 32,000 pts/sec from the hardware SDK, performs Euclidean clustering for player feet, tracks player IDs, and streams compact `/player/update [id, x, y]` OSC packets directly over Ethernet (port 9000).
   - **Godot 4**: Ingests OSC directly on UDP port 9000, handles 2D physics, beast AI, particle juice, audio, fullscreen 1080p/4K projection, and includes an in-engine 4-corner floor calibration overlay (`calibration.gd` / `calibration_overlay.tscn`).
   - **TouchDesigner Removed**: Eliminates commercial licensing restrictions ($600–$2,200), eliminates 1280×1280 resolution caps, avoids multi-window focus issues on the Windows host, and keeps 100% of the project in version-controlled text code (C++ & GDScript).

---

## 4. Refined Phased Task List

### Phase 1: Hardware Viability & Environmental Optics Audit
*Goal: Confirm physical connectivity, mounting geometry, and playable dimensions before building software.*

- [x] **1.1. OptiPlex Connectivity Audit**:
  - [x] Select and acquire USB 3.0 PCIe expansion card compatible with Kinect v2 SDK (*Ordered: GLOTRENDS U3023 - Renesas uPD720202*).
  - [ ] Install card, verify Kinect SDK 2.0 device recognition, and verify GPU driver support + dual-display output (GTX 1050 Ti: DisplayPort/HDMI to projector + control monitor).
- [ ] **1.2. Projection & Coverage Geometry Calculation**:
  - Calculate exact throw distance and resulting aspect/image size for both Putrims K12 and Vava VA-LT002 at 8.0–9.0 ft mounting heights.
  - Model kid shadow occlusion angles and compare single-projector vs. potential dual-projector or mirror-bounce options.
- [ ] **1.3. Room Layout & Staging Plan (Suspended Ceiling Options)**:
  - Design a mounting solution: compare drop-ceiling tile bridge plates (e.g. Chief CMA440 replacement tile kit) / grid scissor clamps vs. non-permanent weighted C-stands/lighting trusses for testing.
  - Leverage above-grid plenum space for clean, safe overhead cable runs out of reach of running kids.
  - Define safety buffer zones around the active projection footprint.
- [ ] **1.4. Low-Cost Upgrade Path Definition**:
  - If existing hardware proves insufficient (e.g., small throw size, low lumens, USB dropouts), define budget-friendly upgrade recommendations (e.g., short-throw office projectors like BenQ/InFocus, PCIe USB cards, lightweight depth cameras).

---

### Phase 2: Architecture & Development Workflow Evaluation
*Goal: Establish a developer-friendly, Git-friendly pipeline that avoids manual node-graph editing.*

- [x] **2.1. TouchDesigner MCP Server Assessment**:
  - [x] Survey and benchmark existing TouchDesigner MCP servers on GitHub.
  - [x] **Recommendation**: Use [benoitliard/touch-mcp](https://github.com/benoitliard/touch-mcp) (persistent WebSocket transport on port 9980, 37 tools including `td_batch`, auto-layout, parameter introspection, and image snapshots). Fallback: [8beeeaaat/touchdesigner-mcp](https://github.com/8beeeaaat/touchdesigner-mcp).
  - [x] Confirmed workflow: AI agent can programmatically construct and modify the node graph via MCP; TouchDesigner runs in the background as the execution engine.
- [x] **2.2. Architecture Evolution: Native LiDAR + Godot 4 Pipeline (TouchDesigner Cut)**:
  - [x] **Decision**: TouchDesigner eliminated in favor of a direct **Raspberry Pi 4 (PoE) $\rightarrow$ Ethernet (OSC UDP) $\rightarrow$ Godot 4** pipeline.
  - [x] **Sensor Scope (Raspberry Pi 4)**: C++ daemon running Slamtec SDK at 15 Hz, performs Euclidean clustering on foot reflections, tracks player IDs, and broadcasts directly to UDP port 9000.
  - [x] **Godot 4 Scope**: Full game engine receiving `/player/update [id, x, y]`, native 1080p/4K rendering, and built-in 4-corner floor calibration.
  - [x] **Development Workflow**: 90%+ developed and iterated on macOS using an OSC mouse simulator; single-click export to Windows executable (`.exe`) for the OptiPlex 3010 runtime.
- [x] **2.3. GitHub Source Control & Repository Strategy**:
  - [x] Initialized directory structure:
    - `/game`: Godot 4 project (`project.godot`, scenes, GDScript files).
    - `/lidar-bridge`: C++ daemon running on Raspberry Pi 4.
    - `/tools`: Standalone Python OSC mouse simulator with zero external dependencies.
  - [x] Configured `.gitignore` for Godot, C++ artifacts, and Python.

---

### Phase 3: Commercial Landscape & Cost/TCO Analysis
*Goal: Benchmark DIY investment against commercial interactive floor solutions.*

- [x] **3.1. Market Survey of Commercial Offerings**:
  - [x] Analyzed turnkey offerings: [EyeClick BEAM](https://eyeclick.com/) ($5,796+ hardware, ongoing content license) and [ActiveFloor](https://activefloor.com/) ($5,300–$11,900 hardware, $1,300–$5,400 subscription).
  - [x] Analyzed software-only alternative: [LUMOplay](https://www.lumoplay.com/) ($263–$585/yr per PC).
  - [x] **Finding**: Commercial turnkey solutions cater primarily to toddlers (ages 2–6) or therapy with passive mechanics (bubble-popping, koi pond). They lack the dynamic AI, evasion, and gameplay challenge required to engage 8–10 year olds.
- [x] **3.2. Three-Year Total Cost of Ownership (TCO) Comparison**:
  - [x] **Turnkey Commercial**: $9,696 – $17,300+ (High hardware cost + mandatory ongoing subscriptions).
  - [x] **COTS Software (LUMOplay)**: $857 – $1,873 (Pre-made casual mini-games, limited beast mechanics).
  - [x] **DIY Native Pipeline (Godot 4 + Slamtec S2L + Pi 4)**: **~$350** ($290 LiDAR + $55 Pi + PoE HAT; $0 recurring software fees).
- [x] **3.3. DIY Viability Decision**:
  - [x] **Verdict**: **DIY is emphatically worth it.** DIY saves ~$9,500–$17,000, avoids subscription lock-in, and provides full control to build active, cooperative beast-capturing gameplay tailored specifically for 8–10 year olds.

---

### Phase 4: LiDAR Ingestion & In-Engine Floor Calibration
*Goal: Stream low-latency player coordinates and accurately align projector coordinates with the physical floor.*

- [x] **4.1. Raspberry Pi 4 C++ Bridge Daemon**:
  - Built high-speed C++17 daemon linked against official `libsl_lidar_sdk.a`.
  - Configurable playfield bounds filtering and Euclidean foot clustering.
  - Automatic fallback to internal 15 Hz mock simulator when LiDAR is disconnected.
- [x] **4.2. Low-Latency OSC Streaming**:
  - Broadcasts `/player/update [id, x, y]`, `/player/<id> [x, y]`, and `/player/remove [id]` over UDP port 9000.
  - Raw point cloud packet streaming on port 7001 for diagnostics.
- [x] **4.3. In-Engine 4-Corner Projector Calibration (`calibration.gd`)**:
  - Interactive calibration overlay in Godot (Press `C`).
  - 4-point bilinear mapping aligns physical floor dimensions with projector aspect ratio.
  - Persistent storage in `user://floor_calibration.json`.

---

### Phase 5: Godot 4 Game Suite & Beast Capture Mechanics (Cross-Platform)
*Goal: Create an engaging, high-energy arcade suite spanning sensory games for younger kids (3–7) up to cooperative beast-capturing games for older kids (8–10).*

- [x] **5.1. OSC Receiver & Player Abstraction in Godot**:
  - [x] Implemented UDP listener on port 9000 decoding `/player/update [id, x, y]`, `/player/<id> [x, y]`, and `/player/remove [id]`.
  - [x] Built-in in-engine mouse fallback: click/drag directly in the Godot game window to simulate kids.
- [x] **5.2. Starter / Younger Kid Game: Bubble Burst**:
  - [x] Built interactive `BubblePop` game: organic floating physics, sine wobbling, randomized varieties (Normal, Speedy, Mega).
  - [x] Real-time foot-strike collision detection against active kid footprints.
  - [x] Holiday themes (Ghosts, Turkeys, Snowmen, Bubbles) switchable via `T` / `1`–`4`.
  - [x] Procedural particle explosion shockwaves (`pop_effect.tscn`).
  - [x] Built-in procedural audio pop synthesizer (`audio_manager.gd`) with dynamic pitch variation and zero external sound files.
  - [x] HUD with combo multiplier, score tracking, and active kid counters.
- [x] **5.3. Laser Line Jumping (Jump Rope / Laser Sweeper)**:
  - [x] Sweeping laser line traverses the arena in alternating directions (top-down, bottom-up, left-right, right-left).
  - [x] LiDAR air-elevation detection: airborne jumping feet avoid collision with the floor laser.
  - [x] Exact point of contact highlighted on impact with electrical shockwave, sparks, and tag freeze.
  - [x] Synthesized electric zap audio, pass whoosh chimes, and escalating speed per round.
- [x] **5.4. Circle Scramble (Musical Spots)**:
  - [x] Configurable 2 to 6 glowing circles scattered across the floor with distance rejection.
  - [x] Adjustable count via `[` / `]` or `-` / `+` hotkeys on the fly.
  - [x] Countdown timer with accelerating audible ticks.
  - [x] One kid per circle occupancy check with bright chime and checkmark lock-in.
  - [x] Fanfare celebration when all circles are found, timeout buzzer when time expires.
- [x] **5.5. Speed Pop Frenzy (Bouncing Target Rush)**:
  - [x] Exactly 6 bouncy target circles with full 4-wall elastic reflection physics.
  - [x] Themed skins (Ghosts, Turkeys, Snowmen, Bubbles) with high-velocity trajectories.
  - [x] Escalating difficulty per round: speeds ramp up from 240 px/s to 600+ px/s as timer tightens.
  - [x] Round cleared victory fanfare + time bonuses, timeout fail state with restart.
- [x] **5.6. Master Game Mode Coordinator**:
  - [x] Unified `GameMode` state machine (`G` / `M` cycles, `F1`–`F4` direct access).
  - [x] Live HUD with mode badge, live status banner, theme indicator, and hotkey guide.

---

### Phase 6: Iterative Testing & Safety Protocol
*Goal: Safely test with target audience and refine through quick feedback loops.*

- [x] **6.1. Headless / Mock Simulator (macOS)**:
  - [x] Built standalone `tools/osc_mouse_simulator.py` (Tkinter GUI, zero-dependency standard library).
  - [x] Features Left-click (Kid 1), Right-click (Kid 2), Shift-click (Kid 3), Double-click stomp, and "🤖 Auto-Run Bots" simulation mode broadcasting OSC at 60 FPS.
- [ ] **6.2. Staging & Playtesting Plan**:
  - Safety review: drop ceiling cable routing, wall clearance buffer zones, padded projector mounts.
  - Run structured 15-minute playtests with 8–10-year-old kids; record engagement, confusion, and edge cases (jumping, falling, group dog-piles).
- [ ] **6.3. Post-Demo Iteration Review**:
  - Prioritize bug fixes, tracking tuning, and feature requests for subsequent iterations.

---

## 5. Immediate Next Steps & Decision Gate
1. **Decision Gate 1 (RESOLVED)**: PCIe USB 3.0 card ordered ([GLOTRENDS U3023](https://www.amazon.com/dp/B0BSG5J9M8), Renesas uPD720202).
2. **Decision Gate 2 (RESOLVED)**: Adopted **Hybrid Architecture** (TouchDesigner Vision Engine $\rightarrow$ OSC over UDP $\rightarrow$ Godot 4 Game Engine).
3. **Execution**:
   - Begin Task 2.3 (Initialize repository structure with `/vision`, `/game`, and `/tools`).
   - Calculate detailed projector throw & coverage geometry (Task 1.2) for the 9ft drop ceiling.
   - Scaffold the Godot multi-game runner and first smoke-test game (*Bubble Pop*).
