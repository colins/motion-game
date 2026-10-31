extends CanvasLayer

## Live tracking diagnostics and game-side movement settings.
const SAVE_PATH := "user://motion_config.json"

var receiver: Node
var rows: VBoxContainer
var info_label: Label
var speed_label: Label
var jump_label: Label
var jump_height := 48.0
var example_ids: Array[int] = []
var last_positions: Dictionary = {}
var speeds: Dictionary = {}
var elapsed := 0.0

func _ready() -> void:
	_load_settings()
	_build_ui()
	visible = false

func _build_ui() -> void:
	layer = 90
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.06, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-560, -420)
	panel.size = Vector2(1120, 840)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]: margin.add_theme_constant_override(side, 28)
	for side in ["margin_top", "margin_bottom"]: margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "TRACKING CONFIGURATION"
	title.add_theme_font_size_override("font_size", 30)
	layout.add_child(title)
	info_label = Label.new()
	info_label.text = "Waiting for LiDAR tracks"
	layout.add_child(info_label)
	var head := Label.new()
	head.text = "LIVE DETECTIONS  ·  select an ID to save it as an example foot"
	head.add_theme_color_override("font_color", Color(0.3, 0.85, 1))
	layout.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	speed_label = Label.new()
	layout.add_child(speed_label)
	jump_label = Label.new()
	layout.add_child(jump_label)
	var jump := HSlider.new()
	jump.min_value = 10
	jump.max_value = 120
	jump.step = 1
	jump.value = jump_height
	jump.value_changed.connect(_set_jump)
	layout.add_child(jump)
	var footnote := Label.new()
	footnote.text = "Play area: edit the four corners with C (floor calibration).  D / Esc: close. Settings save automatically."
	footnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(footnote)
	_update_setting_labels()

func _process(delta: float) -> void:
	if not visible or receiver == null: return
	elapsed += delta
	if elapsed < 0.15: return
	elapsed = 0.0
	_refresh_rows()

func _refresh_rows() -> void:
	for child in rows.get_children(): child.queue_free()
	var players: Dictionary = receiver.active_players
	info_label.text = "Active detections: %d     Example feet saved: %d" % [players.size(), example_ids.size()]
	var peak_speed := 0.0
	for id in players:
		var pos: Vector2 = players[id].pos
		var speed := 0.0
		if last_positions.has(id):
			speed = pos.distance_to(last_positions[id]) / maxf(elapsed, 0.001)
		speeds[id] = lerpf(float(speeds.get(id, speed)), speed, 0.5)
		peak_speed = maxf(peak_speed, float(speeds[id]))
		last_positions[id] = pos
		var button := Button.new()
		var marked := example_ids.has(int(id))
		button.text = "%s  ID %s     X %.0f  Y %.0f     speed %.0f px/s" % ["✓ EXAMPLE FOOT" if marked else "＋ MARK AS FOOT", str(id), pos.x, pos.y, speeds[id]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_toggle_example.bind(int(id)))
		rows.add_child(button)
	speed_label.text = "Fastest currently observed movement: %.0f px/s" % peak_speed

func _toggle_example(id: int) -> void:
	if example_ids.has(id): example_ids.erase(id)
	else: example_ids.append(id)
	_save_settings()
	if get_parent().has_method("apply_example_filter"):
		get_parent().apply_example_filter()
	_refresh_rows()

func accepts_player(id: int) -> bool:
	return example_ids.is_empty() or example_ids.has(id)

func _set_jump(value: float) -> void:
	jump_height = value
	_save_settings()
	_update_setting_labels()
	if get_parent().has_method("set_jump_height"):
		get_parent().set_jump_height(value)

func _update_setting_labels() -> void:
	if speed_label: speed_label.text = "Fastest currently observed movement: waiting for tracks"
	if jump_label: jump_label.text = "Jump height threshold: %.0f px (game-side setting)" % jump_height

func _load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		jump_height = float(parsed.get("jump_height", jump_height))
		for id in parsed.get("example_ids", []): example_ids.append(int(id))

func _save_settings() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"jump_height": jump_height, "example_ids": example_ids}))

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_D):
		visible = false
		get_viewport().set_input_as_handled()
