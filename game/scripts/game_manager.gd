extends Node2D

@export var max_bubbles: int = 24
@export var bubble_scene: PackedScene = preload("res://scenes/bubble.tscn")
@export var pop_effect_scene: PackedScene = preload("res://scenes/pop_effect.tscn")
@export var footprint_scene: PackedScene = preload("res://scenes/player_footprint.tscn")

@onready var bubble_container: Node2D = $BubbleContainer
@onready var footprint_container: Node2D = $FootprintContainer
@onready var fx_container: Node2D = $FXContainer
@onready var osc_receiver = $OSCReceiver
@onready var audio_manager: AudioManager = $AudioManager

# HUD UI Nodes
@onready var score_label: Label = $UI/TopBar/MarginContainer/HBox/ScoreLabel
@onready var combo_label: Label = $UI/TopBar/MarginContainer/HBox/ComboLabel
@onready var players_label: Label = $UI/TopBar/MarginContainer/HBox/PlayersLabel

var total_popped: int = 0
var total_score: int = 0
var combo_streak: int = 0
var last_pop_time: float = 0.0
var combo_window_sec: float = 1.2

var footprints: Dictionary = {} # id -> PlayerFootprint

func _ready() -> void:
	# Hook up OSC Receiver signals
	osc_receiver.player_updated.connect(_on_player_updated)
	osc_receiver.player_removed.connect(_on_player_removed)
	osc_receiver.player_stomped.connect(_on_player_stomped)
	
	# Initial bubble population
	var vp = get_viewport_rect().size
	for i in range(max_bubbles):
		_spawn_bubble(vp)
		
	_update_hud()

func _process(delta: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	
	# Reset combo streak if too much time elapsed between pops
	if combo_streak > 0 and now - last_pop_time > combo_window_sec:
		combo_streak = 0
		_update_hud()
		
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
	b.setup_random(vp)
	b.popped.connect(_on_bubble_popped)
	bubble_container.add_child(b)

func _on_bubble_popped(pop_pos: Vector2, radius: float, color: Color, score: int, is_mega: bool) -> void:
	total_popped += 1
	combo_streak += 1
	last_pop_time = Time.get_ticks_msec() / 1000.0
	
	var multiplier = min(5, 1 + (combo_streak / 4))
	total_score += score * multiplier
	
	# 1. Play procedural sound effect
	audio_manager.play_pop(is_mega)
	
	# 2. Spawn visual explosion & score popup
	var fx = pop_effect_scene.instantiate()
	fx_container.add_child(fx)
	fx.setup(pop_pos, radius, color, score * multiplier)
	
	_update_hud()

func _on_player_updated(pid: int, screen_pos: Vector2) -> void:
	if not footprints.has(pid):
		var foot = footprint_scene.instantiate() as PlayerFootprint
		footprints[pid] = foot
		footprint_container.add_child(foot)
		foot.setup(pid, screen_pos)
		_update_hud()
	else:
		footprints[pid].set_target(screen_pos)

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

func _update_hud() -> void:
	if score_label:
		score_label.text = "🫧 POPPED: %d  (SCORE: %d)" % [total_popped, total_score]
		
	if combo_label:
		if combo_streak >= 3:
			combo_label.text = "🔥 %dx COMBO!" % combo_streak
			combo_label.visible = true
		else:
			combo_label.visible = false
			
	if players_label:
		var count = footprints.size()
		if count == 0:
			players_label.text = "Waiting for kids... (Click floor or start OSC)"
			players_label.modulate = Color(0.6, 0.6, 0.7)
		elif count == 1:
			players_label.text = "🟢 1 Kid Active"
			players_label.modulate = Color(0.2, 1.0, 0.5)
		else:
			players_label.text = "🟢 %d Kids Active" % count
			players_label.modulate = Color(0.2, 1.0, 0.5)

# Fullscreen & Debug Hotkeys
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11 or event.keycode == KEY_F:
			_toggle_fullscreen()
		elif event.keycode == KEY_R:
			_reset_game()

func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _reset_game() -> void:
	total_popped = 0
	total_score = 0
	combo_streak = 0
	_update_hud()
