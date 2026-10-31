extends Node2D

class_name GameLineJumper

signal score_awarded(pts: int, reason: String)
signal status_updated(text: String, color: Color)

enum State {
	COUNTDOWN,
	SWEEPING,
	CONTACT_PAUSE,
	ROUND_OVER
}

var current_state: State = State.COUNTDOWN
var state_timer: float = 2.0

# Playfield / Screen parameters
var vp_size: Vector2 = Vector2(1920, 1080)

# Line movement
enum SweepDirection { TOP_TO_BOTTOM, BOTTOM_TO_TOP, LEFT_TO_RIGHT, RIGHT_TO_LEFT }
var sweep_dir: SweepDirection = SweepDirection.TOP_TO_BOTTOM

var line_coord: float = 0.0 # Coordinate along sweep axis (Y for vertical, X for horizontal)
var line_speed: float = 280.0
var base_speed: float = 280.0
var line_thickness: float = 22.0

# Difficulty / Level
var current_level: int = 1
var total_jumps_cleared: int = 0
var passes_completed: int = 0

# Tagged players in current pass
var tagged_players: Array[int] = [] # Player IDs who were hit
var all_player_ids_seen: Array[int] = []

# Point of contact highlight
var contact_point: Vector2 = Vector2.ZERO
var contact_player_id: int = -1
var contact_timer: float = 0.0
var contact_duration: float = 1.4

# Visual animations
var laser_pulse: float = 0.0
var audio_manager: AudioManager = null

func setup(vp: Vector2, audio: AudioManager) -> void:
	vp_size = vp
	audio_manager = audio
	reset_game()

func reset_game() -> void:
	current_level = 1
	total_jumps_cleared = 0
	passes_completed = 0
	line_speed = base_speed
	tagged_players.clear()
	all_player_ids_seen.clear()
	_start_next_pass(true)

func _start_next_pass(is_first: bool = false) -> void:
	tagged_players.clear()
	laser_pulse = 0.0
	
	# Alternate sweep direction: Top->Down, Bottom->Up, Left->Right, Right->Left
	var dirs = [
		SweepDirection.TOP_TO_BOTTOM,
		SweepDirection.BOTTOM_TO_TOP,
		SweepDirection.LEFT_TO_RIGHT,
		SweepDirection.RIGHT_TO_LEFT
	]
	sweep_dir = dirs[passes_completed % dirs.size()]
	
	match sweep_dir:
		SweepDirection.TOP_TO_BOTTOM:
			line_coord = -line_thickness - 20.0
		SweepDirection.BOTTOM_TO_TOP:
			line_coord = vp_size.y + line_thickness + 20.0
		SweepDirection.LEFT_TO_RIGHT:
			line_coord = -line_thickness - 20.0
		SweepDirection.RIGHT_TO_LEFT:
			line_coord = vp_size.x + line_thickness + 20.0
			
	if is_first:
		current_state = State.COUNTDOWN
		state_timer = 2.0
		status_updated.emit("⚡ GET READY TO JUMP!", Color(1.0, 0.85, 0.2))
	else:
		current_state = State.SWEEPING
		state_timer = 0.0
		status_updated.emit("⚡ JUMP OVER THE LASER! (Speed Lvl %d)" % current_level, Color(0.2, 0.9, 1.0))

func update_game(delta: float, footprints: Dictionary) -> void:
	laser_pulse += delta * 8.0
	
	# Track all active player IDs
	for pid in footprints:
		if not all_player_ids_seen.has(pid):
			all_player_ids_seen.append(pid)
			
	match current_state:
		State.COUNTDOWN:
			state_timer -= delta
			var sec = int(ceil(state_timer))
			status_updated.emit("⚡ GET READY! %d..." % max(1, sec), Color(1.0, 0.85, 0.2))
			if state_timer <= 0.0:
				current_state = State.SWEEPING
				status_updated.emit("⚡ JUMP! (Speed Lvl %d)" % current_level, Color(0.2, 0.95, 1.0))
				
		State.SWEEPING:
			_update_sweeping(delta, footprints)
			
		State.CONTACT_PAUSE:
			contact_timer += delta
			state_timer -= delta
			if state_timer <= 0.0:
				# Highlight finished, resume sweeping!
				current_state = State.SWEEPING
				status_updated.emit("⚡ RESUMING LASER SWEEP!", Color(0.2, 0.95, 1.0))
				
		State.ROUND_OVER:
			state_timer -= delta
			if state_timer <= 0.0:
				_start_next_pass(false)
				
	queue_redraw()

func _update_sweeping(delta: float, footprints: Dictionary) -> void:
	var move_step = line_speed * delta
	
	match sweep_dir:
		SweepDirection.TOP_TO_BOTTOM:
			line_coord += move_step
			if line_coord > vp_size.y + line_thickness + 30.0:
				_on_pass_complete(footprints)
				return
		SweepDirection.BOTTOM_TO_TOP:
			line_coord -= move_step
			if line_coord < -line_thickness - 30.0:
				_on_pass_complete(footprints)
				return
		SweepDirection.LEFT_TO_RIGHT:
			line_coord += move_step
			if line_coord > vp_size.x + line_thickness + 30.0:
				_on_pass_complete(footprints)
				return
		SweepDirection.RIGHT_TO_LEFT:
			line_coord -= move_step
			if line_coord < -line_thickness - 30.0:
				_on_pass_complete(footprints)
				return
				
	# Check collision with active player feet
	for pid in footprints:
		var foot: PlayerFootprint = footprints[pid]
		
		# Skip if player is already out this pass
		if tagged_players.has(pid):
			continue
			
		# AIRBORNE CHECK: If the player jumped, their foot is NOT on the floor!
		if not foot.is_on_ground():
			continue
			
		var foot_pos = foot.global_position
		var hit_detected = false
		var hit_point = foot_pos
		
		match sweep_dir:
			SweepDirection.TOP_TO_BOTTOM, SweepDirection.BOTTOM_TO_TOP:
				var dist_y = absf(foot_pos.y - line_coord)
				if dist_y <= (foot.foot_radius * 0.85 + line_thickness * 0.5):
					hit_detected = true
					hit_point = Vector2(foot_pos.x, line_coord)
			SweepDirection.LEFT_TO_RIGHT, SweepDirection.RIGHT_TO_LEFT:
				var dist_x = absf(foot_pos.x - line_coord)
				if dist_x <= (foot.foot_radius * 0.85 + line_thickness * 0.5):
					hit_detected = true
					hit_point = Vector2(line_coord, foot_pos.y)
					
		if hit_detected:
			_trigger_contact(pid, hit_point, foot)
			return

func _trigger_contact(pid: int, hit_pt: Vector2, _foot: PlayerFootprint) -> void:
	tagged_players.append(pid)
	contact_point = hit_pt
	contact_player_id = pid
	contact_timer = 0.0
	state_timer = contact_duration
	current_state = State.CONTACT_PAUSE
	
	if audio_manager:
		audio_manager.play_zap()
		
	status_updated.emit("💥 CONTACT! Player %d is OUT! Resuming..." % (pid + 1), Color(1.0, 0.25, 0.2))

func _on_pass_complete(footprints: Dictionary) -> void:
	passes_completed += 1
	
	# Determine who survived the pass
	var surviving_players = 0
	for pid in footprints:
		if not tagged_players.has(pid):
			surviving_players += 1
			total_jumps_cleared += 1
			
	if surviving_players > 0:
		var pts = surviving_players * 50
		score_awarded.emit(pts, "JUMP CLEARED!")
		if audio_manager:
			audio_manager.play_jump_pass()
		status_updated.emit("🎉 PASS CLEARED! +%d PTS! Next pass..." % pts, Color(0.2, 1.0, 0.4))
	else:
		if audio_manager:
			audio_manager.play_buzzer()
		status_updated.emit("⚡ ALL TAGGED! Resetting players for next pass...", Color(1.0, 0.4, 0.2))
		
	# Increase speed every 2 passes
	if passes_completed % 2 == 0 and current_level < 8:
		current_level += 1
		line_speed = base_speed * (1.0 + float(current_level - 1) * 0.16)
		
	current_state = State.ROUND_OVER
	state_timer = 1.6

func _draw() -> void:
	# 1. Draw playfield boundary indicators
	_draw_boundary_guides()
	
	# 2. Draw moving laser line if active
	if current_state == State.SWEEPING or current_state == State.CONTACT_PAUSE or current_state == State.COUNTDOWN:
		_draw_laser_line()
		
	# 3. Highlight point of contact
	if current_state == State.CONTACT_PAUSE or (contact_timer > 0.0 and contact_timer < contact_duration + 0.3):
		_draw_contact_highlight()

func _draw_boundary_guides() -> void:
	# Subtle floor laser tracks at edges
	var border_col = Color(0.15, 0.35, 0.65, 0.25)
	draw_rect(Rect2(0, 0, vp_size.x, vp_size.y), border_col, false, 3.0)

func _draw_laser_line() -> void:
	var pulse_bright = 0.8 + sin(laser_pulse) * 0.2
	var base_col = Color(0.0, 0.9, 1.0) # Laser cyan
	if current_level >= 4:
		base_col = Color(1.0, 0.35, 0.1) # Super heated laser orange
	if current_state == State.CONTACT_PAUSE:
		base_col = Color(1.0, 0.15, 0.15) # Warning contact red
		
	var is_horizontal = (sweep_dir == SweepDirection.TOP_TO_BOTTOM or sweep_dir == SweepDirection.BOTTOM_TO_TOP)
	
	var p1: Vector2
	var p2: Vector2
	
	if is_horizontal:
		p1 = Vector2(0, line_coord)
		p2 = Vector2(vp_size.x, line_coord)
	else:
		p1 = Vector2(line_coord, 0)
		p2 = Vector2(line_coord, vp_size.y)
		
	# A. Wide danger aura glow
	var aura_col = Color(base_col.r, base_col.g, base_col.b, 0.16 * pulse_bright)
	draw_line(p1, p2, aura_col, line_thickness * 3.2)
	
	# B. Mid energy beam
	var mid_col = Color(base_col.r, base_col.g, base_col.b, 0.75 * pulse_bright)
	draw_line(p1, p2, mid_col, line_thickness)
	
	# C. Core white hot laser filament
	draw_line(p1, p2, Color(1.0, 1.0, 1.0, 0.95), line_thickness * 0.35)
	
	# D. Animated direction arrows along the beam
	var num_arrows = 9
	var arrow_dir = Vector2.ZERO
	match sweep_dir:
		SweepDirection.TOP_TO_BOTTOM: arrow_dir = Vector2(0, 1)
		SweepDirection.BOTTOM_TO_TOP: arrow_dir = Vector2(0, -1)
		SweepDirection.LEFT_TO_RIGHT: arrow_dir = Vector2(1, 0)
		SweepDirection.RIGHT_TO_LEFT: arrow_dir = Vector2(-1, 0)
		
	for i in range(1, num_arrows):
		var frac = float(i) / float(num_arrows)
		var center_pt = p1.lerp(p2, frac)
		var offset_pt = center_pt + arrow_dir * (14.0 + sin(laser_pulse + float(i)) * 4.0)
		
		# Draw chevron arrow
		var perp = Vector2(-arrow_dir.y, arrow_dir.x) * 12.0
		var a1 = offset_pt - arrow_dir * 8.0 + perp
		var a2 = offset_pt
		var a3 = offset_pt - arrow_dir * 8.0 - perp
		draw_line(a1, a2, Color(1, 1, 1, 0.75), 3.0)
		draw_line(a2, a3, Color(1, 1, 1, 0.75), 3.0)

func _draw_contact_highlight() -> void:
	var progress = clampf(contact_timer / contact_duration, 0.0, 1.0)
	var fade = 1.0 - progress
	
	# 1. Giant impact shockwave ring
	var shock_radius = 40.0 + (progress * 130.0)
	var shock_col = Color(1.0, 0.2, 0.1, fade * 0.9)
	draw_arc(contact_point, shock_radius, 0.0, TAU, 36, shock_col, 5.0, true)
	
	# 2. Outer warning dashed ring
	var ring_col = Color(1.0, 0.8, 0.1, fade * 0.8)
	draw_arc(contact_point, 75.0, 0.0, TAU, 28, ring_col, 3.0, true)
	
	# 3. Bright crosshair at exact point of contact
	var cross_col = Color(1.0, 1.0, 1.0, fade)
	var cross_size = 28.0
	draw_line(contact_point + Vector2(-cross_size, 0), contact_point + Vector2(cross_size, 0), cross_col, 4.0)
	draw_line(contact_point + Vector2(0, -cross_size), contact_point + Vector2(0, cross_size), cross_col, 4.0)
	draw_circle(contact_point, 9.0, Color(1.0, 0.2, 0.2, fade))
	
	# 4. Radiating electric spark lines
	var num_sparks = 10
	for i in range(num_sparks):
		var ang = (float(i) / float(num_sparks)) * TAU + (laser_pulse * 0.5)
		var dir = Vector2(cos(ang), sin(ang))
		var r1 = 30.0 + sin(contact_timer * 20.0 + float(i)) * 10.0
		var r2 = r1 + 25.0
		draw_line(contact_point + dir * r1, contact_point + dir * r2, Color(1.0, 0.9, 0.2, fade), 3.0)
