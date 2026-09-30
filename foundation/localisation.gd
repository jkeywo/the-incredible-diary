extends Node
signal language_changed
const Messages = preload("res://foundation/message_text.gd")
const Text = preload("res://localisation/source_text.gd")
const SUPPORTED := ["en"]
var preference := "automatic"
var _aliases: Translation

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var prefs := get_node("/root/Preferences")
	prefs.changed.connect(_preferences_changed)
	_preferences_changed()
	if OS.is_debug_build() and "--pseudolocalisation" in OS.get_cmdline_user_args():
		set_pseudolocalisation(true)

static func choose_locale(preferred: Array, supported: Array = SUPPORTED) -> String:
	for candidate in preferred:
		var locale := str(candidate).replace("-","_")
		for available in supported:
			if str(available).to_lower() == locale.to_lower(): return available
		var language := locale.get_slice("_",0).to_lower()
		if language in supported: return language
	return "en"

func automatic_locale() -> String:
	if OS.has_feature("web"):
		var encoded: Variant = JavaScriptBridge.eval("JSON.stringify(navigator.languages || [navigator.language])")
		var preferred: Variant = JSON.parse_string(str(encoded))
		if preferred is Array: return choose_locale(preferred)
	return choose_locale([OS.get_locale()])

func _preferences_changed() -> void:
	preference = get_node("/root/Preferences").language
	TranslationServer.set_locale(automatic_locale() if preference == "automatic" else choose_locale([preference]))
	_refresh_aliases()
	language_changed.emit()

func set_language(value: String) -> void:
	preference = value if value in SUPPORTED or value == "automatic" else "automatic"
	var prefs := get_node("/root/Preferences")
	prefs.language = preference
	prefs.save_settings()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { localStorage.setItem('diary-language', %s); } catch (_) {}" % JSON.stringify(preference))
	_preferences_changed()

func set_pseudolocalisation(enabled: bool) -> void:
	TranslationServer.get_or_add_domain(&"").pseudolocalization_expansion_ratio = 0.3
	TranslationServer.pseudolocalization_enabled = enabled
	_refresh_aliases()
	language_changed.emit()

func _refresh_aliases() -> void:
	Messages.clear_cache()
	# Native Controls retain their English source property and retranslate it on
	# locale changes. Stable IDs remain the authority in the CSV catalogues.
	if _aliases != null: TranslationServer.remove_translation(_aliases)
	_aliases = Translation.new()
	_aliases.locale = TranslationServer.get_locale()
	var pseudo := TranslationServer.pseudolocalization_enabled
	TranslationServer.pseudolocalization_enabled = false
	for id in Text.SOURCES:
		var source: String = Text.SOURCES[id]
		if source.contains("%") or source.contains("{"): continue
		var translated := TranslationServer.translate(id)
		if translated == id: translated = Text.ENGLISH[id]
		_aliases.add_message(source,translated)
	TranslationServer.pseudolocalization_enabled = pseudo
	TranslationServer.add_translation(_aliases)
	get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	for node in get_tree().get_nodes_in_group("localised_text"): Messages.refresh(node)
	_redraw(get_tree().root)

func _redraw(node: Node) -> void:
	if node is CanvasItem: node.queue_redraw()
	for child in node.get_children(): _redraw(child)
