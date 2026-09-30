extends Node2D
const Depth = preload("res://mission1/render_depth.gd")
## Both legs use the identical backdrop. Cabin visibility and leaves vary by leg.
@export var locked := false
const CENTERS := [205.0,580.0,960.0]
var depth_entities: Array[Node2D] = []

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
			depth_entities.append(leaf)
	# Redraw only each brass arch and jamb. The opening remains transparent.
	var backdrop := $Backdrop as Sprite2D
	for x in CENTERS:
		var outline := PackedVector2Array([
			Vector2(x-39,405),Vector2(x-39,312),Vector2(x-32,286),Vector2(x-17,271),Vector2(x,265),Vector2(x+17,271),Vector2(x+32,286),Vector2(x+39,312),Vector2(x+39,405),
			Vector2(x+25,405),Vector2(x+25,312),Vector2(x+20,296),Vector2(x+11,285),Vector2(x,280),Vector2(x-11,285),Vector2(x-20,296),Vector2(x-25,312),Vector2(x-25,405)])
		for upper in [false,true]:
			var clip := PackedVector2Array([Vector2(x-50,0 if upper else 335),Vector2(x+50,0 if upper else 335),Vector2(x+50,335 if upper else 406),Vector2(x-50,335 if upper else 406)])
			var index := 0
			for piece in Geometry2D.intersect_polygons(outline,clip):
				var frame := Polygon2D.new()
				frame.name = ("Arch" if upper else "Jamb")+str(int(x))+"_"+str(index)
				frame.position = Vector2(x,405)
				var vertices := PackedVector2Array()
				var uv := PackedVector2Array()
				for point in piece:
					vertices.append(point-frame.position)
					uv.append(point/backdrop.scale)
				frame.polygon = vertices
				frame.uv = uv
				frame.texture = backdrop.texture
				Depth.assign(frame,Depth.OVERHEAD if upper else Depth.ENTITY,true)
				add_child(frame)
				depth_entities.append(frame)
				index += 1

func attach_depth_entities(layer: Node2D) -> Array[Node2D]:
	for entity in depth_entities: entity.reparent(layer,false)
	return depth_entities
