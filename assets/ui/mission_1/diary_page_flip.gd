extends Control
## Painted page-curl frames share the book's fixed hinge. Mirroring turns back.
var elapsed := 1.0
var direction := 1
const DURATION := 0.64
const SHEET := preload("res://assets/ui/mission_1/source/page_turn.png")
const CELL := Vector2(384,512)
const HINGES := [Vector2(110,140),Vector2(121,140),Vector2(153,142),Vector2(155,140),Vector2(247,111),Vector2(275,111),Vector2(287,111),Vector2(266,111)]
const SPINE := Vector2(603,94)
var frames: Array[AtlasTexture] = []

func frame_index() -> int:
	return mini(7,int(elapsed/DURATION*8.0))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in 8:
		var frame := AtlasTexture.new()
		frame.atlas = SHEET
		frame.region = Rect2(Vector2(index%4,index/4)*CELL,CELL)
		frames.append(frame)

func turn(value: int) -> void:
	direction = 1 if value > 0 else -1
	elapsed = 0.0
	queue_redraw()

func advance(delta: float) -> void:
	if elapsed >= DURATION: return
	elapsed = minf(DURATION,elapsed+delta)
	queue_redraw()

func _draw() -> void:
	if elapsed >= DURATION: return
	var index := frame_index()
	var scale := Vector2(1.63,1.565)
	draw_set_transform(SPINE,0,Vector2(direction,1))
	# The settling leaf dissolves into the matching permanent paper below it.
	var opacity := minf(1.0,(DURATION-elapsed)/0.08)
	var hinge: Vector2 = HINGES[index]
	var tint := Color(1,1,1,opacity)
	# Foreshorten the lifted tip while keeping both ends of the binding fixed.
	draw_texture_rect_region(frames[index],Rect2(-hinge.x*scale.x,-hinge.y*0.5,CELL.x*scale.x,hinge.y*0.5),Rect2(0,0,CELL.x,hinge.y),tint)
	draw_texture_rect_region(frames[index],Rect2(-hinge.x*scale.x,0,CELL.x*scale.x,(CELL.y-hinge.y)*scale.y),Rect2(0,hinge.y,CELL.x,CELL.y-hinge.y),tint)
