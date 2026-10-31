extends Node

signal player_updated(id: int, screen_pos: Vector2)
signal raw_player_updated(id: int, raw_norm: Vector2)
signal player_removed(id: int)
signal player_stomped(id: int, screen_pos: Vector2)

@export var listen_port: int = 9000
@export var player_timeout_sec: float = 0.6

var udp: PacketPeerUDP = PacketPeerUDP.new()
var active_players: Dictionary = {} # id -> { "pos": Vector2, "last_seen": float }
var mouse_p0_active: bool = false
var mouse_p1_active: bool = false

var calibration = preload("res://scripts/calibration.gd").new()

func _ready() -> void:
	add_child(calibration)
	# Bind to all network interfaces ("*") to accept packets from both local tools and the Raspberry Pi
	var err = udp.bind(listen_port, "*")
	if err != OK:
		# Fallback to localhost if all interfaces fails
		err = udp.bind(listen_port, "127.0.0.1")
	
	if err == OK:
		print("[OSCReceiver] Listening for OSC on UDP port %d (All interfaces)" % listen_port)
	else:
		push_error("[OSCReceiver] Failed to bind to UDP port %d (Error %d)" % [listen_port, err])

func _process(_delta: float) -> void:
	# 1. Process all incoming UDP packets
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		_parse_osc_packet(packet)
	
	# 2. Check for player timeouts (kids walking off the interactive mat)
	var now = Time.get_ticks_msec() / 1000.0
	var to_remove = []
	for id in active_players:
		# Don't timeout if currently being held with mouse debug
		if id == 0 and mouse_p0_active:
			continue
		if id == 1 and mouse_p1_active:
			continue
			
		if now - active_players[id]["last_seen"] > player_timeout_sec:
			to_remove.append(id)
			
	for id in to_remove:
		active_players.erase(id)
		player_removed.emit(id)

func _parse_osc_packet(data: PackedByteArray) -> void:
	if data.size() < 4:
		return
		
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = true
	buffer.data_array = data
	
	var addr = _read_osc_string(buffer)
	if addr.is_empty():
		return
		
	var tags = _read_osc_string(buffer)
	var args = []
	if not tags.is_empty() and tags.begins_with(","):
		for i in range(1, tags.length()):
			var t = tags[i]
			if t == "f":
				args.append(buffer.get_float())
			elif t == "i":
				args.append(buffer.get_32())
			elif t == "s":
				args.append(_read_osc_string(buffer))
				
	_handle_osc_message(addr, args)

func _read_osc_string(buffer: StreamPeerBuffer) -> String:
	var chars = []
	while buffer.get_position() < buffer.get_size():
		var b = buffer.get_u8()
		if b == 0:
			break
		chars.append(b)
	# Align to 4 bytes
	var rem = buffer.get_position() % 4
	if rem != 0:
		var pad = 4 - rem
		buffer.seek(buffer.get_position() + pad)
	return PackedByteArray(chars).get_string_from_utf8()

func _handle_osc_message(address: String, args: Array) -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var now = Time.get_ticks_msec() / 1000.0
	
	# Format 1: /player/update [id, x, y]
	if address == "/player/update" and args.size() >= 3:
		var pid = int(args[0])
		var raw_norm = Vector2(clampf(float(args[1]), 0.0, 1.0), clampf(float(args[2]), 0.0, 1.0))
		var screen_pos = calibration.map_to_screen(raw_norm, vp_size)
		active_players[pid] = { "pos": screen_pos, "last_seen": now }
		raw_player_updated.emit(pid, raw_norm)
		player_updated.emit(pid, screen_pos)
		
	# Format 2: /player/<id> [x, y] (Compact channel format)
	elif address.begins_with("/player/") and args.size() >= 2:
		var sub = address.substr(8)
		if sub.is_valid_int():
			var pid = sub.to_int()
			var raw_norm = Vector2(clampf(float(args[0]), 0.0, 1.0), clampf(float(args[1]), 0.0, 1.0))
			var screen_pos = calibration.map_to_screen(raw_norm, vp_size)
			active_players[pid] = { "pos": screen_pos, "last_seen": now }
			raw_player_updated.emit(pid, raw_norm)
			player_updated.emit(pid, screen_pos)
			
	# Format 3: /player/remove [id]
	elif address == "/player/remove" and args.size() >= 1:
		var pid = int(args[0])
		if active_players.has(pid):
			active_players.erase(pid)
			player_removed.emit(pid)
			
	# Format 4: /player/stomp [id, x, y]
	elif address == "/player/stomp" and args.size() >= 3:
		var pid = int(args[0])
		var raw_norm = Vector2(clampf(float(args[1]), 0.0, 1.0), clampf(float(args[2]), 0.0, 1.0))
		var screen_pos = calibration.map_to_screen(raw_norm, vp_size)
		player_stomped.emit(pid, screen_pos)

# Direct In-Engine Mouse Debugging (Works on macOS without running python tool)
func _unhandled_input(event: InputEvent) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_p0_active = event.pressed
			if event.pressed:
				active_players[0] = { "pos": event.position, "last_seen": now }
				player_updated.emit(0, event.position)
				if event.double_click:
					player_stomped.emit(0, event.position)
			else:
				active_players.erase(0)
				player_removed.emit(0)
				
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_p1_active = event.pressed
			if event.pressed:
				active_players[1] = { "pos": event.position, "last_seen": now }
				player_updated.emit(1, event.position)
			else:
				active_players.erase(1)
				player_removed.emit(1)
				
	elif event is InputEventMouseMotion:
		if mouse_p0_active:
			active_players[0] = { "pos": event.position, "last_seen": now }
			player_updated.emit(0, event.position)
		elif mouse_p1_active:
			active_players[1] = { "pos": event.position, "last_seen": now }
			player_updated.emit(1, event.position)
