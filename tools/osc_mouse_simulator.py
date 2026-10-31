#!/usr/bin/env python3
"""
OSC Mouse Simulator for Interactive Floor Game.
Simulates children running/stomping on the projected floor.
Broadcasts OSC packets over UDP to 127.0.0.1:9000.

Zero external dependencies - runs with standard Python 3.
"""

import sys
import time
import math
import socket
import struct
import random
import threading
import tkinter as tk
from tkinter import ttk

# Standard OSC packet builder
def pad4(data: bytes) -> bytes:
    pad_len = (4 - (len(data) % 4)) % 4
    if pad_len == 0 and len(data) > 0 and data[-1:] != b'\x00':
        # Need null terminator
        pad_len = 4
    elif pad_len == 0:
        return data
    return data + b'\x00' * pad_len

def build_osc_message(address: str, args: list) -> bytes:
    # Address string must be null terminated and 4-byte padded
    addr_bytes = address.encode('utf-8') + b'\x00'
    addr_padded = pad4(addr_bytes)
    
    # Type tags
    tag_str = ","
    payload = b""
    for arg in args:
        if isinstance(arg, int):
            tag_str += "i"
            payload += struct.pack(">i", arg)
        elif isinstance(arg, float):
            tag_str += "f"
            payload += struct.pack(">f", arg)
        elif isinstance(arg, str):
            tag_str += "s"
            str_bytes = arg.encode('utf-8') + b'\x00'
            payload += pad4(str_bytes)
            
    tag_bytes = tag_str.encode('utf-8') + b'\x00'
    tag_padded = pad4(tag_bytes)
    
    return addr_padded + tag_padded + payload


class OSCMouseSimulator:
    def __init__(self, root):
        self.root = root
        self.root.title("Interactive Floor - OSC Simulator")
        self.root.resizable(False, False)
        
        self.host = "127.0.0.1"
        self.port = 9000
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        
        # Player state: id -> {'x': float, 'y': float, 'active': bool, 'color': str, 'name': str}
        self.players = {
            0: {'x': 0.5, 'y': 0.5, 'active': False, 'color': '#00F0FF', 'name': 'Kid 1 (Left Drag)'},
            1: {'x': 0.3, 'y': 0.7, 'active': False, 'color': '#39FF14', 'name': 'Kid 2 (Right Drag)'},
            2: {'x': 0.7, 'y': 0.3, 'active': False, 'color': '#FF007F', 'name': 'Kid 3 (Shift+Drag)'},
        }
        
        # Bot auto-walk state
        self.bot_active = False
        self.bot_targets = {
            0: [random.uniform(0.1, 0.9), random.uniform(0.1, 0.9)],
            1: [random.uniform(0.1, 0.9), random.uniform(0.1, 0.9)],
            2: [random.uniform(0.1, 0.9), random.uniform(0.1, 0.9)]
        }
        
        self.packets_sent = 0
        self.canvas_w = 800
        self.canvas_h = 450
        
        self._build_ui()
        
        # Start background 60Hz sender loop
        self.running = True
        self.network_thread = threading.Thread(target=self._sender_loop, daemon=True)
        self.network_thread.start()

    def _build_ui(self):
        # Top toolbar
        top_frame = ttk.Frame(self.root, padding=8)
        top_frame.pack(fill=tk.X)
        
        ttk.Label(top_frame, text=f"Target: {self.host}:{self.port} (UDP OSC)", font=("Helvetica", 11, "bold")).pack(side=tk.LEFT, padx=5)
        
        self.stat_label = ttk.Label(top_frame, text="Packets: 0", font=("Helvetica", 10))
        self.stat_label.pack(side=tk.LEFT, padx=15)
        
        self.bot_var = tk.BooleanVar(value=False)
        self.bot_check = ttk.Checkbutton(top_frame, text="🤖 Auto-Run Bots (Simulate 3 Kids)", variable=self.bot_var, command=self._toggle_bots)
        self.bot_check.pack(side=tk.RIGHT, padx=5)
        
        # Canvas representation of floor
        self.canvas = tk.Canvas(self.root, width=self.canvas_w, height=self.canvas_h, bg="#0d1117", highlightthickness=0)
        self.canvas.pack(padx=8, pady=4)
        
        # Draw floor guides
        self._draw_floor_grid()
        
        # Bottom controls / instructions
        bottom_frame = ttk.Frame(self.root, padding=8)
        bottom_frame.pack(fill=tk.X)
        
        help_text = "Controls:  [Left Click + Drag] Kid 1 (Cyan)   |   [Right Click + Drag] Kid 2 (Green)   |   [Shift + Left Drag] Kid 3 (Pink)"
        ttk.Label(bottom_frame, text=help_text, foreground="#555555", font=("Helvetica", 10)).pack(side=tk.LEFT)
        
        # Bind mouse events
        self.canvas.bind("<Button-1>", self._on_left_down)
        self.canvas.bind("<B1-Motion>", self._on_left_drag)
        self.canvas.bind("<ButtonRelease-1>", self._on_left_up)
        
        self.canvas.bind("<Button-2>", self._on_right_down) # macOS trackpad 2-finger or right click
        self.canvas.bind("<B2-Motion>", self._on_right_drag)
        self.canvas.bind("<ButtonRelease-2>", self._on_right_up)
        
        self.canvas.bind("<Button-3>", self._on_right_down) # Standard right click
        self.canvas.bind("<B3-Motion>", self._on_right_drag)
        self.canvas.bind("<ButtonRelease-3>", self._on_right_up)
        
        self.canvas.bind("<Double-Button-1>", self._on_stomp)

    def _draw_floor_grid(self):
        # Grid lines for spatial visual
        for x in range(100, self.canvas_w, 100):
            self.canvas.create_line(x, 0, x, self.canvas_h, fill="#161b22", dash=(2, 4))
        for y in range(75, self.canvas_h, 75):
            self.canvas.create_line(0, y, self.canvas_w, y, fill="#161b22", dash=(2, 4))
        # Center target
        cx, cy = self.canvas_w // 2, self.canvas_h // 2
        self.canvas.create_oval(cx - 40, cy - 40, cx + 40, cy + 40, outline="#21262d", width=2)
        self.canvas.create_text(cx, cy, text="FLOOR ARENA", fill="#30363d", font=("Helvetica", 14, "bold"))

    def _toggle_bots(self):
        self.bot_active = self.bot_var.get()
        if not self.bot_active:
            for pid in self.players:
                self.players[pid]['active'] = False
                self._send_player_remove(pid)
            self._render_canvas()

    def _update_player(self, pid, x_px, y_px):
        norm_x = max(0.0, min(1.0, x_px / self.canvas_w))
        norm_y = max(0.0, min(1.0, y_px / self.canvas_h))
        self.players[pid]['x'] = norm_x
        self.players[pid]['y'] = norm_y
        self.players[pid]['active'] = True
        self._render_canvas()

    def _on_left_down(self, event):
        pid = 2 if (event.state & 0x0001) else 0 # Shift key
        self._update_player(pid, event.x, event.y)

    def _on_left_drag(self, event):
        pid = 2 if (event.state & 0x0001) else 0
        self._update_player(pid, event.x, event.y)

    def _on_left_up(self, event):
        pid = 2 if (event.state & 0x0001) else 0
        self.players[pid]['active'] = False
        self._send_player_remove(pid)
        self._render_canvas()

    def _on_right_down(self, event):
        self._update_player(1, event.x, event.y)

    def _on_right_drag(self, event):
        self._update_player(1, event.x, event.y)

    def _on_right_up(self, event):
        self.players[1]['active'] = False
        self._send_player_remove(1)
        self._render_canvas()

    def _on_stomp(self, event):
        # Send quick stomp trigger
        pid = 0
        x = event.x / self.canvas_w
        y = event.y / self.canvas_h
        msg = build_osc_message("/player/stomp", [pid, float(x), float(y)])
        self.sock.sendto(msg, (self.host, self.port))

    def _send_player_remove(self, pid):
        msg = build_osc_message("/player/remove", [pid])
        try:
            self.sock.sendto(msg, (self.host, self.port))
        except Exception:
            pass

    def _render_canvas(self):
        self.canvas.delete("player_node")
        for pid, data in self.players.items():
            if not data['active']:
                continue
            px = data['x'] * self.canvas_w
            py = data['y'] * self.canvas_h
            r = 22
            # Glow circle
            self.canvas.create_oval(px - r - 8, py - r - 8, px + r + 8, py + r + 8, outline=data['color'], width=2, tags="player_node")
            # Inner filled circle
            self.canvas.create_oval(px - r, py - r, px + r, py + r, fill=data['color'], outline="#ffffff", width=2, tags="player_node")
            # Label
            self.canvas.create_text(px, py - 35, text=f"P{pid+1}", fill="#ffffff", font=("Helvetica", 10, "bold"), tags="player_node")

    def _sender_loop(self):
        """Broadcasts active players over OSC at 60 FPS"""
        step = 0
        while self.running:
            start_t = time.time()
            
            # If bot mode is on, advance bot positions
            if self.bot_active:
                step += 1
                for pid in [0, 1, 2]:
                    data = self.players[pid]
                    data['active'] = True
                    target = self.bot_targets[pid]
                    dx = target[0] - data['x']
                    dy = target[1] - data['y']
                    dist = math.hypot(dx, dy)
                    speed = 0.008 + (pid * 0.004)
                    if dist < 0.04:
                        self.bot_targets[pid] = [random.uniform(0.1, 0.9), random.uniform(0.1, 0.9)]
                    else:
                        data['x'] += (dx / dist) * speed
                        data['y'] += (dy / dist) * speed
                # Schedule UI update on main thread
                if step % 2 == 0:
                    self.root.after(0, self._render_canvas)

            # Send OSC packets for each active player
            for pid, data in self.players.items():
                if data['active']:
                    # Format 1: /player/update [id: int, x: float, y: float]
                    msg1 = build_osc_message("/player/update", [pid, float(data['x']), float(data['y'])])
                    # Format 2: /player/<id> [x: float, y: float] (indexed channel format)
                    msg2 = build_osc_message(f"/player/{pid}", [float(data['x']), float(data['y'])])
                    
                    try:
                        self.sock.sendto(msg1, (self.host, self.port))
                        self.sock.sendto(msg2, (self.host, self.port))
                        self.packets_sent += 2
                    except Exception:
                        pass
            
            # Update stats occasionally
            if step % 30 == 0:
                self.root.after(0, lambda: self.stat_label.config(text=f"Packets: {self.packets_sent}"))

            elapsed = time.time() - start_t
            sleep_t = max(0.001, (1.0 / 60.0) - elapsed)
            time.sleep(sleep_t)

    def close(self):
        self.running = False
        self.sock.close()


if __name__ == "__main__":
    root = tk.Tk()
    app = OSCMouseSimulator(root)
    def on_closing():
        app.close()
        root.destroy()
    root.protocol("WM_DELETE_WINDOW", on_closing)
    root.mainloop()
