extends Sprite2D
## Sweep frames follow recorded voyage time, so pause and scrubbing stay still.
const REGIONS := [Rect2(0,0,543,724),Rect2(543,0,543,724),Rect2(1086,0,543,724),Rect2(1629,0,543,724)]
const ANCHORS := [374.0,915.0,1398.0,1974.0]
var current_frame := 0

func _ready() -> void:
 texture = preload("res://assets/props/mission_1/janitor_sweep.png")
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 centered = false
 region_enabled = true
 scale = Vector2(0.088,0.088)
 show_at(0)

func set_state(_value: String) -> bool: return true

func show_at(time: float) -> void:
 current_frame = int(time*4.0)%4
 region_rect = REGIONS[current_frame]
 offset = Vector2(region_rect.position.x-ANCHORS[current_frame],-640)
