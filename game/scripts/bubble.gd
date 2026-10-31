extends Node2D

class_name Bubble

signal popped(pos: Vector2, radius: float, color: Color, score: int, is_mega: bool, theme_id: int)

enum BubbleType { NORMAL, SPEEDY, MEGA }
enum HolidayTheme { BUBBLES = 0, GHOSTS = 1, TURKEYS = 2, SNOWMEN = 3 }

var bubble_type: BubbleType = BubbleType.NORMAL
var current_theme: HolidayTheme = HolidayTheme.BUBBLES

var radius: float = 45.0
var base_radius: float = 45.0
var velocity: Vector2 = Vector2.ZERO
var color: Color = Color(0.3, 0.8, 1.0)
var secondary_color: Color = Color(1.0, 1.0, 1.0)
var accent_color: Color = Color(1.0, 0.5, 0.2)
var score_value: int = 10
var is_mega: bool = false

var wobble_phase: float = 0.0
var wobble_speed: float = 3.5
var wobble_amplitude: float = 0.08
var lifetime_timer: float = 0.0
var is_popping: bool = false
var bounce_mode: bool = false

# Individual variant styling
var variant_seed: int = 0
var hat_color: Color = Color(0.15, 0.15, 0.2)
var scarf_color: Color = Color(0.9, 0.2, 0.2)
var eye_blink_timer: float = 0.0

func setup_random(vp_size: Vector2, target_theme: HolidayTheme = HolidayTheme.BUBBLES) -> void:
	current_theme = target_theme
	variant_seed = randi()
	wobble_phase = randf() * TAU
	wobble_speed = randf_range(2.5, 4.5)
	
	var roll = randf()
	if roll < 0.15:
		# Mega (15% chance)
		bubble_type = BubbleType.MEGA
		is_mega = true
		base_radius = randf_range(75.0, 105.0)
		score_value = 50
		velocity = Vector2(randf_range(-25, 25), randf_range(-40, -15))
	elif roll < 0.40:
		# Speedy (25% chance)
		bubble_type = BubbleType.SPEEDY
		base_radius = randf_range(28.0, 38.0)
		score_value = 25
		velocity = Vector2(randf_range(-70, 70), randf_range(-120, -60))
	else:
		# Normal (60% chance)
		bubble_type = BubbleType.NORMAL
		base_radius = randf_range(42.0, 62.0)
		score_value = 10
		velocity = Vector2(randf_range(-35, 35), randf_range(-70, -30))

	radius = base_radius
	_apply_theme_colors()

	# Spawn at bottom edge or random floor spot
	var spawn_at_bottom = randf() < 0.7
	if spawn_at_bottom:
		global_position = Vector2(randf_range(100.0, vp_size.x - 100.0), vp_size.y + base_radius + 10.0)
	else:
		global_position = Vector2(randf_range(100.0, vp_size.x - 100.0), randf_range(100.0, vp_size.y - 100.0))

func set_theme(new_theme: HolidayTheme) -> void:
	if current_theme == new_theme:
		return
	current_theme = new_theme
	_apply_theme_colors()
	
	# Magical bounce morph tween
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	scale = Vector2(0.5, 0.5)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35)
	queue_redraw()

func _apply_theme_colors() -> void:
	match current_theme:
		HolidayTheme.BUBBLES:
			if is_mega:
				color = [Color(1.0, 0.8, 0.2), Color(1.0, 0.25, 0.65), Color(0.9, 0.4, 1.0)].pick_random()
			elif bubble_type == BubbleType.SPEEDY:
				color = [Color(0.2, 1.0, 0.8), Color(1.0, 1.0, 0.2), Color(0.0, 0.9, 1.0)].pick_random()
			else:
				color = [
					Color(0.25, 0.75, 1.0),
					Color(0.4, 0.95, 0.6),
					Color(1.0, 0.45, 0.75),
					Color(0.85, 0.55, 1.0),
					Color(0.3, 0.9, 1.0)
				].pick_random()
			secondary_color = Color(1.0, 1.0, 1.0, 0.7)
			accent_color = color.lightened(0.3)

		HolidayTheme.GHOSTS:
			if is_mega:
				color = [Color(0.95, 0.5, 0.1), Color(0.75, 0.3, 0.95)].pick_random() # Pumpkin or Shadow Violet
				accent_color = Color(1.0, 0.9, 0.2) # Glowing eyes
			elif bubble_type == BubbleType.SPEEDY:
				color = [Color(0.35, 1.0, 0.55), Color(0.3, 0.9, 1.0)].pick_random() # Eerie Toxic Green / Spirit Cyan
				accent_color = Color(0.1, 0.15, 0.1)
			else:
				color = [
					Color(0.92, 0.94, 1.0), # Crisp white ghost
					Color(0.85, 0.82, 0.98), # Pale lavender
					Color(0.82, 0.96, 0.94)  # Seafoam ectoplasm
				].pick_random()
				accent_color = Color(0.1, 0.1, 0.15)
			secondary_color = Color(color.r, color.g, color.b, 0.4)

		HolidayTheme.TURKEYS:
			if is_mega:
				color = Color(0.68, 0.36, 0.15) # Regal roasted bronze
				accent_color = Color(1.0, 0.78, 0.1) # Golden crown/feathers
			elif bubble_type == BubbleType.SPEEDY:
				color = Color(0.78, 0.38, 0.12) # Rust auburn
				accent_color = Color(1.0, 0.5, 0.1)
			else:
				color = [
					Color(0.55, 0.32, 0.16), # Deep chocolate
					Color(0.64, 0.38, 0.20), # Cinnamon brown
					Color(0.70, 0.44, 0.22)  # Harvest hazel
				].pick_random()
				accent_color = Color(0.95, 0.2, 0.15) # Red wattle
			secondary_color = Color(0.88, 0.65, 0.35) # Tummy patch

		HolidayTheme.SNOWMEN:
			if is_mega:
				color = Color(0.94, 0.97, 1.0)
				hat_color = Color(0.12, 0.12, 0.18) # Classic black top hat
				scarf_color = Color(0.9, 0.15, 0.15) # Red holiday scarf
				accent_color = Color(1.0, 0.5, 0.05) # Carrot orange
			elif bubble_type == BubbleType.SPEEDY:
				color = Color(0.88, 0.96, 1.0)
				hat_color = Color(0.2, 0.5, 0.8) # Blue beanie
				scarf_color = Color(0.1, 0.8, 0.6) # Teal wind scarf
				accent_color = Color(1.0, 0.55, 0.1)
			else:
				color = [
					Color(0.96, 0.98, 1.0),
					Color(0.92, 0.95, 0.99),
					Color(0.95, 0.94, 0.99)
				].pick_random()
				hat_color = Color(0.15, 0.15, 0.2)
				scarf_color = [Color(0.88, 0.18, 0.18), Color(0.15, 0.65, 0.3), Color(0.2, 0.45, 0.85)].pick_random()
				accent_color = Color(1.0, 0.48, 0.08)
			secondary_color = Color(0.75, 0.85, 0.96, 0.5)

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
	eye_blink_timer += delta
	if eye_blink_timer > 5.0:
		eye_blink_timer = 0.0
	
	# Organic floating movement with sine lateral drift
	var current_velocity = velocity
	current_velocity.x += sin(wobble_phase) * 30.0
	global_position += current_velocity * delta
	
	# Screen wrap or bounce at edges
	var vp = get_viewport_rect().size
	if bounce_mode:
		# Full 4-wall bounce reflection for Speed Rush
		if global_position.x < base_radius:
			global_position.x = base_radius
			velocity.x = abs(velocity.x)
		elif global_position.x > vp.x - base_radius:
			global_position.x = vp.x - base_radius
			velocity.x = -abs(velocity.x)
			
		if global_position.y < base_radius + 65.0:
			global_position.y = base_radius + 65.0
			velocity.y = abs(velocity.y)
		elif global_position.y > vp.y - base_radius:
			global_position.y = vp.y - base_radius
			velocity.y = -abs(velocity.y)
	else:
		if global_position.x < base_radius:
			global_position.x = base_radius
			velocity.x = abs(velocity.x)
		elif global_position.x > vp.x - base_radius:
			global_position.x = vp.x - base_radius
			velocity.x = -abs(velocity.x)
			
		# If floats off top, recycle to bottom
		if global_position.y < -base_radius - 30.0:
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
	popped.emit(global_position, base_radius, color, score_value, is_mega, current_theme as int)
	queue_free()

func _draw() -> void:
	match current_theme:
		HolidayTheme.BUBBLES:
			_draw_bubble()
		HolidayTheme.GHOSTS:
			_draw_ghost()
		HolidayTheme.TURKEYS:
			_draw_turkey()
		HolidayTheme.SNOWMEN:
			_draw_snowman()

# ==============================================================================
# THEME 1: CLASSIC BUBBLE
# ==============================================================================
func _draw_bubble() -> void:
	# Outer subtle glow aura
	var glow_col = Color(color.r, color.g, color.b, 0.18)
	draw_circle(Vector2.ZERO, base_radius + 8.0, glow_col)
	
	# Main translucent body
	var body_col = Color(color.r, color.g, color.b, 0.32)
	draw_circle(Vector2.ZERO, base_radius, body_col)
	
	# Outer sharp rim
	var rim_col = Color(color.r, color.g, color.b, 0.85)
	draw_arc(Vector2.ZERO, base_radius, 0.0, TAU, 48, rim_col, 3.0, true)
	
	# Secondary inner iridescent sheen arc
	var sheen_col = Color(1.0, 1.0, 1.0, 0.45)
	draw_arc(Vector2.ZERO, base_radius * 0.88, PI * 0.9, PI * 1.6, 24, sheen_col, 2.0, true)
	
	# Top-left specular gleam highlight
	var gleam_pos = Vector2(-base_radius * 0.42, -base_radius * 0.42)
	draw_circle(gleam_pos, base_radius * 0.18, Color(1.0, 1.0, 1.0, 0.75))
	draw_circle(gleam_pos + Vector2(base_radius * 0.22, base_radius * 0.18), base_radius * 0.09, Color(1.0, 1.0, 1.0, 0.55))

# ==============================================================================
# THEME 2: HALLOWEEN GHOST
# ==============================================================================
func _draw_ghost() -> void:
	var r = base_radius
	
	# 1. Spooky outer aura
	var aura_col = Color(color.r, color.g, color.b, 0.25)
	draw_circle(Vector2(0, -r * 0.1), r + 12.0, aura_col)
	
	# 2. Build flowing sheet ghost polygon (dome top + wavy rippling skirt)
	var pts: PackedVector2Array = []
	
	# Top dome arc (-PI to 0)
	var dome_radius = r * 0.85
	var dome_center = Vector2(0, -r * 0.18)
	for i in range(17):
		var ang = -PI + (float(i) / 16.0) * PI
		pts.append(dome_center + Vector2(cos(ang), sin(ang)) * dome_radius)
	
	# Right side down to hem
	var hem_y = r * 0.88
	var right_hem = Vector2(r * 0.82, hem_y)
	pts.append(Vector2(r * 0.85, 0))
	pts.append(right_hem)
	
	# Wavy undulating skirt hem (4 ripples from right to left)
	var wave_count = 4
	for i in range(wave_count):
		var t0 = float(i) / float(wave_count)
		var t1 = float(i + 1) / float(wave_count)
		var x0 = lerpf(right_hem.x, -r * 0.82, t0)
		var x1 = lerpf(right_hem.x, -r * 0.82, t1)
		var x_mid = (x0 + x1) * 0.5
		
		var wave_amp = sin(wobble_phase * 2.0 + float(i) * 1.5) * 6.0
		var y_valley = hem_y - (r * 0.18) + wave_amp
		var y_peak = hem_y + wave_amp * 0.5
		
		pts.append(Vector2(x_mid, y_valley))
		pts.append(Vector2(x1, y_peak))
		
	# Left side up back to top dome
	pts.append(Vector2(-r * 0.85, 0))
	
	# Draw filled ghost body
	var body_col = Color(color.r, color.g, color.b, 0.88)
	draw_colored_polygon(pts, body_col)
	
	# Glowing rim outline
	var stroke_col = Color(color.r, color.g, color.b, 0.95).lightened(0.2)
	for i in range(pts.size()):
		var p1 = pts[i]
		var p2 = pts[(i + 1) % pts.size()]
		draw_line(p1, p2, stroke_col, 3.0, true)
		
	# Cute flapping ghost arms
	var arm_flapping = sin(wobble_phase * 1.8) * (r * 0.12)
	var left_arm = Vector2(-r * 0.78, -r * 0.05 + arm_flapping)
	var right_arm = Vector2(r * 0.78, -r * 0.05 - arm_flapping)
	draw_circle(left_arm, r * 0.22, body_col)
	draw_circle(right_arm, r * 0.22, body_col)
	draw_arc(left_arm, r * 0.22, 0.0, TAU, 16, stroke_col, 2.5, true)
	draw_arc(right_arm, r * 0.22, 0.0, TAU, 16, stroke_col, 2.5, true)
	
	# Eyes: expressive big dark ovals
	var eye_y = -r * 0.28
	var eye_w = r * 0.13
	var eye_h = r * 0.22
	
	var eye_col = Color(0.08, 0.08, 0.12)
	if is_mega:
		eye_col = Color(1.0, 0.9, 0.2) # Glowing pumpkin eyes for mega
		
	# Left eye
	draw_rect(Rect2(-r * 0.32 - eye_w * 0.5, eye_y - eye_h * 0.5, eye_w, eye_h), eye_col, true)
	# Right eye
	draw_rect(Rect2(r * 0.32 - eye_w * 0.5, eye_y - eye_h * 0.5, eye_w, eye_h), eye_col, true)
	
	# Cute white catchlights in eyes
	if not is_mega:
		draw_circle(Vector2(-r * 0.30, eye_y - eye_h * 0.2), r * 0.05, Color.WHITE)
		draw_circle(Vector2(r * 0.34, eye_y - eye_h * 0.2), r * 0.05, Color.WHITE)
		
	# Mouth: cute surprised oval "O"
	var mouth_y = -r * 0.02
	draw_circle(Vector2(0, mouth_y), r * 0.12, eye_col)
	
	# Rosy cheeks
	var cheek_col = Color(1.0, 0.4, 0.6, 0.35)
	draw_circle(Vector2(-r * 0.45, -r * 0.12), r * 0.10, cheek_col)
	draw_circle(Vector2(r * 0.45, -r * 0.12), r * 0.10, cheek_col)
	
	# Mega Ghost Witch Hat
	if is_mega:
		var hat_pts: PackedVector2Array = [
			Vector2(-r * 0.7, -r * 0.95),
			Vector2(r * 0.7, -r * 0.95),
			Vector2(r * 0.25, -r * 1.65),
			Vector2(-r * 0.1, -r * 1.55)
		]
		draw_colored_polygon(hat_pts, Color(0.12, 0.1, 0.18))
		draw_line(Vector2(-r * 0.85, -r * 0.95), Vector2(r * 0.85, -r * 0.95), Color(0.9, 0.5, 0.1), 5.0)

# ==============================================================================
# THEME 3: THANKSGIVING TURKEY
# ==============================================================================
func _draw_turkey() -> void:
	var r = base_radius
	
	# 1. Warm harvest aura
	var aura_col = Color(0.95, 0.5, 0.1, 0.2)
	draw_circle(Vector2.ZERO, r + 8.0, aura_col)
	
	# 2. Grand fanned tail feathers in the back (7 feathers)
	var feather_colors = [
		Color(0.88, 0.2, 0.15),  # Crimson
		Color(0.95, 0.55, 0.08), # Harvest orange
		Color(0.95, 0.82, 0.15), # Corn yellow
		Color(0.28, 0.65, 0.28), # Moss green
		Color(0.95, 0.82, 0.15),
		Color(0.95, 0.55, 0.08),
		Color(0.88, 0.2, 0.15)
	]
	
	var num_feathers = feather_colors.size()
	for i in range(num_feathers):
		var frac = float(i) / float(num_feathers - 1)
		# Arc from -150 deg to -30 deg
		var base_angle = deg_to_rad(lerpf(-155.0, -25.0, frac))
		# Feathers sway gently in the breeze
		var sway = sin(wobble_phase * 1.5 + float(i)) * 0.06
		var angle = base_angle + sway
		
		var feather_dist = r * 0.95
		var f_pos = Vector2(cos(angle), sin(angle)) * feather_dist
		var f_radius = r * 0.28
		
		# Feather shaft / body
		draw_line(Vector2(0, r * 0.1), f_pos, feather_colors[i], 12.0 * (r / 50.0))
		draw_circle(f_pos, f_radius, feather_colors[i])
		# Feather accent eye / tip
		draw_circle(f_pos, f_radius * 0.45, Color(1.0, 0.92, 0.6))
	
	# 3. Plump Round Body
	var body_pos = Vector2(0, r * 0.18)
	var body_radius = r * 0.72
	draw_circle(body_pos, body_radius, color)
	draw_arc(body_pos, body_radius, 0.0, TAU, 32, color.darkened(0.25), 3.0, true)
	
	# Lighter Tummy Belly Patch
	draw_circle(body_pos + Vector2(0, r * 0.12), body_radius * 0.6, secondary_color)
	
	# 4. Cute flapping wings on left and right
	var wing_sway = sin(wobble_phase * 2.2) * 0.12
	var left_wing_center = Vector2(-r * 0.62, r * 0.18)
	var right_wing_center = Vector2(r * 0.62, r * 0.18)
	draw_circle(left_wing_center, r * 0.30, color.darkened(0.12))
	draw_circle(right_wing_center, r * 0.30, color.darkened(0.12))
	draw_arc(left_wing_center, r * 0.30, 0.0, TAU, 24, color.darkened(0.3), 2.5, true)
	draw_arc(right_wing_center, r * 0.30, 0.0, TAU, 24, color.darkened(0.3), 2.5, true)
	
	# 5. Little Orange Feet
	var foot_y = r * 0.82
	var foot_col = Color(0.95, 0.5, 0.05)
	draw_line(Vector2(-r * 0.22, r * 0.6), Vector2(-r * 0.28, foot_y), foot_col, 4.0)
	draw_line(Vector2(-r * 0.28, foot_y), Vector2(-r * 0.42, foot_y + 4.0), foot_col, 3.5)
	draw_line(Vector2(-r * 0.28, foot_y), Vector2(-r * 0.28, foot_y + 6.0), foot_col, 3.5)
	draw_line(Vector2(-r * 0.28, foot_y), Vector2(-r * 0.14, foot_y + 4.0), foot_col, 3.5)
	
	draw_line(Vector2(r * 0.22, r * 0.6), Vector2(r * 0.28, foot_y), foot_col, 4.0)
	draw_line(Vector2(r * 0.28, foot_y), Vector2(r * 0.14, foot_y + 4.0), foot_col, 3.5)
	draw_line(Vector2(r * 0.28, foot_y), Vector2(r * 0.28, foot_y + 6.0), foot_col, 3.5)
	draw_line(Vector2(r * 0.28, foot_y), Vector2(r * 0.42, foot_y + 4.0), foot_col, 3.5)

	# 6. Turkey Head
	var head_pos = Vector2(0, -r * 0.36)
	var head_radius = r * 0.40
	draw_circle(head_pos, head_radius, color)
	draw_arc(head_pos, head_radius, 0.0, TAU, 24, color.darkened(0.25), 2.5, true)
	
	# 7. Bright Red Snood / Wattle (hanging down beside beak)
	var snood_col = Color(0.92, 0.12, 0.16)
	var snood_pts: PackedVector2Array = [
		head_pos + Vector2(r * 0.06, r * 0.05),
		head_pos + Vector2(r * 0.18, r * 0.18),
		head_pos + Vector2(r * 0.14, r * 0.42 + sin(wobble_phase * 2.0) * 4.0),
		head_pos + Vector2(r * 0.02, r * 0.38),
		head_pos + Vector2(r * 0.02, r * 0.12)
	]
	draw_colored_polygon(snood_pts, snood_col)
	draw_circle(head_pos + Vector2(r * 0.12, r * 0.38), r * 0.10, snood_col)
	
	# 8. Yellow Beak
	var beak_col = Color(1.0, 0.75, 0.05)
	var beak_pts: PackedVector2Array = [
		head_pos + Vector2(-r * 0.14, r * 0.02),
		head_pos + Vector2(r * 0.14, r * 0.02),
		head_pos + Vector2(0, r * 0.28)
	]
	draw_colored_polygon(beak_pts, beak_col)
	draw_line(beak_pts[0], beak_pts[1], beak_col.darkened(0.2), 2.0)
	draw_line(beak_pts[1], beak_pts[2], beak_col.darkened(0.2), 2.0)
	draw_line(beak_pts[2], beak_pts[0], beak_col.darkened(0.2), 2.0)
	
	# 9. Cartoon Googly Eyes
	var left_eye = head_pos + Vector2(-r * 0.18, -r * 0.10)
	var right_eye = head_pos + Vector2(r * 0.18, -r * 0.10)
	draw_circle(left_eye, r * 0.14, Color.WHITE)
	draw_circle(right_eye, r * 0.14, Color.WHITE)
	draw_circle(left_eye + Vector2(1, 1), r * 0.07, Color(0.1, 0.1, 0.15))
	draw_circle(right_eye + Vector2(-1, 1), r * 0.07, Color(0.1, 0.1, 0.15))
	draw_circle(left_eye + Vector2(-1, -1), r * 0.03, Color.WHITE)
	draw_circle(right_eye + Vector2(-2, -1), r * 0.03, Color.WHITE)
	
	# Mega Turkey: Pilgrim Hat!
	if is_mega:
		var hat_y = head_pos.y - head_radius + 4.0
		# Brim
		draw_rect(Rect2(-r * 0.55, hat_y - 4.0, r * 1.1, 8.0), Color(0.15, 0.15, 0.18))
		# Tall crown
		draw_rect(Rect2(-r * 0.35, hat_y - r * 0.65, r * 0.7, r * 0.65), Color(0.15, 0.15, 0.18))
		# Gold buckle
		draw_rect(Rect2(-r * 0.35, hat_y - 12.0, r * 0.7, 8.0), Color(0.9, 0.5, 0.1))
		draw_rect(Rect2(-r * 0.14, hat_y - 14.0, r * 0.28, 12.0), Color(1.0, 0.85, 0.2), false, 2.0)

# ==============================================================================
# THEME 4: WINTER SNOWMAN
# ==============================================================================
func _draw_snowman() -> void:
	var r = base_radius
	
	# 1. Chilly Frost Aura
	var aura_col = Color(0.5, 0.8, 1.0, 0.22)
	draw_circle(Vector2.ZERO, r + 8.0, aura_col)
	
	# 2. Twig stick arms (behind body)
	var arm_col = Color(0.42, 0.26, 0.12)
	var left_hand = Vector2(-r * 0.95, -r * 0.1 + sin(wobble_phase * 1.5) * 4.0)
	var right_hand = Vector2(r * 0.95, -r * 0.1 - sin(wobble_phase * 1.5) * 4.0)
	draw_line(Vector2(-r * 0.45, 0), left_hand, arm_col, 3.5)
	draw_line(left_hand, left_hand + Vector2(-8, -10), arm_col, 2.5) # Twig finger
	draw_line(Vector2(r * 0.45, 0), right_hand, arm_col, 3.5)
	draw_line(right_hand, right_hand + Vector2(8, -10), arm_col, 2.5) # Twig finger
	
	# 3. Bottom Snowball (Tummy)
	var bot_pos = Vector2(0, r * 0.32)
	var bot_radius = r * 0.68
	draw_circle(bot_pos, bot_radius, color)
	draw_arc(bot_pos, bot_radius, 0.0, TAU, 36, Color(0.7, 0.85, 0.98), 2.5, true)
	
	# 4. Head Snowball
	var head_pos = Vector2(0, -r * 0.38)
	var head_radius = r * 0.48
	draw_circle(head_pos, head_radius, color)
	draw_arc(head_pos, head_radius, 0.0, TAU, 32, Color(0.7, 0.85, 0.98), 2.5, true)
	
	# 5. Coal Buttons down the tummy (3 buttons)
	var coal_col = Color(0.12, 0.12, 0.16)
	for i in range(3):
		var btn_y = bot_pos.y - bot_radius * 0.35 + (float(i) * r * 0.28)
		draw_circle(Vector2(0, btn_y), r * 0.075, coal_col)
		draw_circle(Vector2(-1, btn_y - 1), r * 0.025, Color(1, 1, 1, 0.5)) # Reflection
		
	# 6. Cozy Winter Scarf around neck
	var scarf_y = -r * 0.06
	var scarf_rect = Rect2(-r * 0.48, scarf_y - r * 0.10, r * 0.96, r * 0.20)
	draw_rect(scarf_rect, scarf_color, true)
	draw_rect(scarf_rect, scarf_color.darkened(0.2), false, 2.0)
	
	# Scarf dangling tails fluttering in the wind
	var tail_wave = sin(wobble_phase * 2.0) * (r * 0.14)
	var tail_pts: PackedVector2Array = [
		Vector2(r * 0.18, scarf_y + r * 0.05),
		Vector2(r * 0.42, scarf_y + r * 0.05),
		Vector2(r * 0.48 + tail_wave, scarf_y + r * 0.58),
		Vector2(r * 0.22 + tail_wave, scarf_y + r * 0.58)
	]
	draw_colored_polygon(tail_pts, scarf_color)
	# Scarf fringes
	draw_line(Vector2(r * 0.22 + tail_wave, scarf_y + r * 0.58), Vector2(r * 0.48 + tail_wave, scarf_y + r * 0.58), Color(1, 1, 1, 0.8), 3.0)
	
	# 7. Coal Eyes on head
	var left_eye = head_pos + Vector2(-r * 0.18, -r * 0.10)
	var right_eye = head_pos + Vector2(r * 0.18, -r * 0.10)
	draw_circle(left_eye, r * 0.08, coal_col)
	draw_circle(right_eye, r * 0.08, coal_col)
	draw_circle(left_eye + Vector2(-1, -1), r * 0.03, Color.WHITE)
	draw_circle(right_eye + Vector2(-1, -1), r * 0.03, Color.WHITE)
	
	# 8. Carrot Nose pointing sideways
	var nose_start = head_pos + Vector2(-r * 0.04, r * 0.04)
	var nose_tip = nose_start + Vector2(r * 0.42, -r * 0.02)
	var nose_pts: PackedVector2Array = [
		nose_start + Vector2(0, -r * 0.07),
		nose_tip,
		nose_start + Vector2(0, r * 0.07)
	]
	draw_colored_polygon(nose_pts, accent_color)
	draw_line(nose_start + Vector2(r * 0.15, -r * 0.03), nose_start + Vector2(r * 0.15, r * 0.03), Color(0.75, 0.3, 0.0), 1.5)
	
	# 9. Cheery Coal Smile (5 small dots)
	for i in range(5):
		var frac = float(i) / 4.0
		var ang = deg_to_rad(lerpf(30.0, 150.0, frac))
		var smile_center = head_pos + Vector2(0, r * 0.08)
		var smile_pt = smile_center + Vector2(cos(ang) * (r * 0.22), sin(ang) * (r * 0.16))
		draw_circle(smile_pt, r * 0.04, coal_col)
		
	# Rosy frosty cheeks
	var cheek_col = Color(1.0, 0.4, 0.5, 0.3)
	draw_circle(head_pos + Vector2(-r * 0.30, 0), r * 0.08, cheek_col)
	draw_circle(head_pos + Vector2(r * 0.30, 0), r * 0.08, cheek_col)

	# 10. Top Hat
	var hat_base_y = head_pos.y - head_radius + 4.0
	# Hat Brim
	var brim_w = r * 0.95
	var brim_h = r * 0.16
	draw_rect(Rect2(-brim_w * 0.5, hat_base_y - brim_h * 0.5, brim_w, brim_h), hat_color, true)
	
	# Hat Crown
	var crown_w = r * 0.62
	var crown_h = r * 0.55
	draw_rect(Rect2(-crown_w * 0.5, hat_base_y - crown_h, crown_w, crown_h), hat_color, true)
	# Hat Band (Red holiday ribbon)
	draw_rect(Rect2(-crown_w * 0.5, hat_base_y - r * 0.14, crown_w, r * 0.12), Color(0.9, 0.15, 0.15), true)
	
	# Mega Snowman: Holly Berry on the hat!
	if is_mega:
		var berry_pos = Vector2(crown_w * 0.4, hat_base_y - r * 0.16)
		draw_circle(berry_pos, 4.0, Color(0.95, 0.1, 0.1))
		draw_circle(berry_pos + Vector2(-4, -2), 3.5, Color(0.95, 0.1, 0.1))
		draw_circle(berry_pos + Vector2(3, -3), 2.5, Color(0.2, 0.7, 0.2)) # Leaf
