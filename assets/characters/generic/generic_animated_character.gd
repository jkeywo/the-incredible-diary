@tool
extends AnimatedSprite2D
## First-playable idle, walk and conversation cycles for the recolourable NPCs.
## The mask atlas follows the displayed frame so skin/garment tints stay aligned.

const CELL_SIZE := Vector2i(32, 48)
const DIRECTIONS := ["down", "left", "up", "right"]
const ACTIONS := {"idle": [0, 2, 2.0], "walk": [2, 4, 8.0], "talk": [6, 3, 4.0], "bob": [9, 4, 8.0]}
const SAILOR_ACTIONS := {
	"handle_baggage": [0, 4, 6.0, true],
	"demonstrate": [4, 4, 6.0, true],
	"restore_steam": [8, 4, 6.0, true],
	"raise_alarm": [12, 4, 10.0, false],
}
const IDS := ["sailor", "guest_male_jacket", "guest_male_waistcoat", "guest_female_dress", "guest_female_coat"]
const BASE_LUMA := {
	"sailor": Vector2(0.547, 1.0),
	"guest_male_jacket": Vector2(0.528, 0.272),
	"guest_male_waistcoat": Vector2(0.546, 0.331),
	"guest_female_dress": Vector2(0.562, 0.227),
	"guest_female_coat": Vector2(0.638, 0.214),
}
const RECOLOR_SHADER := preload("res://assets/characters/generic/recolor.gdshader")

@export_enum("sailor", "guest_male_jacket", "guest_male_waistcoat", "guest_female_dress", "guest_female_coat") var character_id := "sailor":
	set(value):
		character_id = value
		if is_node_ready():
			_refresh()

@export_enum("down", "left", "up", "right") var initial_direction := "down":
	set(value):
		initial_direction = value
		if is_node_ready():
			play_action("idle", value)

@export var recolor_skin := false:
	set(value):
		recolor_skin = value
		_update_colors()

@export var skin_tone := Color(0.82, 0.58, 0.42):
	set(value):
		skin_tone = value
		_update_colors()

@export var recolor_garment := false:
	set(value):
		recolor_garment = value
		_update_colors()

@export var garment_color := Color(0.32, 0.56, 0.65):
	set(value):
		garment_color = value
		_update_colors()

var _mask_frames: Dictionary = {}
var _resume_direction := "down"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	offset = Vector2(0, -24)
	frame_changed.connect(_sync_mask)
	animation_finished.connect(_on_animation_finished)
	_refresh()


func _refresh() -> void:
	if not IDS.has(character_id):
		push_error("Unknown generic character: " + character_id)
		return
	var sprite_sheet := load("res://assets/characters/generic/%s_sprites.png" % character_id) as Texture2D
	var mask_sheet := load("res://assets/characters/generic/%s_sprites_mask.png" % character_id) as Texture2D
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_mask_frames.clear()
	for direction_index in range(DIRECTIONS.size()):
		for action in ACTIONS:
			var definition: Array = ACTIONS[action]
			var name := "%s_%s" % [action, DIRECTIONS[direction_index]]
			frames.add_animation(name)
			frames.set_animation_speed(name, definition[2])
			frames.set_animation_loop(name, action != "bob")
			var paired_masks: Array[AtlasTexture] = []
			for frame_index in range(definition[1]):
				var region := Rect2i(
					Vector2i((definition[0] + frame_index) * CELL_SIZE.x, direction_index * CELL_SIZE.y),
					CELL_SIZE
				)
				var sprite_atlas := AtlasTexture.new()
				sprite_atlas.atlas = sprite_sheet
				sprite_atlas.region = region
				frames.add_frame(name, sprite_atlas)
				var mask_atlas := AtlasTexture.new()
				mask_atlas.atlas = mask_sheet
				mask_atlas.region = region
				paired_masks.append(mask_atlas)
			_mask_frames[name] = paired_masks
	if character_id == "sailor":
		var action_sheet := load("res://assets/characters/actions/sailor_actions.png") as Texture2D
		var action_mask_sheet := load("res://assets/characters/actions/sailor_actions_mask.png") as Texture2D
		for action in SAILOR_ACTIONS:
			var definition: Array = SAILOR_ACTIONS[action]
			frames.add_animation(action)
			frames.set_animation_speed(action, definition[2])
			frames.set_animation_loop(action, definition[3])
			var paired_action_masks: Array[AtlasTexture] = []
			for frame_index in range(definition[1]):
				var region := Rect2i(Vector2i((definition[0] + frame_index) * CELL_SIZE.x, 0), CELL_SIZE)
				var sprite_atlas := AtlasTexture.new()
				sprite_atlas.atlas = action_sheet
				sprite_atlas.region = region
				frames.add_frame(action, sprite_atlas)
				var mask_atlas := AtlasTexture.new()
				mask_atlas.atlas = action_mask_sheet
				mask_atlas.region = region
				paired_action_masks.append(mask_atlas)
			_mask_frames[action] = paired_action_masks
	sprite_frames = frames
	var shader_material := ShaderMaterial.new()
	shader_material.shader = RECOLOR_SHADER
	shader_material.set_shader_parameter("skin_base_luma", BASE_LUMA[character_id].x)
	shader_material.set_shader_parameter("garment_base_luma", BASE_LUMA[character_id].y)
	material = shader_material
	_update_colors()
	play_action("idle", initial_direction)


func play_action(action: String, direction: String) -> void:
	var name := "%s_%s" % [action, direction]
	if sprite_frames != null and sprite_frames.has_animation(action):
		name = action
		_resume_direction = direction
	if sprite_frames == null or not sprite_frames.has_animation(name):
		push_error("Unknown generic animation: " + name)
		return
	play(name)
	_sync_mask()


func _sync_mask() -> void:
	if not material is ShaderMaterial or not _mask_frames.has(animation):
		return
	var paired_masks: Array = _mask_frames[animation]
	if frame >= 0 and frame < paired_masks.size():
		(material as ShaderMaterial).set_shader_parameter("recolor_mask", paired_masks[frame])


func _update_colors() -> void:
	if not material is ShaderMaterial:
		return
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("recolor_skin", recolor_skin)
	shader_material.set_shader_parameter("recolor_garment", recolor_garment and character_id != "sailor")
	shader_material.set_shader_parameter("skin_tone", skin_tone)
	shader_material.set_shader_parameter("garment_color", garment_color)


func _on_animation_finished() -> void:
	if animation.begins_with("bob_"):
		play_action("idle", animation.trim_prefix("bob_"))
	elif SAILOR_ACTIONS.has(animation):
		play_action("idle", _resume_direction)
