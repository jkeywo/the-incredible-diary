@tool
extends Sprite2D
## A single-row state sheet. The node origin stays at the prop's floor contact.

@export var cell_size := Vector2i(32, 48):
	set(value):
		cell_size = value
		if is_node_ready():
			_apply_state()
@export var state_names := PackedStringArray():
	set(value):
		state_names = value
		if is_node_ready():
			_apply_state()
@export var current_state := "":
	set(value):
		current_state = value
		if is_node_ready():
			_apply_state()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	region_enabled = true
	_apply_state()


func set_state(next_state: String) -> bool:
	if not state_names.has(next_state):
		push_warning("Unknown prop state: " + next_state)
		return false
	if current_state == next_state: return true
	current_state = next_state
	return true


func _apply_state() -> void:
	if texture == null or cell_size.x <= 0 or cell_size.y <= 0:
		return
	var index := state_names.find(current_state)
	if index < 0:
		push_warning("Prop state is not in state_names: " + current_state)
		return
	var expected_width := cell_size.x * state_names.size()
	if texture.get_width() != expected_width or texture.get_height() != cell_size.y:
		push_warning("Prop sheet does not match its state list and cell size")
		return
	region_rect = Rect2i(index * cell_size.x, 0, cell_size.x, cell_size.y)
	offset = Vector2(-cell_size.x * 0.5, -cell_size.y)
