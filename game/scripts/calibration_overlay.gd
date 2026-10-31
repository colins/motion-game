extends CanvasLayer

signal calibration_finished()

@onready var prompt_label: Label = $Panel/VBox/PromptLabel
@onready var corner_dots: Array[ColorRect] = [
	$CornerTL,
	$CornerTR,
	$CornerBR,
	$CornerBL
]

var active_step: int = -1 # 0: TL, 1: TR, 2: BR, 3: BL, -1: inactive
var recorded_corners: Array[Vector2] = []
var latest_raw_pos: Vector2 = Vector2.ZERO
var has_raw_pos: bool = false
var calibration_ref = null

func _ready() -> void:
	visible = false

func open_calibration(calib) -> void:
	calibration_ref = calib
	visible = true
	active_step = 0
	recorded_corners.clear()
	_update_visuals()

func close_calibration() -> void:
	visible = false
	active_step = -1
	calibration_finished.emit()

func set_latest_raw(pos: Vector2) -> void:
	latest_raw_pos = pos
	has_raw_pos = true

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		var key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		print("[Calibration] Key pressed: keycode=%d physical=%d (%s)" % [event.keycode, event.physical_keycode, OS.get_keycode_string(key)])
		if key == KEY_ESCAPE or key == KEY_C:
			close_calibration()
			get_viewport().set_input_as_handled()
		elif key == KEY_SPACE or key == KEY_ENTER:
			_capture_current_corner()
			get_viewport().set_input_as_handled()
		elif key == KEY_BACKSPACE:
			if calibration_ref:
				calibration_ref.reset_to_defaults()
			close_calibration()
			get_viewport().set_input_as_handled()

func _capture_current_corner() -> void:
	if active_step < 0 or active_step > 3:
		return

	var pos_to_record = latest_raw_pos if has_raw_pos else _default_for_step(active_step)
	recorded_corners.append(pos_to_record)
	print("[Calibration] Recorded corner %d: %s" % [active_step, pos_to_record])

	active_step += 1
	if active_step > 3:
		# Finished all 4 corners!
		if calibration_ref:
			calibration_ref.corners = recorded_corners.duplicate()
			calibration_ref.save_calibration()
		close_calibration()
	else:
		_update_visuals()

func _default_for_step(step: int) -> Vector2:
	match step:
		0: return Vector2(0.0, 0.0)
		1: return Vector2(1.0, 0.0)
		2: return Vector2(1.0, 1.0)
		3: return Vector2(0.0, 1.0)
	return Vector2.ZERO

func _update_visuals() -> void:
	var names = ["1. TOP-LEFT", "2. TOP-RIGHT", "3. BOTTOM-RIGHT", "4. BOTTOM-LEFT"]
	if active_step >= 0 and active_step < 4:
		prompt_label.text = "🎯 STEP ON THE %s CORNER TARGET\nThen press [SPACE] to capture\n[ESC to cancel | BACKSPACE to reset]" % names[active_step]

	for i in range(4):
		if i == active_step:
			corner_dots[i].color = Color(1.0, 0.2, 0.2, 1.0) # Active target (Red)
			corner_dots[i].scale = Vector2(1.5, 1.5)
		elif i < active_step:
			corner_dots[i].color = Color(0.2, 1.0, 0.3, 1.0) # Done (Green)
			corner_dots[i].scale = Vector2(1.0, 1.0)
		else:
			corner_dots[i].color = Color(0.4, 0.4, 0.5, 0.6) # Pending (Gray)
			corner_dots[i].scale = Vector2(1.0, 1.0)
