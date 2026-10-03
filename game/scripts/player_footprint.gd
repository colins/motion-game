extends Node2D

class_name PlayerFootprint

@export var player_id: int = 0
var target_pos: Vector2 = Vector2.ZERO
var foot_radius: float = 65.0
var color: Color = Color(0.0, 0.94, 1.0) # Default cyan

var pulse_time: float = 0.0
var stomp_boost: float = 0.0

const PLAYER_COLORS = [
	Color(0.0, 0.94, 1.0),   # P1: Cyan
	Color(0.22, 1.0, 0.08),  # P2: Lime
	Color(1.0, 0.0, 0.5),    # P3: Magenta / Pink
	Color(1.0, 0.6, 0.0),    # P4: Orange
]

func setup(id: int, start_pos: Vector2) -> void:
	player_id = id
	global_position = start_pos
	target_pos = start_pos
	color = PLAYER_COLORS[id % PLAYER_COLORS.size()]
	
	# Initial spawn bloom
	scale = Vector2(0.2, 0.2)
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2.ONE, 0.4)

func set_target(pos: Vector2) -> void:
	target_pos = pos

func trigger_stomp() -> void:
	stomp_boost = 1.0

func _process(delta: float) -> void:
	# Smoothly interpolate footprint to camera/mouse position for fluid motion
	global_position = global_position.lerp(target_pos, clampf(delta * 22.0, 0.0, 1.0))
	
	pulse_time += delta * 4.0
	if stomp_boost > 0.0:
		stomp_boost = max(0.0, stomp_boost - delta * 3.0)
		
	queue_redraw()

func _draw() -> void:
	var current_radius = foot_radius + (sin(pulse_time) * 4.0) + (stomp_boost * 35.0)
	var alpha_boost = 0.7 + (stomp_boost * 0.3)
	
	# Outer soft energy ring
	var glow_col = Color(color.r, color.g, color.b, 0.25 * alpha_boost)
	draw_circle(Vector2.ZERO, current_radius + 14.0, glow_col)
	
	# Solid ring with small breaks/notches
	var ring_col = Color(color.r, color.g, color.b, alpha_boost)
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 36, ring_col, 4.0 + (stomp_boost * 3.0), true)
	
	# Center target dot
	draw_circle(Vector2.ZERO, 9.0 + (stomp_boost * 5.0), Color(1.0, 1.0, 1.0, 0.9))
	
	# Stomp expanding ripple
	if stomp_boost > 0.05:
		var ripple_r = foot_radius + (1.0 - stomp_boost) * 80.0
		var rip_col = Color(color.r, color.g, color.b, stomp_boost * 0.6)
		draw_arc(Vector2.ZERO, ripple_r, 0.0, TAU, 36, rip_col, 3.0, true)
