extends RefCounted
## Locale-independent records. Only resolve()/ui() depend on the chosen language.
const Text = preload("res://localisation/source_text.gd")
static var _ids: Dictionary = {}
static var _patterns: Array = []
static var _rendered: Dictionary = {}
static var _raw_domain: TranslationDomain

static func _prepare() -> void:
	if not _ids.is_empty(): return
	for id in Text.SOURCES:
		var source: String = Text.SOURCES[id]
		_ids[source] = id
		if not (source.contains("%") or source.contains("{")) or source.length() < 8: continue
		var pattern := RegEx.new()
		var tokens := RegEx.new()
		tokens.compile("%%|%[-+0-9.]*[sdf]|\\{[A-Za-z][A-Za-z0-9_]*\\}")
		var position := 0
		var expression := "(?s)^"
		var count := 0
		var names: Array[String] = []
		for token in tokens.search_all(source):
			expression += _escape(source.substr(position, token.get_start()-position))
			if token.get_string() == "%%": expression += "%"
			else:
				expression += "(.+?)"
				count += 1
				names.append(token.get_string().trim_prefix("{").trim_suffix("}") if token.get_string().begins_with("{") else "arg%d" % count)
			position = token.get_end()
		expression += _escape(source.substr(position)) + "$"
		if count > 0 and tokens.sub(source,"",true).strip_edges().length() >= 3 and pattern.compile(expression) == OK:
			_patterns.append({"id":id,"regex":pattern,"count":count,"names":names})

static func _escape(value: String) -> String:
	var result := ""
	for character in value:
		if character in "\\.^$|?*+()[]{}": result += "\\"
		result += character
	return result

static func make_ref(id: String, arguments: Dictionary = {}, fallback := "") -> Dictionary:
	var source: String = Text.SOURCES.get(id, fallback)
	var source_arguments := {}
	for key in arguments:
		var value: Variant = arguments[key]
		source_arguments[key] = str(value.get("fallback","")) if value is Dictionary else value
	return {"id":id,"revision":source.sha256_text(),"arguments":arguments.duplicate(true),"fallback":fallback if not fallback.is_empty() else str(Text.ENGLISH.get(id,source)).format(source_arguments)}

static func literal(value: String) -> Dictionary:
	return {"id":"","revision":"","arguments":{},"fallback":value}

static func capture(source: String, id := "") -> Dictionary:
	# Only call at emission or for current UI, never to migrate recorded literals.
	_prepare()
	if not id.is_empty():
		return make_ref(id,{},source) if Text.SOURCES.get(id) == source else literal(source)
	if _ids.has(source): return make_ref(_ids[source],{},source)
	for item in _patterns:
		var match_result: RegExMatch = item.regex.search(source)
		if match_result == null: continue
		var arguments := {}
		for index in item.count:
			var value := match_result.get_string(index+1)
			arguments[item.names[index]] = make_ref(_ids[value],{},value) if _ids.has(value) else value
		return make_ref(item.id,arguments,source)
	return literal(source)

static func resolve(message: Dictionary) -> String:
	var id := str(message.get("id",""))
	var fallback := str(message.get("fallback",""))
	if not Text.SOURCES.has(id) or str(Text.SOURCES[id]).sha256_text() != message.get("revision",""): return fallback
	var arguments := {}
	for key in message.get("arguments",{}):
		var value: Variant = message.arguments[key]
		arguments[key] = resolve(value) if value is Dictionary else value
	var translated := _translate(id)
	if translated == id: translated = Text.ENGLISH[id]
	return _format(str(translated),arguments)

static func _translate(id: String, plural_id := "", count := 1) -> String:
	if not TranslationServer.pseudolocalization_enabled:
		return TranslationServer.translate(id) if plural_id.is_empty() else TranslationServer.translate_plural(id,plural_id,count)
	# Godot protects printf placeholders during pseudo translation, but not named
	# braces. Read the raw template, protect its arguments, then pseudolocalise.
	if _raw_domain == null:
		_raw_domain = TranslationDomain.new()
		for translation in TranslationServer.get_or_add_domain(&"").get_translations():
			_raw_domain.add_translation(translation)
	return _raw_domain.translate(id) if plural_id.is_empty() else _raw_domain.translate_plural(id,plural_id,count)

static func _format(template: String, arguments: Dictionary) -> String:
	if not TranslationServer.pseudolocalization_enabled: return template.format(arguments)
	var tokens := RegEx.new()
	tokens.compile("\\{([A-Za-z][A-Za-z0-9_]*)\\}")
	var protected := template.replace("%","%%")
	var values: Array = []
	for token in tokens.search_all(protected): values.append(arguments.get(token.get_string(1),token.get_string()))
	protected = tokens.sub(protected,"%s",true)
	return str(TranslationServer.pseudolocalize(protected)) % values

static func ui(source: String) -> String:
	if not _rendered.has(source):
		if _rendered.size() > 4096: _rendered.clear()
		_rendered[source] = resolve(capture(source))
	return _rendered[source]

static func clear_cache() -> void:
	_rendered.clear()
	_raw_domain = null

static func source(id: String, arguments: Dictionary = {}) -> String:
	return str(Text.ENGLISH.get(id, "")).format(arguments)

static func assign(node: Node, property: String, source: String) -> void:
	# Retain the source for locale changes, including text set only at construction.
	var properties: Dictionary = node.get_meta("localised_properties",{})
	properties[property] = source
	node.set_meta("localised_properties",properties)
	node.add_to_group("localised_text")
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.set(property,ui(source))

static func assign_ref(node: Node, property: String, message: Dictionary) -> void:
	var properties: Dictionary = node.get_meta("localised_references",{})
	properties[property] = message
	node.set_meta("localised_references",properties)
	node.add_to_group("localised_text")
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.set(property,resolve(message))

static func refresh(node: Node) -> void:
	for property in node.get_meta("localised_properties",{}):
		node.set(property,ui(node.get_meta("localised_properties")[property]))
	for property in node.get_meta("localised_references",{}):
		node.set(property,resolve(node.get_meta("localised_references")[property]))

static func field(record: Dictionary, name: String) -> String:
	var message: Variant = record.get(name+"_ref")
	var source := str(record.get(name,""))
	return resolve(message) if message is Dictionary and message.get("fallback","") == source else source

static func valid(message: Variant, depth := 0) -> bool:
	if depth > 8 or not message is Dictionary: return false
	for key in ["id","revision","fallback"]:
		if not message.get(key) is String: return false
	if not message.get("arguments") is Dictionary: return false
	for value in message.arguments.values():
		if value is Dictionary and not valid(value,depth+1): return false
		if not (value is Dictionary or value is String or value is int or value is float or value is bool): return false
	return true

static func plural(id: String, plural_id: String, count: int, arguments: Dictionary = {}) -> String:
	var translated := _translate(id,plural_id,count)
	if translated in [id,plural_id]: translated = Text.ENGLISH.get(id if count == 1 else plural_id,"")
	var values := arguments.duplicate()
	values["count"] = count
	return _format(str(translated),values)
