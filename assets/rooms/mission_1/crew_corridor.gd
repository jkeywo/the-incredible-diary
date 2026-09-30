extends Node2D
## Both legs use the identical backdrop. Cabin visibility and leaves vary by leg.
@export var locked := false
const CENTERS := [205.0,580.0,960.0]

func _ready() -> void:
	if locked:
		var darkness := Polygon2D.new()
		darkness.name = "UpperCabinBlackout"
		darkness.polygon = PackedVector2Array([Vector2.ZERO,Vector2(1160,0),Vector2(1160,306),Vector2(0,306)])
		darkness.color = Color.BLACK
		add_child(darkness)
		for x in CENTERS:
			var leaf := preload("res://assets/props/mission_1/crew_door.tscn").instantiate()
			leaf.position = Vector2(x,405)
			add_child(leaf)
	# Redraw only each brass arch and jamb. The opening remains transparent.
	var backdrop := $Backdrop as Sprite2D
	for x in CENTERS:
		var frame := Polygon2D.new()
		frame.name = "Doorframe"+str(int(x))
		var outline := PackedVector2Array([
			Vector2(x-39,405),Vector2(x-39,312),Vector2(x-32,286),Vector2(x-17,271),Vector2(x,265),Vector2(x+17,271),Vector2(x+32,286),Vector2(x+39,312),Vector2(x+39,405),
			Vector2(x+25,405),Vector2(x+25,312),Vector2(x+20,296),Vector2(x+11,285),Vector2(x,280),Vector2(x-11,285),Vector2(x-20,296),Vector2(x-25,312),Vector2(x-25,405)])
		frame.polygon = outline
		var uv := PackedVector2Array()
		for point in outline: uv.append(point/backdrop.scale)
		frame.uv = uv
		frame.texture = backdrop.texture
		frame.z_index = 5
		add_child(frame)
