extends AnimatedSprite2D
## Fixed-grid character art for the two-room foundation.
## Place this node at the character's feet and call play_action(action, direction).

const CELL_SIZE := Vector2i(32, 48)
const DIRECTIONS := ["down", "left", "up", "right"]
const ACTIONS := {"idle": [0, 2, 2.0], "walk": [2, 4, 8.0], "talk": [6, 3, 4.0], "bob": [9, 4, 8.0]}
const CHARACTERS := ["player", "rake", "glamorous", "ex_army", "matron"]

@export_enum("player", "rake", "glamorous", "ex_army", "matron") var character_id := "player"
@export_enum("down", "left", "up", "right") var initial_direction := "down"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	offset = Vector2(0, -24)
	sprite_frames = make_frames(character_id)
	animation_finished.connect(_on_animation_finished)
	play_action("idle", initial_direction)


static func make_frames(id: String) -> SpriteFrames:
	if not CHARACTERS.has(id):
		push_error("Unknown character sprite: " + id)
		return SpriteFrames.new()
	var sheet := load("res://assets/characters/%s_sprites.png" % id) as Texture2D
	var result := SpriteFrames.new()
	if result.has_animation("default"):
		result.remove_animation("default")
	for direction_index in range(DIRECTIONS.size()):
		for action in ACTIONS:
			var name := "%s_%s" % [action, DIRECTIONS[direction_index]]
			var definition: Array = ACTIONS[action]
			result.add_animation(name)
			result.set_animation_speed(name, definition[2])
			result.set_animation_loop(name, action != "bob")
			for frame_index in range(definition[1]):
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2i(
					Vector2i((definition[0] + frame_index) * CELL_SIZE.x, direction_index * CELL_SIZE.y),
					CELL_SIZE
				)
				result.add_frame(name, atlas)
	return result


func play_action(action: String, direction: String) -> void:
	var name := "%s_%s" % [action, direction]
	if not sprite_frames.has_animation(name):
		push_error("Unknown character animation: " + name)
		return
	play(name)


func _on_animation_finished() -> void:
	if animation.begins_with("bob_"):
		play_action("idle", animation.trim_prefix("bob_"))
