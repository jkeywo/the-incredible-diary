extends RefCounted
class_name FoundationGithubProject

const Content = preload("res://foundation/content.gd")

const MANIFEST_PATH := ".incredible-diary/project.json"
const SCENARIO_PATH := ".incredible-diary/scenario.json"
const FORMAT := "the-incredible-diary-project"
const SCHEMA := 1
const AUTHORED_FIELDS := ["schema", "version", "assets", "scenes", "storylets", "rooms", "connections", "actors", "commitments", "interactions", "dialogue"]
const ENTRY_FIELDS := {
	"rooms": ["id", "name", "bounds", "walkable", "background_asset"],
	"connections": ["id", "from", "to", "from_x", "from_y", "to_x", "to_y", "requires_flag"],
	"actors": ["id", "room", "x", "y", "sprite"],
	"commitments": ["id", "actor", "at_tick", "room", "x", "y", "speed"],
	"interactions": ["id", "room", "x", "y", "radius", "label", "duration_ticks", "effect", "effect_ticks"],
	"storylets": ["id", "scene", "room", "required_actors", "start_tick", "end_tick", "required_flags", "priority", "label"],
}
const ASSET_FIELDS := ["name", "mime", "sha256", "base64", "width", "height"]

static func package(document: FoundationAuthoringDocument) -> Dictionary:
	var errors: Array[String] = document.validate()
	if not errors.is_empty():
		return {"ok": false, "reason": "; ".join(errors), "files": {}}
	var scenario: Dictionary = document.candidate()
	var private_fields := _unexpected_fields(scenario)
	if not private_fields.is_empty():
		return {"ok": false, "reason": "Scenario contains fields outside the authored project: " + ", ".join(private_fields), "files": {}}
	var manifest := {"format": FORMAT, "schema": SCHEMA, "scenario": SCENARIO_PATH}
	return {"ok": true, "files": {MANIFEST_PATH: JSON.stringify(manifest, "\t"), SCENARIO_PATH: JSON.stringify(scenario, "\t")}, "scenario": scenario}

static func open_files(files: Dictionary) -> Dictionary:
	if not files.has(MANIFEST_PATH):
		return {"ok": false, "reason": "Repository has no Incredible Diary project manifest"}
	var manifest_parser := JSON.new()
	if manifest_parser.parse(str(files[MANIFEST_PATH])) != OK:
		return {"ok": false, "reason": "Repository project manifest is invalid or unsupported"}
	var manifest: Variant = manifest_parser.data
	if not manifest is Dictionary or manifest.get("format") != FORMAT or manifest.get("schema") != SCHEMA or manifest.get("scenario") != SCENARIO_PATH:
		return {"ok": false, "reason": "Repository project manifest is invalid or unsupported"}
	if not files.has(SCENARIO_PATH):
		return {"ok": false, "reason": "Repository project scenario is missing"}
	var scenario_parser := JSON.new()
	if scenario_parser.parse(str(files[SCENARIO_PATH])) != OK:
		return {"ok": false, "reason": "Repository project scenario is not valid JSON"}
	var scenario: Variant = scenario_parser.data
	if not scenario is Dictionary:
		return {"ok": false, "reason": "Repository project scenario is not a JSON object"}
	var private_fields := _unexpected_fields(scenario)
	if not private_fields.is_empty():
		return {"ok": false, "reason": "Repository project contains unsupported scenario fields: " + ", ".join(private_fields)}
	var errors: Array[String] = Content.validate(scenario)
	if not errors.is_empty():
		return {"ok": false, "reason": "; ".join(errors)}
	return {"ok": true, "content": scenario}

static func _unexpected_fields(scenario: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for key in scenario:
		if not key in AUTHORED_FIELDS:
			result.append(str(key))
	for group in ENTRY_FIELDS:
		if not scenario.get(group) is Array:
			continue
		for index in scenario[group].size():
			var entry: Variant = scenario[group][index]
			if entry is Dictionary:
				for key in entry:
					if not key in ENTRY_FIELDS[group]:
						result.append("%s[%d].%s" % [group, index, key])
	if scenario.get("assets") is Dictionary:
		for asset_id in scenario.assets:
			var asset: Variant = scenario.assets[asset_id]
			if asset is Dictionary:
				for key in asset:
					if not key in ASSET_FIELDS:
						result.append("assets.%s.%s" % [asset_id, key])
	result.sort()
	return result
