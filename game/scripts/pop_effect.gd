extends Node2D

var ring_radius: float = 10.0
var max_radius: float = 75.0
var color: Color = Color(0.2, 0.8, 1.0, 0.9)
var lifetime: float = 0.5
var timer: float = 0.0

@onready var particles: CPUParticles2D = $Particles
@onready var label: Label = $ScoreLabel

func setup(pop_pos: Vector2, bubble_radius: float, bubble_color: Color, score: int) -> void:
	global_position = pop_pos
	max_radius = bubble_radius * 1.8
	color = bubble_color
	
	if label:
		label.text = "+%d" % score
		label.modulate = bubble_color
		var tween = create_tween().set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 45.0, lifetime)
		tween.tween_property(label, "modulate:a", 0.0, lifetime)
		
	if particles:
		particles.color = bubble_color
		particles.amount = int(clampf(bubble_radius * 0.5, 12, 36))
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
	var ring_col = Color(color.r, color.g, color.b, alpha * 0.75)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 36, ring_col, 3.5, true)
	
	# Smaller inner shockwave
	if ring_radius > 15.0:
		draw_arc(Vector2.ZERO, ring_radius * 0.6, 0.0, TAU, 28, Color(1, 1, 1, alpha * 0.5), 1.5, true)
