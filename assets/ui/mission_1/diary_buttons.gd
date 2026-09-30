extends RefCounted
## Diary-local sprite buttons. The bundled font renders identically on PC and web.
const FRAME = preload("res://assets/ui/popup/nine_piece_style.gd")
const FONT = preload("res://assets/fonts/lora/Lora-Variable.ttf")
const TINTS := {"normal":Color.WHITE,"hover":Color(1.22,1.17,1.08),"pressed":Color(0.74,0.78,0.86),"disabled":Color(0.62,0.64,0.68,0.85)}

static func background(tint: Color) -> StyleBox:
	var style := FRAME.new()
	style.tint = tint
	style.set_content_margin(SIDE_LEFT,18)
	style.set_content_margin(SIDE_RIGHT,18)
	style.set_content_margin(SIDE_TOP,8)
	style.set_content_margin(SIDE_BOTTOM,8)
	return style

static func make_theme() -> Theme:
	var theme := Theme.new()
	var font := FontVariation.new()
	font.base_font = FONT
	font.variation_opentype = {"wght":600.0}
	theme.set_font("font","Button",font)
	theme.set_font_size("font_size","Button",20)
	for state in TINTS: theme.set_stylebox(state,"Button",background(TINTS[state]))
	for color in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		theme.set_color(color,"Button",Color("fff0cf"))
	theme.set_color("font_disabled_color","Button",Color("a9a79e"))
	theme.set_color("font_outline_color","Button",Color("0a1628"))
	theme.set_constant("outline_size","Button",1)
	# An outline only: keep the textured hover/pressed background underneath.
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("ffe1a0")
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(2)
	theme.set_stylebox("focus","Button",focus)
	return theme

static func square(button: Button) -> void:
	button.custom_minimum_size = Vector2(44,44)
	button.add_theme_font_size_override("font_size",22)
	for state in TINTS:
		var style := FRAME.new()
		style.tint = TINTS[state]
		style.set_content_margin_all(6)
		button.add_theme_stylebox_override(state,style)
