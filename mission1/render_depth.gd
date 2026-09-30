extends RefCounted
## Node origins are ground anchors. Art offsets never change depth.
const BACKGROUND := -20
const SHELL_BACKGROUND := -30
const ENTITY := 0
const OVERHEAD := 10
const EFFECT := 20
const OVERLAY := 30
static var images := {}

static func assign(item: CanvasItem, layer := ENTITY, occluder := false) -> void:
	item.z_as_relative = false
	item.z_index = layer
	item.set_meta("depth_occluder",occluder)

static func behind(actor: Node2D, item: Node2D) -> bool:
	return actor.global_position.y < item.global_position.y and actor.z_index <= item.z_index

static func bounds(item: Node2D) -> Rect2:
	if item is Sprite2D: return item.get_rect()
	if item is AnimatedSprite2D:
		if item.sprite_frames == null or not item.sprite_frames.has_animation(item.animation): return Rect2()
		var texture: Texture2D = item.sprite_frames.get_frame_texture(item.animation,item.frame)
		if texture == null: return Rect2()
		var size: Vector2 = texture.get_size()
		return Rect2(item.offset-(size*0.5 if item.centered else Vector2.ZERO),size)
	if item is Polygon2D and not item.polygon.is_empty():
		var box := Rect2(item.polygon[0],Vector2.ZERO)
		for point in item.polygon: box = box.expand(point)
		return box
	return Rect2()

static func opaque_at(item: Node2D, point: Vector2) -> bool:
	var local := item.global_transform.affine_inverse()*point
	if item is Polygon2D: return Geometry2D.is_point_in_polygon(local,item.polygon)
	var texture: Texture2D
	var uv: Vector2 = local-bounds(item).position
	if item.flip_h: uv.x = bounds(item).size.x-1-uv.x
	if item.flip_v: uv.y = bounds(item).size.y-1-uv.y
	if item is AnimatedSprite2D:
		texture = item.sprite_frames.get_frame_texture(item.animation,item.frame)
	elif item is Sprite2D:
		texture = item.texture
		if item.region_enabled: uv += item.region_rect.position
	else: return false
	if texture == null: return false
	var key: int = texture.get_instance_id()
	if not images.has(key): images[key] = texture.get_image()
	var pixels: Image = images[key]
	return uv.x >= 0 and uv.y >= 0 and uv.x < pixels.get_width() and uv.y < pixels.get_height() and pixels.get_pixel(int(uv.x),int(uv.y)).a > 0.2

static func sync_fade(item: Node2D, actors: Array) -> void:
	if not item.get_meta("depth_occluder",false): return
	item.self_modulate.a = 1.0
	if not item.is_visible_in_tree(): return
	var area: Rect2 = item.global_transform*bounds(item)
	for actor in actors:
		if not actor is AnimatedSprite2D or not actor.is_visible_in_tree() or not behind(actor,item): continue
		var overlap: Rect2 = area.intersection(actor.global_transform*bounds(actor))
		if not overlap.has_area(): continue
		for y in range(int(overlap.position.y),ceili(overlap.end.y)+1,2):
			for x in range(int(overlap.position.x),ceili(overlap.end.x)+1,2):
				if opaque_at(item,Vector2(x,y)) and opaque_at(actor,Vector2(x,y)):
					item.self_modulate.a = 0.5
					return
