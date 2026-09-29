extends CanvasLayer
## Shared pause UI for gameplay scenes. Scenes with an authoring session can
## handle pause themselves; all other scenes get the live scene inspector.

const FloatingPanel = preload("res://foundation/floating_panel.gd")

var overlay: Control
var scene_tree: Tree
var properties: VBoxContainer
var dock: HBoxContainer
var panels: Dictionary = {}
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var edited_scene: Node
var selected: Node
var owns_pause := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_build_ui()
	get_tree().scene_changed.connect(_scene_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause_game") or event.is_echo():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.has_method("is_pause_editor_available") and not scene.is_pause_editor_available():
		return
	# Recorded simulations provide their own authoring/validation adapter.
	if scene.has_method("toggle_pause_editor"):
		scene.toggle_pause_editor()
		get_viewport().set_input_as_handled()
		return
	if owns_pause:
		resume()
	else:
		pause(scene)
	get_viewport().set_input_as_handled()


func pause(scene: Node) -> void:
	if edited_scene != scene:
		undo_stack.clear()
		redo_stack.clear()
		edited_scene = scene
	get_tree().paused = true
	owns_pause = true
	overlay.show()
	_refresh_tree()
	for panel in panels.values():
		panel.open_panel()


func resume() -> void:
	if not owns_pause:
		return
	overlay.hide()
	get_viewport().gui_release_focus()
	get_tree().paused = false
	owns_pause = false


func _scene_changed() -> void:
	resume()
	edited_scene = null
	selected = null
	undo_stack.clear()
	redo_stack.clear()


func _build_ui() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 58
	overlay.add_child(bar)
	var row := HBoxContainer.new()
	bar.add_child(row)
	_menu(row, "Run", ["Resume (Space)"], [resume])
	_menu(row, "Edit", ["Undo", "Redo"], [_undo, _redo])
	_menu(row, "View", ["Scene", "Inspector"], [func(): _show_panel("Scene"), func(): _show_panel("Inspector")])
	var heading := Label.new()
	heading.text = "PAUSED — Scene editor"
	row.add_child(heading)
	dock = HBoxContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -38
	overlay.add_child(dock)
	var scene_panel := _panel("Scene", Vector2(16, 55), Vector2(330, 480))
	scene_tree = Tree.new()
	scene_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_tree.item_selected.connect(_select_node)
	scene_panel.body.add_child(scene_tree)
	var inspector := _panel("Inspector", Vector2(740, 55), Vector2(390, 480))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inspector.body.add_child(scroll)
	properties = VBoxContainer.new()
	properties.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(properties)
	overlay.hide()


func _menu(row: Control, caption: String, labels: Array, callbacks: Array) -> void:
	var button := MenuButton.new()
	button.text = caption
	row.add_child(button)
	for label in labels:
		button.get_popup().add_item(label)
	button.get_popup().id_pressed.connect(func(id: int):
		if owns_pause:
			callbacks[id].call())


func _panel(caption: String, point: Vector2, dimensions: Vector2) -> FoundationFloatingPanel:
	var panel := FloatingPanel.new()
	overlay.add_child(panel)
	panel.configure(caption, dimensions)
	panel.position = point
	panels[caption] = panel
	panel.attach_dock(dock)
	return panel


func _show_panel(caption: String) -> void:
	panels[caption].open_panel()


func _refresh_tree() -> void:
	scene_tree.clear()
	_add_node(edited_scene, null)
	scene_tree.get_root().select(0)


func _add_node(node: Node, parent: TreeItem) -> void:
	var item := scene_tree.create_item(parent)
	item.set_text(0, str(node.name))
	item.set_metadata(0, node.get_instance_id())
	for child in node.get_children():
		_add_node(child, item)


func _select_node() -> void:
	selected = instance_from_id(scene_tree.get_selected().get_metadata(0)) as Node
	_refresh_properties()


func _label(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	properties.add_child(label)


func _refresh_properties() -> void:
	for child in properties.get_children():
		properties.remove_child(child)
		child.queue_free()
	if not is_instance_valid(selected):
		return
	_label(str(selected.name) + " · " + selected.get_class())
	_label("Exported scene properties. Changes apply while paused; Undo restores previous values. Changes last for this session.")
	var count := 0
	for property in selected.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage) & PROPERTY_USAGE_EDITOR):
			continue
		var key := str(property.name)
		var value: Variant = selected.get(key)
		if typeof(value) not in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			continue
		# Paths and free-form identifiers require a content validation adapter.
		if typeof(value) == TYPE_STRING and int(property.hint) != PROPERTY_HINT_ENUM:
			continue
		count += 1
		_label(key.capitalize())
		var target := selected
		if int(property.hint) == PROPERTY_HINT_ENUM and typeof(value) == TYPE_STRING:
			var picker := OptionButton.new()
			var choices := str(property.hint_string).split(",")
			for choice in choices:
				picker.add_item(choice)
			picker.select(choices.find(value))
			picker.item_selected.connect(func(index: int): _edit(target, key, choices[index]))
			properties.add_child(picker)
		elif typeof(value) == TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = value
			check.toggled.connect(func(next: bool): _edit(target, key, next))
			properties.add_child(check)
		elif typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			var spin := SpinBox.new()
			spin.min_value = -1000000
			spin.max_value = 1000000
			spin.step = 1.0 if typeof(value) == TYPE_INT else 0.1
			if int(property.hint) == PROPERTY_HINT_RANGE:
				var bounds := str(property.hint_string).split(",")
				spin.min_value = float(bounds[0])
				spin.max_value = float(bounds[1])
				if bounds.size() > 2:
					spin.step = float(bounds[2])
			spin.value = value
			spin.value_changed.connect(func(next: float): _edit(target, key, int(next) if typeof(value) == TYPE_INT else next))
			properties.add_child(spin)
	if count == 0:
		_label("No editable exported properties on this node. Select a child in Scene.")


func _edit(target: Node, key: String, value: Variant) -> void:
	if not owns_pause or not is_instance_valid(target) or target.get(key) == value:
		return
	undo_stack.append({"id": target.get_instance_id(), "key": key, "before": target.get(key), "after": value})
	redo_stack.clear()
	target.set(key, value)


func _undo() -> void:
	_transfer(undo_stack, redo_stack, "before")


func _redo() -> void:
	_transfer(redo_stack, undo_stack, "after")


func _transfer(source: Array[Dictionary], destination: Array[Dictionary], key: String) -> void:
	if not owns_pause or source.is_empty():
		return
	var change: Dictionary = source.pop_back()
	var target := instance_from_id(change.id)
	if is_instance_valid(target):
		target.set(change.key, change[key])
		destination.append(change)
	_refresh_properties()
