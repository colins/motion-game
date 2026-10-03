extends Node2D

class_name Bubble

signal popped(pos: Vector2, radius: float, color: Color, score: int, is_mega: bool)

enum BubbleType { NORMAL, SPEEDY, MEGA }

var bubble_type: BubbleType = BubbleType.NORMAL
var radius: float = 45.0
var base_radius: float = 45.0
var velocity: Vector2 = Vector2.ZERO
var color: Color = Color(0.3, 0.8, 1.0)
var score_value: int = 10
var is_mega: bool = false

var wobble_phase: float = 0.0
var wobble_speed: float = 3.5
var wobble_amplitude: float = 0.08
var lifetime_timer: float = 0.0
var spawn_scale: float = 0.0

var is_popping: bool = false

func setup_random(vp_size: Vector2) -> void:
	wobble_phase = randf() * TAU
	wobble_speed = randf_range(2.5, 4.5)
	
	var roll = randf()
	if roll < 0.15:
		# Mega Bubble (15% chance)
		bubble_type = BubbleType.MEGA
		is_mega = true
		base_radius = randf_range(75.0, 105.0)
		score_value = 50
		velocity = Vector2(randf_range(-25, 25), randf_range(-40, -15))
		color = [Color(1.0, 0.8, 0.2), Color(1.0, 0.2, 0.6), Color(0.9, 0.4, 1.0)].pick_random()
	elif roll < 0.40:
		# Speedy Bubble (25% chance)
		bubble_type = BubbleType.SPEEDY
		base_radius = randf_range(28.0, 38.0)
		score_value = 25
		velocity = Vector2(randf_range(-70, 70), randf_range(-120, -60))
		color = [Color(0.2, 1.0, 0.8), Color(1.0, 1.0, 0.2), Color(0.0, 0.9, 1.0)].pick_random()
	else:
		# Normal Bubble (60% chance)
		bubble_type = BubbleType.NORMAL
		base_radius = randf_range(42.0, 62.0)
		score_value = 10
		velocity = Vector2(randf_range(-35, 35), randf_range(-70, -30))
		color = [
			Color(0.25, 0.75, 1.0),
			Color(0.4, 0.95, 0.6),
			Color(1.0, 0.45, 0.75),
			Color(0.85, 0.55, 1.0),
			Color(0.3, 0.9, 1.0)
		].pick_random()

	radius = base_radius
	
	# Spawn at bottom edge or random floor spot
	var spawn_at_bottom = randf() < 0.7
	if spawn_at_bottom:
		global_position = Vector2(randf_range(100.0, vp_size.x - 100.0), vp_size.y + base_radius + 10.0)
	else:
		global_position = Vector2(randf_range(100.0, vp_size.x - 100.0), randf_range(100.0, vp_size.y - 100.0))

func _ready() -> void:
	# Pop-in scale bounce
	scale = Vector2.ZERO
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.4)

func _process(delta: float) -> void:
	if is_popping:
		return
		
	lifetime_timer += delta
	wobble_phase += delta * wobble_speed
	
	# Organic floating movement with sine lateral drift
	var current_velocity = velocity
	current_velocity.x += sin(wobble_phase) * 30.0
	global_position += current_velocity * delta
	
	# Screen wrap or bounce at edges
	var vp = get_viewport_rect().size
	if global_position.x < base_radius:
		global_position.x = base_radius
		velocity.x = abs(velocity.x)
	elif global_position.x > vp.x - base_radius:
		global_position.x = vp.x - base_radius
		velocity.x = -abs(velocity.x)
		
	# If floats off top, recycle to bottom
	if global_position.y < -base_radius - 20.0:
		global_position.y = vp.y + base_radius
		global_position.x = randf_range(100.0, vp.x - 100.0)
	
	# Wobble deformation
	var squish = 1.0 + sin(wobble_phase) * wobble_amplitude
	scale = Vector2(squish, 2.0 - squish)
	
	queue_redraw()

func check_collision(foot_pos: Vector2, foot_radius: float = 65.0) -> bool:
	if is_popping:
		return false
	var dist = global_position.distance_to(foot_pos)
	if dist <= (base_radius + foot_radius):
		pop()
		return true
	return false

func pop() -> void:
	if is_popping:
		return
	is_popping = true
	popped.emit(global_position, base_radius, color, score_value, is_mega)
	queue_free()

func _draw() -> void:
	# 1. Outer subtle glow aura
	var glow_col = Color(color.r, color.g, color.b, 0.18)
	draw_circle(Vector2.ZERO, base_radius + 8.0, glow_col)
	
	# 2. Main translucent body
	var body_col = Color(color.r, color.g, color.b, 0.32)
	draw_circle(Vector2.ZERO, base_radius, body_col)
	
	# 3. Outer sharp rim
	var rim_col = Color(color.r, color.g, color.b, 0.85)
	draw_arc(Vector2.ZERO, base_radius, 0.0, TAU, 48, rim_col, 3.0, true)
	
	# 4. Secondary inner iridescent sheen arc
	var sheen_col = Color(1.0, 1.0, 1.0, 0.45)
	draw_arc(Vector2.ZERO, base_radius * 0.88, PI * 0.9, PI * 1.6, 24, sheen_col, 2.0, true)
	
	# 5. Top-left specular gleam highlight
	var gleam_pos = Vector2(-base_radius * 0.42, -base_radius * 0.42)
	draw_circle(gleam_pos, base_radius * 0.18, Color(1.0, 1.0, 1.0, 0.75))
	draw_circle(gleam_pos + Vector2(base_radius * 0.22, base_radius * 0.18), base_radius * 0.09, Color(1.0, 1.0, 1.0, 0.55))
