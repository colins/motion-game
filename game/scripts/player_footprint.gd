extends Node2D

class_name PlayerFootprint

@export var player_id: int = 0
var target_pos: Vector2 = Vector2.ZERO
var foot_radius: float = 65.0
var color: Color = Color(0.0, 0.94, 1.0) # Default cyan

var pulse_time: float = 0.0
var stomp_boost: float = 0.0

# Jumping physics & animation
var is_jumping: bool = false
var jump_timer: float = 0.0
const JUMP_DURATION: float = 0.60

const PLAYER_COLORS = [
	Color(0.0, 0.94, 1.0),   # P1: Cyan
	Color(0.22, 1.0, 0.08),  # P2: Lime
	Color(1.0, 0.0, 0.5),    # P3: Magenta / Pink
	Color(1.0, 0.6, 0.0),    # P4: Orange
	Color(0.9, 0.85, 0.1),   # P5: Yellow
	Color(0.65, 0.35, 1.0)   # P6: Purple
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
	trigger_jump()

func trigger_jump() -> void:
	if not is_jumping:
		is_jumping = true
		jump_timer = JUMP_DURATION

func is_on_ground() -> bool:
	return not is_jumping

func _process(delta: float) -> void:
	# Smoothly interpolate footprint to camera/mouse position for fluid motion
	global_position = global_position.lerp(target_pos, clampf(delta * 22.0, 0.0, 1.0))
	
	pulse_time += delta * 4.0
	if stomp_boost > 0.0:
		stomp_boost = max(0.0, stomp_boost - delta * 3.0)
		
	if is_jumping:
		jump_timer -= delta
		if jump_timer <= 0.0:
			is_jumping = false
			stomp_boost = 0.6 # Small landing ripple
			
	queue_redraw()

func _draw() -> void:
	var jump_norm = 0.0
	var lift = Vector2.ZERO
	if is_jumping:
		jump_norm = sin((1.0 - (jump_timer / JUMP_DURATION)) * PI)
		lift = Vector2(0, -jump_norm * 48.0)
		
		# Draw dark ground shadow beneath the airborne player
		var shadow_radius = (foot_radius * 0.9) * (1.0 - jump_norm * 0.25)
		draw_circle(Vector2(0, 12), shadow_radius, Color(0.0, 0.0, 0.0, 0.45))
		
	var current_radius = (foot_radius + (sin(pulse_time) * 4.0) + (stomp_boost * 35.0)) * (1.0 + jump_norm * 0.15)
	var alpha_boost = 0.7 + (stomp_boost * 0.3)
	
	# Outer soft energy ring
	var glow_col = Color(color.r, color.g, color.b, (0.25 if not is_jumping else 0.4) * alpha_boost)
	draw_circle(lift, current_radius + 14.0, glow_col)
	
	# Solid ring
	var ring_col = Color(color.r, color.g, color.b, alpha_boost)
	draw_arc(lift, current_radius, 0.0, TAU, 36, ring_col, 4.0 + (stomp_boost * 3.0), true)
	
	# Center target dot
	draw_circle(lift, 9.0 + (stomp_boost * 5.0), Color(1.0, 1.0, 1.0, 0.9))
	
	# Airborne indicator badge
	if is_jumping and jump_norm > 0.2:
		var wing_col = Color(1.0, 1.0, 1.0, jump_norm * 0.85)
		draw_arc(lift + Vector2(0, -current_radius - 8.0), 16.0, PI * 0.8, PI * 1.2, 12, wing_col, 3.0)
		draw_arc(lift + Vector2(0, -current_radius - 8.0), 16.0, PI * 1.8, PI * 2.2, 12, wing_col, 3.0)
	
	# Stomp expanding ripple on ground
	if stomp_boost > 0.05 and not is_jumping:
		var ripple_r = foot_radius + (1.0 - stomp_boost) * 80.0
		var rip_col = Color(color.r, color.g, color.b, stomp_boost * 0.6)
		draw_arc(Vector2.ZERO, ripple_r, 0.0, TAU, 36, rip_col, 3.0, true)
