@tool
extends Sprite2D
## Static four-facing NPC sprite. Skin and one guest garment can be recoloured
## independently using the paired red/green mask image.

const DIRECTIONS := ["down", "left", "up", "right"]
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

@export_enum("down", "left", "up", "right") var facing := "down":
	set(value):
		facing = value
		if is_node_ready():
			_refresh()

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


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	offset = Vector2(0, -24)
	_refresh()


func _refresh() -> void:
	if not BASE_LUMA.has(character_id):
		push_error("Unknown generic character: " + character_id)
		return
	var sheet := load("res://assets/characters/generic/%s.png" % character_id) as Texture2D
	var mask := load("res://assets/characters/generic/%s_mask.png" % character_id) as Texture2D
	texture = sheet
	region_enabled = true
	region_rect = Rect2(DIRECTIONS.find(facing) * 32, 0, 32, 48)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = RECOLOR_SHADER
	shader_material.set_shader_parameter("recolor_mask", mask)
	shader_material.set_shader_parameter("skin_base_luma", BASE_LUMA[character_id].x)
	shader_material.set_shader_parameter("garment_base_luma", BASE_LUMA[character_id].y)
	material = shader_material
	_update_colors()


func _update_colors() -> void:
	if not material is ShaderMaterial:
		return
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("recolor_skin", recolor_skin)
	shader_material.set_shader_parameter("recolor_garment", recolor_garment and character_id != "sailor")
	shader_material.set_shader_parameter("skin_tone", skin_tone)
	shader_material.set_shader_parameter("garment_color", garment_color)
