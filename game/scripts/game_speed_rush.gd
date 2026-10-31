extends Node2D

class_name GameSpeedRush

signal score_awarded(pts: int, reason: String)
signal status_updated(text: String, color: Color)
signal bubble_popped_fx(pos: Vector2, radius: float, color: Color, score: int, is_mega: bool, theme_id: int)

enum State {
	PRE_ROUND,
	ACTIVE,
	ROUND_CLEARED_PAUSE,
	GAME_OVER_PAUSE
}

var current_state: State = State.PRE_ROUND
var state_timer: float = 1.5

const TARGET_COUNT: int = 6
var current_round: int = 1
var round_duration: float = 20.0
var round_timer: float = 20.0
var targets_remaining: int = 6

var vp_size: Vector2 = Vector2(1920, 1080)
var audio_manager: AudioManager = null
var current_theme: Bubble.HolidayTheme = Bubble.HolidayTheme.BUBBLES
var bubble_scene: PackedScene = preload("res://scenes/bubble.tscn")

var targets_container: Node2D = null
var tick_timer: float = 0.0

func setup(vp: Vector2, audio: AudioManager, theme: Bubble.HolidayTheme) -> void:
	vp_size = vp
	audio_manager = audio
	current_theme = theme
	
	targets_container = Node2D.new()
	targets_container.name = "SpeedTargetsContainer"
	add_child(targets_container)
	
	reset_game()

func reset_game() -> void:
	current_round = 1
	_start_round(current_round)

func set_theme(theme: Bubble.HolidayTheme) -> void:
	current_theme = theme
	if targets_container:
		for b in targets_container.get_children():
			if b is Bubble:
				b.set_theme(current_theme)

func _get_speed_for_round(round_num: int) -> float:
	# Round 1: 240, Round 2: 320, Round 3: 410, Round 4: 510, Round 5: 620...
	return 240.0 + float(round_num - 1) * 90.0

func _get_timer_for_round(round_num: int) -> float:
	# Decreasing time window: 20s, 18s, 16s, 15s, 14s (min 12s)
	return max(12.0, 20.0 - float(round_num - 1) * 2.0)

func _start_round(round_num: int) -> void:
	current_round = round_num
	round_duration = _get_timer_for_round(current_round)
	round_timer = round_duration
	targets_remaining = TARGET_COUNT
	tick_timer = 0.0
	
	# Clear existing targets
	for child in targets_container.get_children():
		targets_container.remove_child(child)
		child.queue_free()
		
	var speed = _get_speed_for_round(current_round)
	
	# Spawn exactly 6 bouncing targets
	for i in range(TARGET_COUNT):
		var b = bubble_scene.instantiate() as Bubble
		b.setup_random(vp_size, current_theme)
		b.bounce_mode = true
		
		# Give diverse high-speed diagonal directions
		var angle = (float(i) / float(TARGET_COUNT)) * TAU + randf_range(-0.3, 0.3)
		b.velocity = Vector2(cos(angle), sin(angle)) * speed
		
		# Position well inside boundaries
		b.global_position = Vector2(
			randf_range(150.0, vp_size.x - 150.0),
			randf_range(160.0, vp_size.y - 150.0)
		)
		
		b.popped.connect(_on_target_popped)
		targets_container.add_child(b)
		
	current_state = State.ACTIVE
	status_updated.emit("⚡ ROUND %d: POP ALL 6 TARGETS! (Speed: %d px/s)" % [current_round, int(speed)], Color(1.0, 0.85, 0.2))

func _on_target_popped(pop_pos: Vector2, radius: float, color: Color, score: int, is_mega: bool, theme_id: int) -> void:
	targets_remaining = max(0, targets_remaining - 1)
	
	var round_multiplier = 1 + (current_round - 1) * 2
	var final_score = score * round_multiplier
	score_awarded.emit(final_score, "TARGET POPPED!")
	bubble_popped_fx.emit(pop_pos, radius, color, final_score, is_mega, theme_id)
	
	if audio_manager:
		audio_manager.play_pop(is_mega, theme_id)
		
	if targets_remaining == 0:
		_on_round_cleared()

func _on_round_cleared() -> void:
	var time_bonus = int(round_timer * 25.0)
	var clear_bonus = current_round * 100
	var total_bonus = time_bonus + clear_bonus
	score_awarded.emit(total_bonus, "ROUND CLEARED!")
	
	if audio_manager:
		audio_manager.play_fanfare()
		
	current_state = State.ROUND_CLEARED_PAUSE
	state_timer = 2.0
	status_updated.emit("🌟 ROUND %d CLEARED! +%d BONUS! GET READY FOR ROUND %d (FASTER!)" % [
		current_round, total_bonus, current_round + 1
	], Color(0.2, 1.0, 0.4))

func _on_round_failed() -> void:
	if audio_manager:
		audio_manager.play_buzzer()
		
	current_state = State.GAME_OVER_PAUSE
	state_timer = 3.0
	status_updated.emit("⏰ TIME'S UP! Final Round: %d | (Press R or stomping to retry)" % current_round, Color(1.0, 0.3, 0.2))

func update_game(delta: float, footprints: Dictionary) -> void:
	match current_state:
		State.PRE_ROUND:
			state_timer -= delta
			if state_timer <= 0.0:
				_start_round(current_round)
				
		State.ACTIVE:
			_update_active(delta, footprints)
			
		State.ROUND_CLEARED_PAUSE:
			state_timer -= delta
			if state_timer <= 0.0:
				_start_round(current_round + 1)
				
		State.GAME_OVER_PAUSE:
			state_timer -= delta
			if state_timer <= 0.0:
				# Restart from round 1
				_start_round(1)
				
	queue_redraw()

func _update_active(delta: float, footprints: Dictionary) -> void:
	round_timer -= delta
	
	# Audible ticking when time is low
	tick_timer -= delta
	var tick_interval = 1.0 if round_timer > 4.0 else 0.35
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		if audio_manager and round_timer <= 6.0 and round_timer > 0.0:
			audio_manager.play_tick()
			
	# Check collisions with active player feet
	for pid in footprints:
		var foot: PlayerFootprint = footprints[pid]
		for bubble_node in targets_container.get_children():
			if bubble_node is Bubble:
				bubble_node.check_collision(foot.global_position, foot.foot_radius)
				
	# Update HUD status
	status_updated.emit("⏱️ %.1fs  |  ROUND %d  |  REMAINING: %d / 6" % [
		max(0.0, round_timer), current_round, targets_remaining
	], Color(1.0, 0.3, 0.2) if round_timer < 4.0 else (Color(0.2, 1.0, 0.4) if targets_remaining <= 2 else Color(1.0, 0.85, 0.2)))

	if round_timer <= 0.0 and targets_remaining > 0:
		_on_round_failed()

func _draw() -> void:
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
		if frac < 0.3:
			timer_col = Color(1.0, 0.2, 0.15)
		elif frac < 0.6:
			timer_col = Color(1.0, 0.75, 0.1)
		draw_rect(Rect2(bar_x, bar_y, bar_w * frac, bar_h), timer_col, true)
