@tool
extends AnimatedSprite2D
## One-row transparent effect strip with a bottom-centre scene origin.

@export var sheet: Texture2D:
	set(value):
		sheet = value
		if is_node_ready():
			_rebuild()
@export var cell_size := Vector2i(64, 64):
	set(value):
		cell_size = value
		if is_node_ready():
			_rebuild()
@export_range(1, 16, 1) var frame_count := 4
@export_range(1.0, 24.0, 0.5) var frames_per_second := 8.0
@export var loop_effect := false
@export var play_on_ready := false
@export var hide_when_finished := true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animation_finished.connect(_on_animation_finished)
	_rebuild()
	if play_on_ready:
		play_effect()
	else:
		visible = false


func _rebuild() -> void:
	if sheet == null or cell_size.x <= 0 or cell_size.y <= 0:
		return
	if sheet.get_size() != Vector2(cell_size.x * frame_count, cell_size.y):
		push_warning("Effect sheet dimensions do not match the configured cells")
		return
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("effect")
	frames.set_animation_speed("effect", frames_per_second)
	frames.set_animation_loop("effect", loop_effect)
	for index in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2i(index * cell_size.x, 0, cell_size.x, cell_size.y)
		frames.add_frame("effect", atlas)
	sprite_frames = frames
	offset = Vector2(0.0, -cell_size.y * 0.5)


func play_effect() -> void:
	if sprite_frames == null or not sprite_frames.has_animation("effect"):
		return
	stop()
	frame = 0
	visible = true
	play("effect")


func stop_effect() -> void:
	stop()
	visible = false


func _on_animation_finished() -> void:
	if hide_when_finished:
		visible = false
