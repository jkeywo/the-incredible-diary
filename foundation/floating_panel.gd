extends PanelContainer
class_name FoundationFloatingPanel

var restore_button: Button

const MINIMUM_PANEL_SIZE := Vector2(280, 180)

var title_bar: HBoxContainer
var body: Control
var resize_handle: Control
var _dragging := false
var _resizing := false
var _pointer_start := Vector2.ZERO
var _position_start := Vector2.ZERO
var _size_start := Vector2.ZERO

func configure(caption: String, starting_size: Vector2) -> void:
	name = caption
	custom_minimum_size = MINIMUM_PANEL_SIZE
	size = starting_size.max(MINIMUM_PANEL_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172630")
	style.border_color = Color("527487")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	title_bar = HBoxContainer.new()
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_input)
	layout.add_child(title_bar)
	var title_label := Label.new()
	title_label.text = caption
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(title_label)
	var minimise_button := Button.new()
	minimise_button.text = "_"
	minimise_button.tooltip_text = "Minimise to bottom bar"
	minimise_button.pressed.connect(minimise_panel)
	title_bar.add_child(minimise_button)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Close panel"
	close_button.pressed.connect(close_panel)
	title_bar.add_child(close_button)
	body = Control.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	resize_handle = Control.new()
	resize_handle.custom_minimum_size = Vector2(22, 18)
	resize_handle.size_flags_horizontal = Control.SIZE_SHRINK_END
	resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	resize_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	resize_handle.gui_input.connect(_on_resize_input)
	layout.add_child(resize_handle)
	resize_handle.draw.connect(func():
		resize_handle.draw_line(Vector2(8, 16), Vector2(20, 4), Color("a9bfca"), 2.0)
		resize_handle.draw_line(Vector2(14, 16), Vector2(20, 10), Color("a9bfca"), 2.0))

func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_pointer_start = get_global_mouse_position()
			_position_start = position
			move_to_front()
		accept_event()

func _on_resize_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_resizing = event.pressed
		if _resizing:
			_pointer_start = get_global_mouse_position()
			_size_start = size
			move_to_front()
		accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		_resizing = false
	elif event is InputEventMouseMotion:
		if _dragging:
			position = _clamp_position(_position_start + get_global_mouse_position() - _pointer_start)
		elif _resizing:
			var available: Vector2 = get_parent().size - position - Vector2(8, 8)
			size = (_size_start + get_global_mouse_position() - _pointer_start).max(MINIMUM_PANEL_SIZE).min(available.max(MINIMUM_PANEL_SIZE))

func _clamp_position(candidate: Vector2) -> Vector2:
	var available: Vector2 = (get_parent().size - size - Vector2(8, 8)).max(Vector2.ZERO)
	return Vector2(clampf(candidate.x, 0.0, available.x), clampf(candidate.y, 0.0, available.y))

func fit_to_parent() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var available: Vector2 = get_parent().size - Vector2(16, 54)
	size = size.min(available.max(MINIMUM_PANEL_SIZE))
	position = _clamp_position(position)

func attach_dock(dock: HBoxContainer) -> void:
	if is_instance_valid(restore_button): return
	restore_button = Button.new()
	restore_button.text = name
	restore_button.tooltip_text = "Restore %s" % name
	restore_button.hide()
	dock.add_child(restore_button)
	restore_button.pressed.connect(open_panel)

func open_panel() -> void:
	show()
	fit_to_parent()
	move_to_front()
	if is_instance_valid(restore_button): restore_button.hide()

func close_panel() -> void:
	hide()
	if is_instance_valid(restore_button): restore_button.hide()

func minimise_panel() -> void:
	hide()
	if is_instance_valid(restore_button): restore_button.show()

func _exit_tree() -> void:
	if is_instance_valid(restore_button):
		restore_button.queue_free()
		restore_button = null
