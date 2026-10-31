extends Node2D

var ring_radius: float = 10.0
var max_radius: float = 75.0
var color: Color = Color(0.2, 0.8, 1.0, 0.9)
var lifetime: float = 0.5
var timer: float = 0.0
var current_theme: int = 0

@onready var particles: CPUParticles2D = $Particles
@onready var label: Label = $ScoreLabel

func setup(pop_pos: Vector2, bubble_radius: float, bubble_color: Color, score: int, theme_id: int = 0) -> void:
	global_position = pop_pos
	max_radius = bubble_radius * 1.8
	color = bubble_color
	current_theme = theme_id
	
	if label:
		label.text = "+%d" % score
		label.modulate = bubble_color.lightened(0.2)
		var tween = create_tween().set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 45.0, lifetime)
		tween.tween_property(label, "modulate:a", 0.0, lifetime)
		
	if particles:
		particles.color = bubble_color
		particles.amount = int(clampf(bubble_radius * 0.5, 12, 36))
		
		# Adapt particle motion according to theme
		match current_theme:
			1: # Ghosts: floating ethereal spirits
				particles.gravity = Vector2(0, -60)
				particles.initial_velocity_min = 20.0
				particles.initial_velocity_max = 80.0
			2: # Turkeys: energetic feather burst
				particles.gravity = Vector2(0, 70)
				particles.initial_velocity_min = 40.0
				particles.initial_velocity_max = 140.0
			3: # Snowmen: crystalline snow poof
				particles.gravity = Vector2(0, 30)
				particles.initial_velocity_min = 30.0
				particles.initial_velocity_max = 90.0
			_: # Bubbles
				particles.gravity = Vector2(0, -20)
				particles.initial_velocity_min = 25.0
				particles.initial_velocity_max = 90.0
				
		particles.emitting = true

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	timer += delta
	var progress = timer / lifetime
	
	ring_radius = lerpf(10.0, max_radius, ease(progress, 0.3))
	queue_redraw()
	
	if timer >= lifetime + 0.3:
		queue_free()

func _draw() -> void:
	var alpha = clampf(1.0 - (timer / lifetime), 0.0, 1.0)
	var ring_col = Color(color.r, color.g, color.b, alpha * 0.8)
	
	match current_theme:
		1: # GHOST: Eerie wavy spirit ring
			var steps = 32
			var pts: PackedVector2Array = []
			for i in range(steps + 1):
				var ang = (float(i) / float(steps)) * TAU
				var r_wobble = ring_radius + sin(ang * 4.0 + timer * 12.0) * (ring_radius * 0.12)
				pts.append(Vector2(cos(ang), sin(ang)) * r_wobble)
			for i in range(steps):
				draw_line(pts[i], pts[i + 1], ring_col, 3.5, true)
			# Inner glow
			draw_circle(Vector2.ZERO, ring_radius * 0.45, Color(color.r, color.g, color.b, alpha * 0.25))

		2: # TURKEY: Starburst feather ring
			draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 36, ring_col, 3.5, true)
			# 8 radiating spark lines
			var num_sparks = 8
			for i in range(num_sparks):
				var ang = (float(i) / float(num_sparks)) * TAU
				var dir = Vector2(cos(ang), sin(ang))
				var p1 = dir * (ring_radius * 0.7)
				var p2 = dir * (ring_radius * 1.15)
				draw_line(p1, p2, Color(1.0, 0.85, 0.2, alpha * 0.9), 3.0)

		3: # SNOWMAN: Frost snowflake crystal ring
			draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 36, Color(0.8, 0.95, 1.0, alpha * 0.85), 3.0, true)
			# 6-point snowflake spokes
			for i in range(6):
				var ang = (float(i) / 6.0) * TAU
				var dir = Vector2(cos(ang), sin(ang))
				draw_line(Vector2.ZERO, dir * ring_radius, Color(1, 1, 1, alpha * 0.7), 2.0)
				# Little snowflake branch barb
				var mid = dir * (ring_radius * 0.65)
				var perp = Vector2(-dir.y, dir.x) * (ring_radius * 0.18)
				draw_line(mid, mid + perp, Color(1, 1, 1, alpha * 0.6), 1.5)
				draw_line(mid, mid - perp, Color(1, 1, 1, alpha * 0.6), 1.5)

		_: # BUBBLE: Classic water shockwave
			draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 36, ring_col, 3.5, true)
			if ring_radius > 15.0:
				draw_arc(Vector2.ZERO, ring_radius * 0.6, 0.0, TAU, 28, Color(1, 1, 1, alpha * 0.5), 1.5, true)
