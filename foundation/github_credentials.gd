extends RefCounted
class_name FoundationGithubCredentials

const DEFAULT_BROWSER_KEY := "the-incredible-diary.github-token.v1"
const DEFAULT_NATIVE_PATH := "user://github_credentials.json"

var native_path: String
var browser_key: String

func _init(path: String = DEFAULT_NATIVE_PATH, key: String = DEFAULT_BROWSER_KEY) -> void:
	native_path = path
	browser_key = key

func load_token() -> String:
	if OS.has_feature("web"):
		var result: Variant = JavaScriptBridge.eval("(() => { try { return localStorage.getItem(%s) || ''; } catch (_) { return ''; } })()" % JSON.stringify(browser_key))
		return str(result) if result is String else ""
	if not FileAccess.file_exists(native_path):
		return ""
	var file := FileAccess.open(native_path, FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return str(parsed.get("token", "")) if parsed is Dictionary and parsed.get("schema") == 1 else ""

func save_token(token: String) -> Dictionary:
	if token.strip_edges().is_empty():
		return {"ok": false, "reason": "Enter a GitHub token"}
	if OS.has_feature("web"):
		var script := "(() => { try { localStorage.setItem(%s, %s); return true; } catch (_) { return false; } })()" % [JSON.stringify(browser_key), JSON.stringify(token)]
		var saved: Variant = JavaScriptBridge.eval(script)
		return {"ok": bool(saved), "reason": "Token saved in this browser" if bool(saved) else "Browser storage could not save the token"}
	var file := FileAccess.open(native_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "Local token file could not be opened"}
	file.store_string(JSON.stringify({"schema": 1, "token": token}))
	file.flush()
	var result := file.get_error()
	file.close()
	return {"ok": result == OK, "reason": "Token saved on this device" if result == OK else "Local token file could not be written"}

func clear_token() -> Dictionary:
	if OS.has_feature("web"):
		var removed: Variant = JavaScriptBridge.eval("(() => { try { localStorage.removeItem(%s); return true; } catch (_) { return false; } })()" % JSON.stringify(browser_key))
		return {"ok": bool(removed), "reason": "Saved token removed" if bool(removed) else "Browser storage could not remove the token"}
	if not FileAccess.file_exists(native_path):
		return {"ok": true, "reason": "No saved token"}
	var result := DirAccess.remove_absolute(ProjectSettings.globalize_path(native_path))
	return {"ok": result == OK, "reason": "Saved token removed" if result == OK else "Local token file could not be removed"}
