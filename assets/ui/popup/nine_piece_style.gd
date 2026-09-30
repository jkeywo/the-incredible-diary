@tool
extends StyleBox
## Fixed corners; edge strips stretch along one axis and the body fills the middle.
const PIECES := [
	preload("res://assets/ui/popup/top_left.png"), preload("res://assets/ui/popup/top.png"), preload("res://assets/ui/popup/top_right.png"),
	preload("res://assets/ui/popup/left.png"), preload("res://assets/ui/popup/body.png"), preload("res://assets/ui/popup/right.png"),
	preload("res://assets/ui/popup/bottom_left.png"), preload("res://assets/ui/popup/bottom.png"), preload("res://assets/ui/popup/bottom_right.png")]

var tint := Color.WHITE
var high_contrast := false

func _init() -> void:
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		set_content_margin(side, 28)

func _draw(canvas_item: RID, rect: Rect2) -> void:
	if high_contrast:
		RenderingServer.canvas_item_add_rect(canvas_item, rect, Color("e6c68c"))
		RenderingServer.canvas_item_add_rect(canvas_item, rect.grow(-2), Color("09121e"))
		return
	var corner := minf(40, minf(rect.size.x, rect.size.y) / 2)
	var xs := [rect.position.x, rect.position.x + corner, rect.end.x - corner, rect.end.x]
	var ys := [rect.position.y, rect.position.y + corner, rect.end.y - corner, rect.end.y]
	for y in range(3):
		for x in range(3):
			RenderingServer.canvas_item_add_texture_rect(canvas_item,
				Rect2(xs[x], ys[y], xs[x+1]-xs[x], ys[y+1]-ys[y]), PIECES[y*3+x].get_rid(),false,tint)
