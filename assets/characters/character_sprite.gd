@tool
extends AnimatedSprite2D
## Fixed-grid character art for the two-room foundation.
## Place this node at the character's feet and call play_action(action, direction).

const CELL_SIZE := Vector2i(32, 48)
const DIRECTIONS := ["down", "left", "up", "right"]
const ACTIONS := {"idle": [0, 2, 2.0], "walk": [2, 4, 8.0], "talk": [6, 3, 4.0], "bob": [9, 4, 8.0]}
const PLAYER_ACTIONS := {
	"hide_bag": [0, 4, 8.0, false],
	"shove": [4, 4, 12.0, false],
	"turn_valve": [8, 4, 6.0, true],
	"bump": [12, 4, 10.0, false],
}
## Action strips are separate from the shared four-facing movement sheets.
## The last flag marks a one-shot that should return to idle; casualty poses hold.
const ROLE_ACTIONS := {
	"rake": {
		"search_bag": [0, 4, 6.0, true, false],
		"hold_drink": [4, 4, 4.0, true, false],
		"spill_react": [8, 4, 8.0, false, true],
		"poison_collapse": [12, 4, 6.0, false, false],
	},
	"glamorous": {
		"chandelier_warn": [0, 4, 5.0, true, false],
		"pushed": [4, 4, 10.0, false, true],
		"recover": [8, 4, 8.0, false, true],
		"chandelier_casualty": [12, 4, 6.0, false, false],
	},
	"matron": {
		"steam_trapped": [0, 4, 5.0, true, false],
		"cough": [4, 4, 6.0, true, false],
		"escape": [8, 4, 10.0, false, true],
		"chatter": [12, 4, 4.0, true, false],
	},
}
const CHARACTERS := ["player", "rake", "glamorous", "ex_army", "matron"]

@export_enum("player", "rake", "glamorous", "ex_army", "matron") var character_id := "player":
	set(value):
		character_id = value
		if is_node_ready():
			_refresh()
@export_enum("down", "left", "up", "right") var initial_direction := "down":
	set(value):
		initial_direction = value
		if is_node_ready():
			play_action("idle", value)
var _resume_direction := "down"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	offset = Vector2(0, -24)
	animation_finished.connect(_on_animation_finished)
	_refresh()


func _refresh() -> void:
	sprite_frames = make_frames(character_id)
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
	if id == "player":
		var action_sheet := load("res://assets/characters/actions/amelia_actions.png") as Texture2D
		for action in PLAYER_ACTIONS:
			var definition: Array = PLAYER_ACTIONS[action]
			result.add_animation(action)
			result.set_animation_speed(action, definition[2])
			result.set_animation_loop(action, definition[3])
			for frame_index in range(definition[1]):
				var atlas := AtlasTexture.new()
				atlas.atlas = action_sheet
				atlas.region = Rect2i(Vector2i((definition[0] + frame_index) * CELL_SIZE.x, 0), CELL_SIZE)
				result.add_frame(action, atlas)
	elif ROLE_ACTIONS.has(id):
		var action_sheet := load("res://assets/characters/actions/%s_actions.png" % id) as Texture2D
		for action in ROLE_ACTIONS[id]:
			var definition: Array = ROLE_ACTIONS[id][action]
			result.add_animation(action)
			result.set_animation_speed(action, definition[2])
			result.set_animation_loop(action, definition[3])
			for frame_index in range(definition[1]):
				var atlas := AtlasTexture.new()
				atlas.atlas = action_sheet
				atlas.region = Rect2i(Vector2i((definition[0] + frame_index) * CELL_SIZE.x, 0), CELL_SIZE)
				result.add_frame(action, atlas)
	return result


func play_action(action: String, direction: String) -> void:
	var name := "%s_%s" % [action, direction]
	if sprite_frames.has_animation(action):
		name = action
		_resume_direction = direction
	if not sprite_frames.has_animation(name):
		push_error("Unknown character animation: " + name)
		return
	play(name)


func _on_animation_finished() -> void:
	if animation.begins_with("bob_"):
		play_action("idle", animation.trim_prefix("bob_"))
	elif PLAYER_ACTIONS.has(animation):
		play_action("idle", _resume_direction)
	elif ROLE_ACTIONS.has(character_id) and ROLE_ACTIONS[character_id].has(animation):
		if ROLE_ACTIONS[character_id][animation][4]:
			play_action("idle", _resume_direction)
