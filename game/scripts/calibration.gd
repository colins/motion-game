extends Node

# 4-Point Projector to Floor Alignment & Calibration
# Maps normalized LiDAR coordinates into exact projector viewport space.

const SAVE_PATH = "user://floor_calibration.json"

# Default quad corners in LiDAR space (normalized 0.0 to 1.0)
# Top-Left (0), Top-Right (1), Bottom-Right (2), Bottom-Left (3)
var corners: Array[Vector2] = [
	Vector2(0.0, 0.0), # Top-Left
	Vector2(1.0, 0.0), # Top-Right
	Vector2(1.0, 1.0), # Bottom-Right
	Vector2(0.0, 1.0)  # Bottom-Left
]

var is_calibrated: bool = false

func _ready() -> void:
	load_calibration()

func load_calibration() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var text = file.get_as_text()
	var json = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var d = json.data
		if d.has("corners") and d["corners"].size() == 4:
			corners[0] = Vector2(d["corners"][0][0], d["corners"][0][1])
			corners[1] = Vector2(d["corners"][1][0], d["corners"][1][1])
			corners[2] = Vector2(d["corners"][2][0], d["corners"][2][1])
			corners[3] = Vector2(d["corners"][3][0], d["corners"][3][1])
			is_calibrated = true
			print("[Calibration] Loaded 4-corner floor calibration from ", SAVE_PATH)
			return true
	return false

func save_calibration() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[Calibration] Failed to save calibration to ", SAVE_PATH)
		return
	var d = {
		"corners": [
			[corners[0].x, corners[0].y],
			[corners[1].x, corners[1].y],
			[corners[2].x, corners[2].y],
			[corners[3].x, corners[3].y]
		],
		"saved_at": Time.get_datetime_string_from_system()
	}
	file.store_string(JSON.stringify(d, "\t"))
	is_calibrated = true
	print("[Calibration] Successfully saved 4-corner floor calibration!")

func reset_to_defaults() -> void:
	corners = [
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0)
	]
	is_calibrated = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	print("[Calibration] Reset floor calibration to defaults.")

# Map a raw normalized LiDAR point (nx, ny in 0..1) to viewport pixel space
func map_to_screen(raw_norm: Vector2, vp_size: Vector2) -> Vector2:
	if not is_calibrated:
		# Identity mapping
		return Vector2(clampf(raw_norm.x, 0.0, 1.0) * vp_size.x, clampf(raw_norm.y, 0.0, 1.0) * vp_size.y)

	# Inverse bilinear mapping from physical quad (c0, c1, c2, c3) to unit square (u, v)
	var uv = _quad_to_unit_square(raw_norm)
	return Vector2(clampf(uv.x, 0.0, 1.0) * vp_size.x, clampf(uv.y, 0.0, 1.0) * vp_size.y)

# Iterative or analytical quad to unit square mapping
func _quad_to_unit_square(p: Vector2) -> Vector2:
	var c0 = corners[0] # TL
	var c1 = corners[1] # TR
	var c2 = corners[2] # BR
	var c3 = corners[3] # BL

	# Analytical cross-ratio / bilinear solver:
	# p(u, v) = (1-u)(1-v)*c0 + u*(1-v)*c1 + u*v*c2 + (1-u)*v*c3
	# Let a = c0 - p, b = c1 - c0, c = c3 - c0, d = c0 - c1 + c2 - c3
	var a = c0 - p
	var b = c1 - c0
	var c = c3 - c0
	var d = c0 - c1 + c2 - c3

	var cross_bd = b.cross(d)
	var cross_cd = c.cross(d)

	if absf(d.x) < 1e-5 and absf(d.y) < 1e-5:
		# Parallelogram shortcut
		var det = b.x * c.y - b.y * c.x
		if absf(det) > 1e-6:
			var u = (-a.x * c.y + a.y * c.x) / det
			var v = (b.x * -a.y - b.y * -a.x) / det
			return Vector2(u, v)

	# General quadrilateral quadratic equation for v
	var A = c.cross(d)
	var B = c.cross(b) + a.cross(d)
	var C = a.cross(b)

	var v = 0.5
	if absf(A) < 1e-6:
		if absf(B) > 1e-6:
			v = -C / B
	else:
		var disc = B * B - 4.0 * A * C
		if disc >= 0.0:
			var sqrt_disc = sqrt(disc)
			var v1 = (-B - sqrt_disc) / (2.0 * A)
			var v2 = (-B + sqrt_disc) / (2.0 * A)
			if v1 >= -0.2 and v1 <= 1.2:
				v = v1
			else:
				v = v2

	var denom = (b.x + d.x * v)
	var u = 0.5
	if absf(denom) > 1e-5:
		u = -(a.x + c.x * v) / denom
	else:
		var denom2 = (b.y + d.y * v)
		if absf(denom2) > 1e-5:
			u = -(a.y + c.y * v) / denom2

	return Vector2(u, v)
