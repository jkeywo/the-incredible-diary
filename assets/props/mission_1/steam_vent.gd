@tool
extends "res://assets/props/mission_1/stateful_prop.gd"
## The active state uses the clear vent art with a looping steam child.


func _apply_state() -> void:
	super._apply_state()
	var plume := get_node_or_null("SteamPlume") as AnimatedSprite2D
	if plume == null:
		return
	if current_state == "active":
		region_rect = Rect2i(cell_size.x, 0, cell_size.x, cell_size.y)
		if not plume.is_playing():
			plume.call("play_effect")
	else:
		plume.call("stop_effect")
