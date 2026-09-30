extends Node2D
## Hardware sits beside the door. Only the animated steam crosses its threshold.
var current_state := "off"
func _ready() -> void:
 var pipe := Sprite2D.new()
 pipe.position.x = -45
 pipe.texture = preload("res://assets/props/mission_1/steam_outlet_right.png")
 pipe.region_enabled = true
 pipe.region_rect = Rect2(219,186,997,916)
 pipe.centered = false
 pipe.offset = Vector2(-pipe.region_rect.size.x/2,-pipe.region_rect.size.y)
 pipe.scale = Vector2(65,65)/pipe.region_rect.size
 add_child(pipe)
 set_state(current_state)
func set_state(value: String) -> bool:
 current_state = value
 var plume := get_node("SteamPlume") as AnimatedSprite2D
 preload("res://mission1/render_depth.gd").assign(plume,preload("res://mission1/render_depth.gd").EFFECT)
 if value == "active":
  if not plume.visible: plume.call("play_effect")
 else: plume.call("stop_effect")
 return true
