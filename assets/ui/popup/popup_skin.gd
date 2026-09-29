extends RefCounted
## Applied locally to player-facing dialogs only; never set as the project theme.
const Frame = preload("res://assets/ui/popup/nine_piece_style.gd")
const TAB = preload("res://assets/ui/popup/tab.png")

static func tab_style(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = TAB
	style.modulate_color = tint
	style.texture_margin_left = 24
	style.texture_margin_right = 24
	style.texture_margin_top = 12
	style.texture_margin_bottom = 8
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_stylebox("panel", "AcceptDialog", Frame.new())
	for type in ["Button", "Label", "TabContainer"]:
		theme.set_color("font_color", type, Color("f4dfb4"))
	theme.set_color("font_selected_color", "TabContainer", Color("fff1ce"))
	theme.set_color("font_unselected_color", "TabContainer", Color("c3bda9"))
	theme.set_stylebox("tab_selected", "TabContainer", tab_style())
	theme.set_stylebox("tab_unselected", "TabContainer", tab_style(Color(0.65, 0.7, 0.8)))
	theme.set_stylebox("tab_hovered", "TabContainer", tab_style(Color(1.15, 1.15, 1.15)))
	var body := StyleBoxEmpty.new()
	body.content_margin_top = 22
	theme.set_stylebox("panel", "TabContainer", body)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("263e54") if state == "hover" else Color("102138")
		style.border_color = Color("ebc37c")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_content_margin_all(10)
		if state == "focus": style.bg_color = Color.TRANSPARENT
		theme.set_stylebox(state, "Button", style)
	return theme

static func decorate(dialog: AcceptDialog) -> VBoxContainer:
	dialog.theme = make_theme()
	dialog.borderless = true
	dialog.unresizable = true
	var message := dialog.dialog_text
	dialog.dialog_text = ""
	var content := VBoxContainer.new()
	content.name = "PopupContent"
	content.custom_minimum_size.x = 430
	content.add_theme_constant_override("separation", 20)
	dialog.add_child(content)
	var heading := Label.new()
	heading.text = dialog.title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	content.add_child(heading)
	if not message.is_empty():
		add_message(content, message)
	return content

static func add_message(content: VBoxContainer, message: String) -> Label:
	var label := Label.new()
	label.name = "Message"
	label.custom_minimum_size.x = 430
	label.size.x = 430
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label
