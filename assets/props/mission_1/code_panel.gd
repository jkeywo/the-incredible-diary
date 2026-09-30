@tool
extends "res://assets/props/mission_1/stateful_prop.gd"
const Messages = preload("res://foundation/message_text.gd")
const Text = preload("res://localisation/source_text.gd")
## Readout interiors measured on the 240 x 108 housing; origin is bottom-centre.
const DISPLAY := Rect2(-84, -70, 78, 24)
const STATUS_PANEL := Rect2(14, -70, 68, 24)
var digits: Label
var status: Label
var entering := false

func _ready() -> void:
 super._ready()
 digits = _label("Digits", DISPLAY.position, DISPLAY.size, 16)
 status = _label("SteamStatus", STATUS_PANEL.position, STATUS_PANEL.size, 16)

func _label(id: String, location: Vector2, dimensions: Vector2, font_size: int) -> Label:
 var label := Label.new()
 label.name = id
 label.position = location
 label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 label.add_theme_font_size_override("font_size",font_size)
 label.size = dimensions
 label.add_theme_color_override("font_color",Color("ffe8a3"))
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(label)
 label.size = dimensions
 return label

func present(state: Dictionary) -> void:
 entering = state.code_open
 digits.text = " ".join(str(state.entry).rpad(3,"_").split("")) if state.code_open else "_ _ _"
 Messages.assign(status,"text",Text.UI_STEAM_OFF if state.flags.get("steam_off",false) else Text.UI_STEAM_ON)
