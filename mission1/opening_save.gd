extends RefCounted
## Save for the playable Mission 1 opening slice. Keep the current leg's
## recorded positions alongside the current state for later rewind work.

const DEFAULT_PATH := "user://mission1_opening_v1.json"
const SCHEMA := 1


static func has_any(path: String = DEFAULT_PATH) -> bool:
	for suffix in ["", ".next", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			return true
	return false


static func load_saved(path: String = DEFAULT_PATH) -> Dictionary:
	var best: Dictionary = {}
	for suffix in ["", ".next", ".bak"]:
		var candidate: String = path + str(suffix)
		if not FileAccess.file_exists(candidate):
			continue
		var result := _read(candidate)
		if result.ok and (best.is_empty() or int(result.data.elapsed_ms) > int(best.data.elapsed_ms)):
			best = result
	return best if not best.is_empty() else {"ok": false, "reason": "No valid Mission 1 save"}


static func clear(path: String = DEFAULT_PATH) -> Dictionary:
	for suffix in ["", ".next", ".bak"]:
		var candidate: String = path + str(suffix)
		if not FileAccess.file_exists(candidate):
			continue
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
		if error != OK:
			return {"ok": false, "reason": "Could not clear the Mission 1 save (%s)" % error}
	if OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()
	return {"ok": true}


static func write(data: Dictionary, path: String = DEFAULT_PATH) -> Dictionary:
	if not _valid(data):
		return {"ok": false, "reason": "Mission 1 save data is invalid"}
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		return {"ok": false, "reason": "Browser storage is not persistent"}
	var body := JSON.stringify(data)
	var wrapper := JSON.stringify({"body": body, "sha256": body.sha256_text()})
	var staged := path + ".next"
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "Could not stage Mission 1 save"}
	file.store_string(wrapper)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not _read(staged).ok:
		return {"ok": false, "reason": "Mission 1 save verification failed"}
	var primary_abs := ProjectSettings.globalize_path(path)
	var staged_abs := ProjectSettings.globalize_path(staged)
	var backup_abs := ProjectSettings.globalize_path(path + ".bak")
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			var old_backup_error := DirAccess.remove_absolute(backup_abs)
			if old_backup_error != OK:
				return {"ok": false, "reason": "Could not rotate Mission 1 backup"}
		var backup_error := DirAccess.rename_absolute(primary_abs, backup_abs)
		if backup_error != OK:
			return {"ok": false, "reason": "Could not protect previous Mission 1 save"}
	var promote_error := DirAccess.rename_absolute(staged_abs, primary_abs)
	if promote_error != OK:
		if FileAccess.file_exists(path + ".bak") and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(backup_abs, primary_abs)
		return {"ok": false, "reason": "Could not promote Mission 1 save"}
	if OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()
	return {"ok": true}


static func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var wrapper: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not wrapper is Dictionary or not wrapper.get("body") is String or not wrapper.get("sha256") is String:
		return {"ok": false}
	if str(wrapper.body).sha256_text() != str(wrapper.sha256):
		return {"ok": false}
	var data: Variant = JSON.parse_string(str(wrapper.body))
	if not data is Dictionary or not _valid(data):
		return {"ok": false}
	return {"ok": true, "data": data, "source": path}


static func _valid(data: Dictionary) -> bool:
	if data.get("schema") != SCHEMA or not str(data.get("room", "")) in ["docks", "foyer"]:
		return false
	if not data.get("elapsed_ms") is float and not data.get("elapsed_ms") is int:
		return false
	if int(data.elapsed_ms) < 0 or not data.get("history") is Array or data.history.is_empty():
		return false
	if not data.get("position") is Array or data.position.size() != 2:
		return false
	for coordinate in data.position:
		if not coordinate is float and not coordinate is int:
			return false
	if not str(data.get("facing", "")) in ["up", "down", "left", "right"]:
		return false
	var last: Variant = data.history[-1]
	if not last is Dictionary or int(last.get("t_ms", -1)) != int(data.elapsed_ms):
		return false
	if str(last.get("room", "")) != str(data.room):
		return false
	return true
