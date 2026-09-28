extends RefCounted
class_name FoundationJournal

const Content = preload("res://foundation/content.gd")
const SCHEMA := 1
var path: String
var saved_count := 0
var last_content_version := ""

func _init(save_path: String) -> void:
	path = save_path

func save(simulation: FoundationSimulation) -> Dictionary:
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		return {"ok": false, "reason": "Browser storage is not persistent; enable IndexedDB/cookies"}
	if simulation.history.is_empty():
		return {"ok": false, "reason": "No coherent recorded tick to save"}
	if saved_count == simulation.history.size() and simulation.content.version == last_content_version:
		return {"ok": true, "reason": "Already saved"}
	if saved_count == 0 or simulation.history.size() <= saved_count or simulation.content.version != last_content_version:
		return _rewrite(simulation)
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		return {"ok": false, "reason": "Cannot open save: %s" % FileAccess.get_open_error()}
	file.seek_end()
	for index in range(saved_count, simulation.history.size()):
		file.store_line(_encode({"schema": SCHEMA, "tick": index, "state": simulation.history[index]}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return {"ok": false, "reason": "Save write failed: %s" % error}
	saved_count = simulation.history.size()
	return {"ok": true, "reason": "Saved tick %d" % simulation.state.tick}

func _rewrite(simulation: FoundationSimulation) -> Dictionary:
	var next_path := path + ".next"
	var file := FileAccess.open(next_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "Cannot stage save: %s" % FileAccess.get_open_error()}
	file.store_line(_encode({"schema": SCHEMA, "kind": "content", "content": simulation.content, "content_versions": simulation.content_versions}))
	for index in simulation.history.size():
		file.store_line(_encode({"schema": SCHEMA, "tick": index, "state": simulation.history[index]}))
	file.store_line(_encode({"schema": SCHEMA, "kind": "head", "state": simulation.state}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return {"ok": false, "reason": "Save staging failed: %s" % error}
	var checked := _read_candidate(next_path)
	if not checked.ok or not checked.complete or checked.history.size() != simulation.history.size():
		return {"ok": false, "reason": "Staged save did not verify"}
	var absolute := ProjectSettings.globalize_path(path)
	var next_absolute := ProjectSettings.globalize_path(next_path)
	var backup := absolute + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(backup)
		var move_old := DirAccess.rename_absolute(absolute, backup)
		if move_old != OK:
			return {"ok": false, "reason": "Could not protect previous save: %s" % move_old}
	var promote := DirAccess.rename_absolute(next_absolute, absolute)
	if promote != OK:
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(backup, absolute)
		return {"ok": false, "reason": "Could not promote staged save: %s" % promote}
	saved_count = simulation.history.size()
	last_content_version = str(simulation.content.version)
	return {"ok": true, "reason": "Saved tick %d" % simulation.state.tick}

static func load(save_path: String) -> Dictionary:
	var candidates := [save_path, save_path + ".next", save_path + ".bak"]
	var last_error := "No save found"
	var partial_staged: Dictionary = {}
	for candidate in candidates:
		if not FileAccess.file_exists(candidate): continue
		var result := _read_candidate(candidate)
		if result.ok:
			if candidate == save_path + ".next" and not result.complete:
				partial_staged = result
				continue
			return result
		if str(result.reason).begins_with("Unsupported save version"):
			return result
		last_error = str(result.reason)
	if not partial_staged.is_empty(): return partial_staged
	return {"ok": false, "reason": last_error}

static func _read_candidate(candidate: String) -> Dictionary:
	var file := FileAccess.open(candidate, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "Cannot read save"}
	var content: Dictionary = {}
	var content_versions: Dictionary = {}
	var history: Array[Dictionary] = []
	var current: Dictionary = {}
	var error := ""
	var saw_head := false
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var decoded := _decode(line)
		if decoded.is_empty():
			error = "Interrupted or corrupt save record; recovered last complete tick"
			break
		if decoded.get("schema") != SCHEMA:
			return {"ok": false, "reason": "Unsupported save version; original file retained"}
		if decoded.get("kind") == "content":
			var raw_content = decoded.get("content", {})
			if not raw_content is Dictionary:
				return {"ok": false, "reason": "Invalid content in save; original file retained"}
			content = raw_content
			var raw_versions = decoded.get("content_versions", {content.get("version", ""): content})
			if not raw_versions is Dictionary:
				return {"ok": false, "reason": "Invalid content versions in save; original file retained"}
			content_versions = raw_versions
			if not Content.validate(content).is_empty():
				return {"ok": false, "reason": "Invalid content in save; original file retained"}
			for version in content_versions:
				if not content_versions[version] is Dictionary or not Content.validate(content_versions[version]).is_empty():
					return {"ok": false, "reason": "Invalid historical content in save; original file retained"}
		elif decoded.get("kind") == "head":
			if not decoded.get("state") is Dictionary:
				return {"ok": false, "reason": "Invalid save head"}
			current = decoded.state
			saw_head = true
			if history.is_empty() or int(current.get("tick", -1)) != history[-1].tick or not _valid_snapshot(current, content_versions):
				return {"ok": false, "reason": "Save head does not match history"}
		elif decoded.has("state"):
			if not decoded.state is Dictionary:
				error = "Invalid state record; recovered last complete tick"
				break
			if int(decoded.get("tick", -1)) != history.size():
				error = "Non-contiguous save history; recovered last complete tick"
				break
			var snapshot: Dictionary = decoded.state
			if int(snapshot.get("tick", -1)) != history.size() or not _valid_snapshot(snapshot, content_versions):
				error = "State tick mismatch; recovered last complete tick"
				break
			history.append(snapshot)
			current = snapshot
	file.close()
	if content.is_empty() or history.is_empty():
		return {"ok": false, "reason": "No complete save state"}
	return {"ok": true, "reason": error, "complete": saw_head and error.is_empty(), "content": content, "content_versions": content_versions, "history": history, "current": current, "source": candidate}

static func _encode(payload: Dictionary) -> String:
	var data := JSON.stringify(payload)
	return JSON.stringify({"data": data, "sha256": data.sha256_text()})

static func _decode(line: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(line) != OK:
		return {}
	var wrapper = parser.data
	if not wrapper is Dictionary or not wrapper.get("data") is String or not wrapper.get("sha256") is String:
		return {}
	if str(wrapper.data).sha256_text() != str(wrapper.sha256):
		return {}
	if parser.parse(wrapper.data) != OK:
		return {}
	var payload = parser.data
	return payload if payload is Dictionary else {}

static func _valid_snapshot(snapshot: Dictionary, versions: Dictionary) -> bool:
	if not _number(snapshot.get("tick")) or int(snapshot.tick) < 0:
		return false
	if not snapshot.get("actors") is Dictionary or not snapshot.get("flags") is Dictionary or not snapshot.get("action") is Dictionary or not snapshot.get("dialogue") is Dictionary:
		return false
	if not snapshot.get("events") is Array or not snapshot.get("diary_observations") is Array or not snapshot.get("current_knowledge") is Array:
		return false
	if not snapshot.get("commitments_started") is Array or not snapshot.get("completed_world_commands") is Array or not snapshot.get("diagnostics") is Dictionary:
		return false
	if not snapshot.get("code") is String or not snapshot.get("loop_index") is float and not snapshot.get("loop_index") is int:
		return false
	if not snapshot.get("content_version") is String or not versions.has(snapshot.content_version):
		return false
	if not snapshot.action.is_empty():
		if not snapshot.action.get("id") is String or not _number(snapshot.action.get("progress")) or not _number(snapshot.action.get("duration")):
			return false
	if not snapshot.dialogue.is_empty():
		if not _number(snapshot.dialogue.get("cursor")) or not _number(snapshot.dialogue.get("remaining")) or not snapshot.dialogue.get("line") is String or not snapshot.dialogue.get("completed_commands") is Array:
			return false
	for event in snapshot.events:
		if not event is Dictionary or not _number(event.get("tick")) or not event.get("category") is String or not event.get("actor") is String or not event.get("detail") is String:
			return false
	for id in snapshot.commitments_started:
		if not id is String: return false
	for id in snapshot.completed_world_commands:
		if not id is String: return false
	var rooms: Dictionary = {}
	for room in versions[snapshot.content_version].rooms: rooms[room.id] = true
	for id in ["amelia", "chatterbox", "guest"]:
		var actor = snapshot.actors.get(id)
		if not actor is Dictionary or not rooms.has(actor.get("room", "")) or not _number(actor.get("x")) or not _number(actor.get("y")):
			return false
		if not actor.get("activity") is String or not actor.get("destination") is String:
			return false
	return true

static func _number(value: Variant) -> bool:
	return value is int or value is float
