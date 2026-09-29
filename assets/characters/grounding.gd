extends RefCounted
## Align visible soles, rather than transparent cell edges, to the floor.
## Stationary loops keep their first pose's lower legs while the torso animates.
const SHADER = preload("res://assets/characters/grounded.gdshader")
static var bottoms: Dictionary = {}

static func install(sprite: AnimatedSprite2D) -> void:
	var shadow := Node2D.new()
	shadow.name = "ContactShadow"
	shadow.show_behind_parent = true
	shadow.scale = Vector2(1, 0.28)
	shadow.draw.connect(func(): shadow.draw_circle(Vector2.ZERO, 10, Color(0.035, 0.045, 0.055, 0.4)))
	sprite.add_child(shadow)
	sprite.frame_changed.connect(func(): sync(sprite))
	sprite.animation_changed.connect(func(): sync(sprite))

static func bottom(texture: Texture2D) -> int:
	if bottoms.has(texture): return bottoms[texture]
	var pixels := texture.get_image()
	var value := pixels.get_height()
	for y in range(pixels.get_height()-1, -1, -1):
		var solid := 0
		for x in pixels.get_width():
			if pixels.get_pixel(x,y).a >= 0.5: solid += 1
		if solid >= 2:
			value = y+1
			break
	bottoms[texture] = value
	return value

static func sync(sprite: AnimatedSprite2D) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation): return
	if sprite.sprite_frames.get_frame_count(sprite.animation) == 0: return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
	if texture == null: return
	var planted := not str(sprite.animation).begins_with("walk") and sprite.sprite_frames.get_animation_loop(sprite.animation)
	var reference := sprite.sprite_frames.get_frame_texture(sprite.animation, 0) as AtlasTexture
	var sole := bottom(reference if planted else texture)
	sprite.offset = Vector2(0, texture.get_height()*0.5-sole)
	if sprite.material == null:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SHADER
		sprite.material = shader_material
	var material := sprite.material as ShaderMaterial
	material.set_shader_parameter("plant_feet", planted)
	material.set_shader_parameter("foot_row", sole-13)
	material.set_shader_parameter("frame_origin", texture.region.position)
	material.set_shader_parameter("plant_shift", reference.region.position-texture.region.position)
