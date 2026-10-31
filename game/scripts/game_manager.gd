extends Node2D

enum GameMode {
	BUBBLE_POP = 0,
	LINE_JUMPER = 1,
	CIRCLE_SCRAMBLE = 2,
	SPEED_RUSH = 3
}

# Current Active Game Mode
var current_game_mode: GameMode = GameMode.BUBBLE_POP
var current_theme: Bubble.HolidayTheme = Bubble.HolidayTheme.BUBBLES

# Child Game Modules
const GameLineJumperClass = preload("res://scripts/game_line_jumper.gd")
const GameCircleScrambleClass = preload("res://scripts/game_circle_scramble.gd")
const GameSpeedRushClass = preload("res://scripts/game_speed_rush.gd")

var line_jumper: Node2D = null
var circle_scramble: Node2D = null
var speed_rush: Node2D = null

# Bubble Pop Specifics
@export var max_bubbles: int = 24
@export var bubble_scene: PackedScene = preload("res://scenes/bubble.tscn")
@export var pop_effect_scene: PackedScene = preload("res://scenes/pop_effect.tscn")
@export var footprint_scene: PackedScene = preload("res://scenes/player_footprint.tscn")

# Scene Nodes
@onready var background: ColorRect = $Background
@onready var ambient_particles: CPUParticles2D = $AmbientParticles
@onready var game_container: Node2D = $GameContainer
@onready var bubble_container: Node2D = $BubbleContainer
@onready var footprint_container: Node2D = $FootprintContainer
@onready var fx_container: Node2D = $FXContainer
@onready var osc_receiver = $OSCReceiver
@onready var audio_manager: AudioManager = $AudioManager
@onready var calibration_overlay = $CalibrationOverlay

# HUD UI Nodes
@onready var mode_label: Label = $UI/TopBar/MarginContainer/HBox/ModeLabel
@onready var score_label: Label = $UI/TopBar/MarginContainer/HBox/ScoreLabel
@onready var status_label: Label = $UI/TopBar/MarginContainer/HBox/StatusLabel
@onready var combo_label: Label = $UI/TopBar/MarginContainer/HBox/ComboLabel
@onready var theme_label: Label = $UI/TopBar/MarginContainer/HBox/ThemeLabel
@onready var players_label: Label = $UI/TopBar/MarginContainer/HBox/PlayersLabel
@onready var help_label: Label = $UI/TopBar/MarginContainer/HBox/HelpLabel

# Score & Combo stats
var total_score: int = 0
var total_popped: int = 0
var combo_streak: int = 0
var last_pop_time: float = 0.0
var combo_window_sec: float = 1.2

var footprints: Dictionary = {} # id -> PlayerFootprint
var config_screen: CanvasLayer

func _ready() -> void:
	if not InputMap.has_action("toggle_config_screen"):
		InputMap.add_action("toggle_config_screen")
		var config_key := InputEventKey.new()
		config_key.physical_keycode = KEY_D
		InputMap.action_add_event("toggle_config_screen", config_key)
	config_screen = preload("res://scripts/config_screen.gd").new()
	config_screen.receiver = osc_receiver
	add_child(config_screen)
	set_jump_height(config_screen.jump_height)
	# Hook up OSC Receiver signals
	osc_receiver.player_updated.connect(_on_player_updated)
	osc_receiver.raw_player_updated.connect(_on_raw_player_updated)
	osc_receiver.player_removed.connect(_on_player_removed)
	osc_receiver.player_stomped.connect(_on_player_stomped)
	
	var vp = get_viewport_rect().size
	
	# Instantiate and wire up Game 2: Line Jumper
	line_jumper = GameLineJumperClass.new()
	line_jumper.setup(vp, audio_manager)
	line_jumper.score_awarded.connect(_on_module_score_awarded)
	line_jumper.status_updated.connect(_on_module_status_updated)
	game_container.add_child(line_jumper)
	line_jumper.visible = false
	
	# Instantiate and wire up Game 3: Circle Scramble
	circle_scramble = GameCircleScrambleClass.new()
	circle_scramble.setup(vp, audio_manager)
	circle_scramble.score_awarded.connect(_on_module_score_awarded)
	circle_scramble.status_updated.connect(_on_module_status_updated)
	circle_scramble.circle_count_changed.connect(_on_circle_count_changed)
	game_container.add_child(circle_scramble)
	circle_scramble.visible = false
	
	# Instantiate and wire up Game 4: Speed Rush
	speed_rush = GameSpeedRushClass.new()
	speed_rush.setup(vp, audio_manager, current_theme)
	speed_rush.score_awarded.connect(_on_module_score_awarded)
	speed_rush.status_updated.connect(_on_module_status_updated)
	speed_rush.bubble_popped_fx.connect(_on_speed_rush_popped_fx)
	game_container.add_child(speed_rush)
	speed_rush.visible = false
	
	# Initial start with Bubble Pop
	set_game_mode(GameMode.BUBBLE_POP)
	_apply_theme_to_world(false)
	_update_hud()

func _process(delta: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	
	# Reset combo streak if too much time elapsed between pops (in bubble / rush games)
	if combo_streak > 0 and now - last_pop_time > combo_window_sec:
		combo_streak = 0
		_update_hud()
		
	match current_game_mode:
		GameMode.BUBBLE_POP:
			_process_bubble_pop(delta)
		GameMode.LINE_JUMPER:
			if line_jumper:
				line_jumper.update_game(delta, footprints)
		GameMode.CIRCLE_SCRAMBLE:
			if circle_scramble:
				circle_scramble.update_game(delta, footprints)
		GameMode.SPEED_RUSH:
			if speed_rush:
				speed_rush.update_game(delta, footprints)

# ==============================================================================
# GAME MODE 1: BUBBLE POP
# ==============================================================================
func _process_bubble_pop(_delta: float) -> void:
	# Replenish bubbles if count drops below target
	var active_bubbles = bubble_container.get_child_count()
	if active_bubbles < max_bubbles:
		var vp = get_viewport_rect().size
		_spawn_bubble(vp)
		
	# Check collisions between all active kid footprints and bubbles
	for pid in footprints:
		var foot: PlayerFootprint = footprints[pid]
		for bubble_node in bubble_container.get_children():
			if bubble_node is Bubble:
				bubble_node.check_collision(foot.global_position, foot.foot_radius)

func _spawn_bubble(vp: Vector2) -> void:
	var b = bubble_scene.instantiate() as Bubble
	b.setup_random(vp, current_theme)
	b.popped.connect(_on_bubble_popped)
	bubble_container.add_child(b)

func _on_bubble_popped(pop_pos: Vector2, radius: float, color: Color, score: int, is_mega: bool, theme_id: int = 0) -> void:
	total_popped += 1
	combo_streak += 1
	last_pop_time = Time.get_ticks_msec() / 1000.0
	
	var multiplier = min(5, 1 + (combo_streak / 4))
	var pts = score * multiplier
	total_score += pts
	
	# 1. Play theme-specific procedural sound
	if audio_manager:
		audio_manager.play_pop(is_mega, theme_id)
	
	# 2. Spawn theme-specific particle explosion & score popup
	if fx_container and pop_effect_scene:
		var fx = pop_effect_scene.instantiate()
		fx_container.add_child(fx)
		fx.setup(pop_pos, radius, color, pts, theme_id)
	
	_update_hud()

# ==============================================================================
# SUB-MODULE SIGNALS & DISPATCH
# ==============================================================================
func _on_module_score_awarded(pts: int, reason: String) -> void:
	total_score += pts
	_update_hud()
	print("[Score] +%d pts (%s) | Total: %d" % [pts, reason, total_score])

func _on_module_status_updated(text: String, color: Color) -> void:
	if status_label:
		status_label.text = text
		status_label.modulate = color

func _on_circle_count_changed(new_count: int) -> void:
	_update_hud()
	print("[Scramble] Circle count changed to: ", new_count)

func _on_speed_rush_popped_fx(pop_pos: Vector2, radius: float, color: Color, score: int, is_mega: bool, theme_id: int) -> void:
	total_popped += 1
	if fx_container and pop_effect_scene:
		var fx = pop_effect_scene.instantiate()
		fx_container.add_child(fx)
		fx.setup(pop_pos, radius, color, score, theme_id)
	_update_hud()

# ==============================================================================
# GAME MODE SWITCHING
# ==============================================================================
func cycle_game_mode(next: bool = true) -> void:
	var mode_int = current_game_mode as int
	if next:
		mode_int = (mode_int + 1) % 4
	else:
		mode_int = (mode_int + 3) % 4
	set_game_mode(mode_int as GameMode)

func set_game_mode(mode: GameMode) -> void:
	current_game_mode = mode
	
	# 1. Toggle visibility and active status of each game container
	if bubble_container:
		bubble_container.visible = (current_game_mode == GameMode.BUBBLE_POP)
		if current_game_mode != GameMode.BUBBLE_POP:
			for b in bubble_container.get_children():
				b.queue_free()
		else:
			var vp = get_viewport_rect().size
			for i in range(max_bubbles):
				_spawn_bubble(vp)
				
	if line_jumper:
		line_jumper.visible = (current_game_mode == GameMode.LINE_JUMPER)
		if current_game_mode == GameMode.LINE_JUMPER:
			line_jumper.reset_game()
			
	if circle_scramble:
		circle_scramble.visible = (current_game_mode == GameMode.CIRCLE_SCRAMBLE)
		if current_game_mode == GameMode.CIRCLE_SCRAMBLE:
			circle_scramble.reset_game()
			
	if speed_rush:
		speed_rush.visible = (current_game_mode == GameMode.SPEED_RUSH)
		if current_game_mode == GameMode.SPEED_RUSH:
			speed_rush.set_theme(current_theme)
			speed_rush.reset_game()
			
	# Sound cue on game mode change
	if audio_manager:
		audio_manager.play_jump_pass()
		
	_apply_theme_to_world(true)
	_update_hud()
	print("[Mode] Switched Game Mode to: ", _get_game_mode_name(current_game_mode))

func _get_game_mode_name(mode: GameMode) -> String:
	match mode:
		GameMode.LINE_JUMPER: return "⚡ LINE JUMPER"
		GameMode.CIRCLE_SCRAMBLE: return "🎯 CIRCLE SCRAMBLE"
		GameMode.SPEED_RUSH: return "💥 SPEED RUSH"
		_: return "🫧 BUBBLE POP"

# ==============================================================================
# PLAYER FOOTPRINTS & OSC HANDLING
# ==============================================================================
func _on_player_updated(pid: int, screen_pos: Vector2) -> void:
	if config_screen and not config_screen.accepts_player(pid):
		return
	if not footprints.has(pid):
		var foot = footprint_scene.instantiate() as PlayerFootprint
		footprints[pid] = foot
		footprint_container.add_child(foot)
		foot.setup(pid, screen_pos)
		_update_hud()
	else:
		footprints[pid].set_target(screen_pos)

func set_jump_height(height: float) -> void:
	for foot in footprints.values():
		foot.jump_height = height

func apply_example_filter() -> void:
	for pid in footprints.keys():
		if not config_screen.accepts_player(int(pid)):
			_on_player_removed(int(pid))
	for pid in osc_receiver.active_players:
		if config_screen.accepts_player(int(pid)):
			_on_player_updated(int(pid), osc_receiver.active_players[pid].pos)

func _on_player_removed(pid: int) -> void:
	if footprints.has(pid):
		var foot = footprints[pid]
		footprints.erase(pid)
		
		# Smooth shrink out
		var tween = create_tween()
		tween.tween_property(foot, "scale", Vector2.ZERO, 0.2)
		tween.tween_callback(foot.queue_free)
		_update_hud()

func _on_player_stomped(pid: int, _screen_pos: Vector2) -> void:
	if footprints.has(pid):
		footprints[pid].trigger_stomp()

func _on_raw_player_updated(_pid: int, raw_norm: Vector2) -> void:
	if calibration_overlay and calibration_overlay.visible:
		calibration_overlay.set_latest_raw(raw_norm)

# Trigger a jump for the main debug/mouse player (ID 0)
func trigger_player_jump(pid: int = 0) -> void:
	if footprints.has(pid):
		footprints[pid].trigger_jump()
	else:
		# If mouse player hasn't moved yet, spawn foot and jump
		var mouse_pos = get_viewport().get_mouse_position()
		_on_player_updated(pid, mouse_pos)
		if footprints.has(pid):
			footprints[pid].trigger_jump()

# ==============================================================================
# THEME SWITCHING (Holiday Skins)
# ==============================================================================
func cycle_theme(next: bool = true) -> void:
	var theme_int = current_theme as int
	if next:
		theme_int = (theme_int + 1) % 4
	else:
		theme_int = (theme_int + 3) % 4
	set_theme(theme_int as Bubble.HolidayTheme)

func set_theme(new_theme: Bubble.HolidayTheme) -> void:
	if current_theme == new_theme:
		return
	current_theme = new_theme
	_apply_theme_to_world(true)
	if speed_rush:
		speed_rush.set_theme(current_theme)
	_update_hud()
	print("[Theme] Switched theme to: ", _get_theme_name(current_theme))

func _apply_theme_to_world(animate: bool = true) -> void:
	if not is_inside_tree():
		return
		
	# 1. Morph all active floating targets into the new holiday theme
	if bubble_container:
		for bubble_node in bubble_container.get_children():
			if bubble_node is Bubble:
				bubble_node.set_theme(current_theme)
				
	# 2. Update background ambiance & particles
	var target_bg_col: Color
	var target_part_col: Color
	var target_gravity: Vector2
	
	match current_theme:
		Bubble.HolidayTheme.GHOSTS:
			target_bg_col = Color(0.06, 0.03, 0.11, 1.0) # Midnight Spooky Purple
			target_part_col = Color(0.65, 0.35, 0.95, 0.32) # Eerie floating wisps
			target_gravity = Vector2(0, -22)
		Bubble.HolidayTheme.TURKEYS:
			target_bg_col = Color(0.10, 0.05, 0.02, 1.0) # Warm Autumn Harvest Bronze
			target_part_col = Color(0.95, 0.55, 0.12, 0.35) # Floating golden embers / leaves
			target_gravity = Vector2(12, 24)
		Bubble.HolidayTheme.SNOWMEN:
			target_bg_col = Color(0.02, 0.07, 0.14, 1.0) # Chilly Winter Twilight
			target_part_col = Color(0.92, 0.96, 1.0, 0.5) # Falling snowflakes
			target_gravity = Vector2(0, 36)
		_: # BUBBLES
			target_bg_col = Color(0.03, 0.06, 0.12, 1.0) # Deep Ocean Navy
			target_part_col = Color(0.2, 0.6, 0.9, 0.25) # Floating aqua bubbles
			target_gravity = Vector2(0, -15)
			
	if background:
		if animate:
			var bg_tween = create_tween()
			bg_tween.tween_property(background, "color", target_bg_col, 0.4)
		else:
			background.color = target_bg_col
			
	if ambient_particles:
		ambient_particles.color = target_part_col
		ambient_particles.gravity = target_gravity

func _get_theme_name(t: Bubble.HolidayTheme) -> String:
	match t:
		Bubble.HolidayTheme.GHOSTS: return "👻 GHOSTS"
		Bubble.HolidayTheme.TURKEYS: return "🦃 TURKEYS"
		Bubble.HolidayTheme.SNOWMEN: return "⛄ SNOWMEN"
		_: return "🫧 BUBBLES"

# ==============================================================================
# HUD & STATUS UPDATES
# ==============================================================================
func _update_hud() -> void:
	if mode_label:
		mode_label.text = "🎮 [G] %s" % _get_game_mode_name(current_game_mode)
		match current_game_mode:
			GameMode.LINE_JUMPER:
				mode_label.modulate = Color(0.2, 0.95, 1.0)
			GameMode.CIRCLE_SCRAMBLE:
				mode_label.modulate = Color(1.0, 0.85, 0.2)
			GameMode.SPEED_RUSH:
				mode_label.modulate = Color(1.0, 0.35, 0.35)
			_:
				mode_label.modulate = Color(0.4, 0.95, 0.7)
				
	if score_label:
		match current_game_mode:
			GameMode.LINE_JUMPER:
				var jumps = line_jumper.total_jumps_cleared if line_jumper else 0
				score_label.text = "⚡ JUMPS: %d  (SCORE: %d)" % [jumps, total_score]
			GameMode.CIRCLE_SCRAMBLE:
				var count = circle_scramble.circle_count if circle_scramble else 4
				var rounds = circle_scramble.rounds_cleared if circle_scramble else 0
				score_label.text = "🎯 [%d CIRCLES]  CLEARED: %d  (SCORE: %d)" % [count, rounds, total_score]
			GameMode.SPEED_RUSH:
				var rnd = speed_rush.current_round if speed_rush else 1
				score_label.text = "💥 ROUND %d  (SCORE: %d)" % [rnd, total_score]
			_:
				score_label.text = "🫧 POPPED: %d  (SCORE: %d)" % [total_popped, total_score]
		
	if theme_label:
		# Theme is most relevant for Bubble Pop and Speed Rush
		theme_label.visible = (current_game_mode == GameMode.BUBBLE_POP or current_game_mode == GameMode.SPEED_RUSH)
		theme_label.text = "🎯 [T] %s" % _get_theme_name(current_theme)
		match current_theme:
			Bubble.HolidayTheme.GHOSTS: theme_label.modulate = Color(0.85, 0.5, 1.0)
			Bubble.HolidayTheme.TURKEYS: theme_label.modulate = Color(1.0, 0.65, 0.2)
			Bubble.HolidayTheme.SNOWMEN: theme_label.modulate = Color(0.5, 0.95, 1.0)
			_: theme_label.modulate = Color(0.35, 0.85, 1.0)
		
	if combo_label:
		if combo_streak >= 3 and current_game_mode == GameMode.BUBBLE_POP:
			combo_label.text = "🔥 %dx COMBO!" % combo_streak
			combo_label.visible = true
		else:
			combo_label.visible = false
			
	if players_label:
		var count = footprints.size()
		if count == 0:
			players_label.text = "Waiting for kids..."
			players_label.modulate = Color(0.6, 0.6, 0.7)
		elif count == 1:
			players_label.text = "🟢 1 Kid Active"
			players_label.modulate = Color(0.2, 1.0, 0.5)
		else:
			players_label.text = "🟢 %d Kids Active" % count
			players_label.modulate = Color(0.2, 1.0, 0.5)
			
	if help_label:
		match current_game_mode:
			GameMode.LINE_JUMPER:
				help_label.text = "[G: Next | Space/J: Jump | C: Calibrate | D: Tracking Config | R: Reset]"
			GameMode.CIRCLE_SCRAMBLE:
				help_label.text = "[G: Next | [ / ]: Circles | C: Calibrate | D: Tracking Config]"
			GameMode.SPEED_RUSH:
				help_label.text = "[G: Next | T: Theme | C: Calibrate | D: Tracking Config]"
			_:
				help_label.text = "[G: Next | T: Theme | C: Calibrate | D: Tracking Config]"

# ==============================================================================
# KEYBOARD & INPUT CONTROLS
# ==============================================================================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_config_screen"):
		config_screen.visible = not config_screen.visible
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		var k = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		print("[Input] Key pressed: keycode=%d physical=%d (%s)" % [event.keycode, event.physical_keycode, OS.get_keycode_string(k)])
		
		# 1. Game Mode Switching (G, M, F1-F4)
		if k == KEY_G or k == KEY_M:
			cycle_game_mode()
		elif k == KEY_F1:
			set_game_mode(GameMode.BUBBLE_POP)
		elif k == KEY_F2:
			set_game_mode(GameMode.LINE_JUMPER)
		elif k == KEY_F3:
			set_game_mode(GameMode.CIRCLE_SCRAMBLE)
		elif k == KEY_F4:
			set_game_mode(GameMode.SPEED_RUSH)
			
		# 2. Circle Scramble count adjustment ([ / ] or - / + or Up / Down)
		elif k == KEY_BRACKETLEFT or k == KEY_MINUS or k == KEY_DOWN:
			if current_game_mode == GameMode.CIRCLE_SCRAMBLE and circle_scramble:
				circle_scramble.adjust_circle_count(-1)
		elif k == KEY_BRACKETRIGHT or k == KEY_EQUAL or k == KEY_UP:
			if current_game_mode == GameMode.CIRCLE_SCRAMBLE and circle_scramble:
				circle_scramble.adjust_circle_count(1)
				
		# 3. Jump hotkey (Space or J) for mouse/keyboard testing
		elif k == KEY_SPACE or k == KEY_J:
			trigger_player_jump(0)
			
		# 4. Holiday Theme Switching (T, TAB, 1-4)
		elif k == KEY_T or k == KEY_TAB:
			cycle_theme()
		elif k == KEY_1 or k == KEY_KP_1:
			set_theme(Bubble.HolidayTheme.BUBBLES)
		elif k == KEY_2 or k == KEY_KP_2:
			set_theme(Bubble.HolidayTheme.GHOSTS)
		elif k == KEY_3 or k == KEY_KP_3:
			set_theme(Bubble.HolidayTheme.TURKEYS)
		elif k == KEY_4 or k == KEY_KP_4:
			set_theme(Bubble.HolidayTheme.SNOWMEN)
			
		# 5. Fullscreen toggle (F11 or F)
		elif k == KEY_F11 or k == KEY_F:
			_toggle_fullscreen()
			
		# 6. Exit game (ESC or Q)
		elif k == KEY_ESCAPE or k == KEY_Q:
			if config_screen and config_screen.visible:
				config_screen.visible = false
			elif not (calibration_overlay and calibration_overlay.visible):
				print("[Game] Quitting game...")
				get_tree().quit()
				
		# 7. Reset current game (R)
		elif k == KEY_R:
			reset_current_game()
			
		# 8. Floor Calibration (C)
		elif k == KEY_C:
			if calibration_overlay:
				if calibration_overlay.visible:
					calibration_overlay.close_calibration()
				else:
					calibration_overlay.open_calibration(osc_receiver.calibration)

func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func reset_current_game() -> void:
	total_score = 0
	total_popped = 0
	combo_streak = 0
	match current_game_mode:
		GameMode.LINE_JUMPER:
			if line_jumper: line_jumper.reset_game()
		GameMode.CIRCLE_SCRAMBLE:
			if circle_scramble: circle_scramble.reset_game()
		GameMode.SPEED_RUSH:
			if speed_rush: speed_rush.reset_game()
		_:
			if bubble_container:
				for b in bubble_container.get_children():
					b.queue_free()
				var vp = get_viewport_rect().size
				for i in range(max_bubbles):
					_spawn_bubble(vp)
	_update_hud()
