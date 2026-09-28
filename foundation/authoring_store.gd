extends RefCounted
class_name FoundationAuthoringStore

const Document = preload("res://foundation/authoring_document.gd")
const Content = preload("res://foundation/content.gd")

var path: String

func _init(save_path: String) -> void:
	path = save_path

func save(document: FoundationAuthoringDocument) -> Dictionary:
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		return {"ok": false, "reason": "Browser storage is not persistent; enable site storage"}
	var staging := path + ".next"
	var encoded := _encode(document.serialize())
	var file := FileAccess.open(staging, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "Cannot stage authoring draft: %s" % FileAccess.get_open_error()}
	file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "reason": "Authoring draft write failed: %s" % write_error}
	var checked := _read(staging)
	if not checked.ok or checked.data.revision != document.revision:
		return {"ok": false, "reason": "Staged authoring draft did not verify"}
	var absolute := ProjectSettings.globalize_path(path)
	var staged_absolute := ProjectSettings.globalize_path(staging)
	var backup_absolute := absolute + ".bak"
	var corrupt_absolute := absolute + ".corrupt"
	var quarantined_corrupt := false
	if FileAccess.file_exists(path):
		if not _read(path).ok:
			if FileAccess.file_exists(path + ".corrupt"):
				return {"ok": false, "reason": "Existing corrupt authoring draft needs manual recovery; saved copies were retained"}
			var quarantine_error := DirAccess.rename_absolute(absolute, corrupt_absolute)
			if quarantine_error != OK:
				return {"ok": false, "reason": "Cannot preserve corrupt authoring draft: %s" % quarantine_error}
			quarantined_corrupt = true
		else:
			if FileAccess.file_exists(path + ".bak"):
				var remove_error := DirAccess.remove_absolute(backup_absolute)
				if remove_error != OK:
					return {"ok": false, "reason": "Cannot rotate prior authoring backup: %s" % remove_error}
			var backup_error := DirAccess.rename_absolute(absolute, backup_absolute)
			if backup_error != OK:
				return {"ok": false, "reason": "Cannot protect prior authoring draft: %s" % backup_error}
	var promote_error := DirAccess.rename_absolute(staged_absolute, absolute)
	if promote_error != OK:
		if quarantined_corrupt:
			DirAccess.rename_absolute(corrupt_absolute, absolute)
		elif FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(backup_absolute, absolute)
		return {"ok": false, "reason": "Cannot promote authoring draft: %s" % promote_error}
	if OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()
		_start_web_verification(ProjectSettings.globalize_path(path), encoded.sha256_text(), document.revision)
	return {"ok": true, "reason": "Saved authoring revision %d" % document.revision}

static func web_verification() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var encoded: Variant = JavaScriptBridge.eval("JSON.stringify(window.__authoringDraftSync || {})")
	var parsed: Variant = JSON.parse_string(str(encoded))
	return parsed if parsed is Dictionary else {}

static func _start_web_verification(virtual_path: String, expected_sha: String, revision: int) -> void:
	# Godot 4.7 web exports use IDBFS at /userfs. Verify its stored bytes after sync,
	# since force_fs_sync() has no success result and browser quota can fail later.
	var script := """
(() => {
  const token = %d, path = %s, expected = %s;
  const started = Date.now();
  const report = (status, reason) => {
    if (window.__authoringDraftSync?.token !== token || window.__authoringDraftSync?.status !== 'pending') return;
    window.__authoringDraftSync = { token, status, reason };
    document.body.dataset.authoringSync = JSON.stringify(window.__authoringDraftSync);
  };
  window.__authoringDraftSync = { token, status: 'pending', reason: '' };
  document.body.dataset.authoringSync = JSON.stringify(window.__authoringDraftSync);
  const deadline = setTimeout(() => report('failed', 'Browser storage did not confirm the authoring draft; check quota or site storage'), 5000);
  const finish = (status, reason) => { clearTimeout(deadline); report(status, reason); };
  let opened;
  try { opened = indexedDB.open('/userfs'); }
  catch (error) { finish('failed', 'Browser storage could not be opened: ' + error); return; }
  opened.onerror = () => finish('failed', 'Browser storage could not be opened');
  opened.onsuccess = () => {
    const db = opened.result;
    const check = () => {
      if (window.__authoringDraftSync?.token !== token || window.__authoringDraftSync?.status !== 'pending') { db.close(); return; }
      let request;
      try { request = db.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA').get(path); }
      catch (error) { db.close(); finish('failed', 'Browser storage read failed: ' + error); return; }
      request.onerror = () => { db.close(); finish('failed', 'Browser storage read failed'); };
      request.onsuccess = async () => {
        const record = request.result;
        if (record?.contents) {
          try {
            const digest = await crypto.subtle.digest('SHA-256', new Uint8Array(record.contents));
            const actual = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');
            if (actual === expected) { db.close(); finish('saved', 'Authoring draft persisted in browser storage'); return; }
          } catch (error) { db.close(); finish('failed', 'Browser storage verification failed: ' + error); return; }
        }
        if (Date.now() - started >= 5000) { db.close(); finish('failed', 'Browser storage did not persist the authoring draft; check quota or site storage'); }
        else setTimeout(check, 100);
      };
    };
    check();
  };
})()
""" % [revision, JSON.stringify(virtual_path), JSON.stringify(expected_sha)]
	JavaScriptBridge.eval(script)

static func load(save_path: String) -> Dictionary:
	var candidates := [save_path, save_path + ".next", save_path + ".bak"]
	var chosen: Dictionary = {}
	var saw_file := false
	for candidate in candidates:
		if not FileAccess.file_exists(candidate):
			continue
		saw_file = true
		var result := _read(candidate)
		if result.ok and (chosen.is_empty() or int(result.data.revision) > int(chosen.data.revision)):
			chosen = result
	if not chosen.is_empty():
		chosen.source = chosen.get("source", "")
		chosen.reason = "Recovered authoring draft from " + str(chosen.source.get_file()) if chosen.source != save_path else "Loaded authoring draft"
		return chosen
	return {"ok": false, "reason": "Corrupt authoring draft retained for recovery" if saw_file else "No authoring draft found"}

static func _encode(data: Dictionary) -> String:
	var body := JSON.stringify(data)
	return JSON.stringify({"body": body, "sha256": body.sha256_text()})

static func _read(candidate: String) -> Dictionary:
	var file := FileAccess.open(candidate, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "Cannot read authoring draft"}
	var encoded := file.get_as_text()
	file.close()
	var wrapper_parser := JSON.new()
	if wrapper_parser.parse(encoded) != OK:
		return {"ok": false, "reason": "Authoring draft wrapper is invalid"}
	var wrapper: Variant = wrapper_parser.data
	if not wrapper is Dictionary or not wrapper.get("body") is String or not wrapper.get("sha256") is String:
		return {"ok": false, "reason": "Authoring draft wrapper is invalid"}
	if str(wrapper.body).sha256_text() != str(wrapper.sha256):
		return {"ok": false, "reason": "Authoring draft checksum failed"}
	var body_parser := JSON.new()
	if body_parser.parse(str(wrapper.body)) != OK:
		return {"ok": false, "reason": "Authoring draft content is invalid"}
	var data: Variant = body_parser.data
	if not data is Dictionary:
		return {"ok": false, "reason": "Authoring draft content is invalid"}
	var document := Document.new(Content.scenario())
	if not document.restore(data):
		return {"ok": false, "reason": "Authoring draft schema is invalid"}
	return {"ok": true, "data": data, "source": candidate}
