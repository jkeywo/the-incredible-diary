extends Sprite2D
## Sweep frames follow recorded voyage time, so pause and scrubbing stay still.
const REGIONS := [Rect2(30,0,510,650),Rect2(675,0,365,650),Rect2(1240,0,295,650),Rect2(1610,0,505,650)]
const ANCHORS := [394.0,920.0,1422.0,1968.0]
var current_frame := 0

func _ready() -> void:
 texture = preload("res://assets/props/mission_1/janitor_sweep.png")
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 centered = false
 region_enabled = true
 scale = Vector2(0.076,0.076)
 show_at(0)

func set_state(_value: String) -> bool: return true

func show_at(time: float) -> void:
 current_frame = int(time*4.0)%4
 region_rect = REGIONS[current_frame]
 offset = Vector2(region_rect.position.x-ANCHORS[current_frame],-615)
