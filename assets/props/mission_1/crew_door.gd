extends Sprite2D
const Depth = preload("res://mission1/render_depth.gd")
## The background supplies the open doorway; this leaf fills it when closed.
var current_state := "closed"

func _ready() -> void:
	texture = preload("res://assets/props/mission_1/crew_door_leaf.png")
	region_enabled = true
	# Ignore the generator's faint alpha noise outside the visible leaf.
	region_rect = Rect2(254,104,425,1475)
	centered = false
	offset = Vector2(-region_rect.size.x/2,-region_rect.size.y)
	scale = Vector2(50,126)/region_rect.size
	Depth.assign(self,Depth.ENTITY,true)
	set_state(current_state)

func set_state(value: String) -> bool:
	current_state = value
	visible = value != "open"
	return true
