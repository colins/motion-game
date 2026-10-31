extends Node2D

class_name GameCircleScramble

signal score_awarded(pts: int, reason: String)
signal status_updated(text: String, color: Color)
signal circle_count_changed(new_count: int)

enum State {
	PRE_ROUND,
	ACTIVE,
	SUCCESS_PAUSE,
	FAILED_PAUSE
}

var current_state: State = State.PRE_ROUND
var state_timer: float = 1.5

# Configurable Circle Count (2 to 6)
var circle_count: int = 4
var round_duration: float = 8.0
var round_timer: float = 8.0
var rounds_cleared: int = 0

# Circle Class Definition
class SpotCircle:
	var id: int
	var pos: Vector2
	var radius: float = 95.0
	var base_color: Color
	var claimed_by_pid: int = -1 # -1 = vacant
	var claim_time: float = 0.0
	var pulse_offset: float = 0.0

var circles: Array[SpotCircle] = []
var vp_size: Vector2 = Vector2(1920, 1080)
var audio_manager: AudioManager = null
var tick_timer: float = 0.0

const CIRCLE_COLORS = [
	Color(0.15, 0.75, 1.0),  # Aqua Blue
	Color(1.0, 0.45, 0.15),  # Radiant Orange
	Color(0.2, 0.95, 0.4),   # Lime Green
	Color(0.95, 0.2, 0.75),  # Hot Pink
	Color(1.0, 0.85, 0.1),   # Golden Yellow
	Color(0.7, 0.4, 1.0)     # Neon Violet
]

func setup(vp: Vector2, audio: AudioManager) -> void:
	vp_size = vp
	audio_manager = audio
	reset_game()

func reset_game() -> void:
	rounds_cleared = 0
	_start_new_round()

func set_circle_count(new_count: int) -> void:
	var clamped = clamp(new_count, 2, 6)
	if circle_count != clamped:
		circle_count = clamped
		circle_count_changed.emit(circle_count)
		_start_new_round()

func adjust_circle_count(delta_val: int) -> void:
	set_circle_count(circle_count + delta_val)

func _start_new_round() -> void:
	circles.clear()
	round_timer = round_duration
	tick_timer = 0.0
	
	# Spawn well-spaced circles
	var margin = 160.0
	var min_dist = max(240.0, 360.0 - float(circle_count) * 20.0)
	
	for i in range(circle_count):
		var spot = SpotCircle.new()
		spot.id = i + 1
		spot.radius = 92.0
		spot.base_color = CIRCLE_COLORS[i % CIRCLE_COLORS.size()]
		spot.claimed_by_pid = -1
		spot.pulse_offset = randf() * TAU
		
		# Find well-separated position
		var best_pos = Vector2.ZERO
		var best_clearance = -1.0
		for attempt in range(40):
			var candidate = Vector2(
				randf_range(margin, vp_size.x - margin),
				randf_range(margin + 50.0, vp_size.y - margin)
			)
			var min_d = 999999.0
			for other in circles:
				var d = candidate.distance_to(other.pos)
				if d < min_d:
					min_d = d
					
			if circles.is_empty() or min_d >= min_dist:
				best_pos = candidate
				break
			elif min_d > best_clearance:
				best_clearance = min_d
				best_pos = candidate
				
		spot.pos = best_pos
		circles.append(spot)
		
	current_state = State.ACTIVE
	status_updated.emit("🏃 RUN TO A CIRCLE! (%d Circles)" % circle_count, Color(1.0, 0.85, 0.2))

func update_game(delta: float, footprints: Dictionary) -> void:
	match current_state:
		State.PRE_ROUND:
			state_timer -= delta
			if state_timer <= 0.0:
				_start_new_round()
				
		State.ACTIVE:
			_update_active(delta, footprints)
			
		State.SUCCESS_PAUSE:
			state_timer -= delta
			if state_timer <= 0.0:
				_start_new_round()
				
		State.FAILED_PAUSE:
			state_timer -= delta
			if state_timer <= 0.0:
				_start_new_round()
				
	queue_redraw()

func _update_active(delta: float, footprints: Dictionary) -> void:
	round_timer -= delta
	
	# Audible countdown ticks
	tick_timer -= delta
	var tick_interval = 1.0 if round_timer > 3.0 else 0.4
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		if audio_manager and round_timer <= 5.0 and round_timer > 0.0:
			audio_manager.play_tick()
			
	# Check footprint occupancy for each circle
	# Rule: Each kid can only claim 1 circle; each circle can only have 1 kid.
	var claimed_pids: Dictionary = {} # pid -> circle_id
	var total_claimed = 0
	
	for circle in circles:
		var previously_claimed_by = circle.claimed_by_pid
		circle.claimed_by_pid = -1
		
		# Check if any standing player is within circle bounds
		for pid in footprints:
			var foot: PlayerFootprint = footprints[pid]
			if not foot.is_on_ground():
				continue # Airborne kids cannot claim circles
				
			if claimed_pids.has(pid):
				continue # This kid already claimed another circle!
				
			var dist = circle.pos.distance_to(foot.global_position)
			if dist <= (circle.radius + foot.foot_radius * 0.5):
				circle.claimed_by_pid = pid
				claimed_pids[pid] = circle.id
				
				# If newly claimed, trigger ding audio!
				if previously_claimed_by != pid:
					circle.claim_time = Time.get_ticks_msec() / 1000.0
					if audio_manager:
						audio_manager.play_ding()
				break
				
		if circle.claimed_by_pid != -1:
			total_claimed += 1
			
	# Update status display
	status_updated.emit("⏱️ %.1fs  |  CLAIMED: %d / %d CIRCLES" % [max(0.0, round_timer), total_claimed, circle_count], 
		Color(0.2, 1.0, 0.4) if total_claimed == circle_count else (Color(1.0, 0.3, 0.2) if round_timer < 2.5 else Color(1.0, 0.85, 0.2)))

	# 1. Win condition: ALL circles occupied!
	if total_claimed == circle_count:
		_on_round_success()
		return
		
	# 2. Timeout condition: Timer runs out
	if round_timer <= 0.0:
		_on_round_failed(total_claimed)
		return

func _on_round_success() -> void:
	rounds_cleared += 1
	var time_bonus = int(round_timer * 15.0)
	var pts = (circle_count * 80) + time_bonus
	score_awarded.emit(pts, "ALL CIRCLES FOUND!")
	
	if audio_manager:
		audio_manager.play_fanfare()
		
	status_updated.emit("🎉 SUCCESS! ALL %d CIRCLES CLAIMED! +%d PTS" % [circle_count, pts], Color(0.2, 1.0, 0.4))
	current_state = State.SUCCESS_PAUSE
	state_timer = 2.0

func _on_round_failed(claimed_count: int) -> void:
	if audio_manager:
		audio_manager.play_buzzer()
		
	status_updated.emit("⏰ TIME'S UP! (Only %d of %d circles occupied) Next round..." % [claimed_count, circle_count], Color(1.0, 0.35, 0.2))
	current_state = State.FAILED_PAUSE
	state_timer = 2.2

func _draw() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	
	# Draw Timer bar across top
	if current_state == State.ACTIVE:
		var bar_w = vp_size.x * 0.7
		var bar_h = 10.0
		var bar_x = (vp_size.x - bar_w) * 0.5
		var bar_y = 65.0
		var frac = clampf(round_timer / round_duration, 0.0, 1.0)
		
		# Background bar
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.1, 0.15, 0.25, 0.6), true)
		# Active fill
		var timer_col = Color(0.2, 0.9, 0.4)
		if frac < 0.35:
			timer_col = Color(1.0, 0.25, 0.2)
		elif frac < 0.65:
			timer_col = Color(1.0, 0.8, 0.1)
		draw_rect(Rect2(bar_x, bar_y, bar_w * frac, bar_h), timer_col, true)
		
	# Draw all circles
	for circle in circles:
		var is_claimed = (circle.claimed_by_pid != -1)
		var pulse = sin(now * 4.0 + circle.pulse_offset) * 6.0
		var cur_r = circle.radius + pulse
		
		var draw_col = circle.base_color
		if is_claimed:
			draw_col = Color(0.1, 1.0, 0.45) # Bright energetic green check
			
		# Outer glowing ring
		var aura_col = Color(draw_col.r, draw_col.g, draw_col.b, 0.22 if not is_claimed else 0.45)
		draw_circle(circle.pos, cur_r + 18.0, aura_col)
		
		# Filled interior pad
		var body_col = Color(draw_col.r, draw_col.g, draw_col.b, 0.28 if not is_claimed else 0.55)
		draw_circle(circle.pos, cur_r, body_col)
		
		# Thick boundary ring
		draw_arc(circle.pos, cur_r, 0.0, TAU, 48, draw_col, 5.0, true)
		
		# Inner rotating dashed arc
		var rot = now * 1.5 + circle.pulse_offset
		draw_arc(circle.pos, cur_r * 0.75, rot, rot + PI * 0.75, 24, Color(1, 1, 1, 0.6), 3.0, true)
		draw_arc(circle.pos, cur_r * 0.75, rot + PI, rot + PI * 1.75, 24, Color(1, 1, 1, 0.6), 3.0, true)
		
		if is_claimed:
			# Draw giant glowing CHECKMARK in center
			var p_mid = circle.pos + Vector2(0, 4)
			var pt1 = p_mid + Vector2(-22, -2)
			var pt2 = p_mid + Vector2(-6, 18)
			var pt3 = p_mid + Vector2(24, -18)
			draw_line(pt1, pt2, Color.WHITE, 7.0)
			draw_line(pt2, pt3, Color.WHITE, 7.0)
			
			# Player claim indicator text / dot
			draw_circle(circle.pos + Vector2(0, -cur_r * 0.55), 10.0, Color.WHITE)
		else:
			# Draw Circle Spot Number (#1, #2, #3...)
			draw_circle(circle.pos, 16.0, Color(1, 1, 1, 0.85))
			draw_circle(circle.pos, 13.0, Color(0.1, 0.1, 0.15))
			draw_circle(circle.pos, 5.0, draw_col)
