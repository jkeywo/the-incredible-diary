extends RefCounted
class_name FoundationGithubMerge

const Content = preload("res://foundation/content.gd")

static func combine(base: Dictionary, local: Dictionary, remote: Dictionary) -> Dictionary:
	if local == base or local == remote:
		var direct: Dictionary = remote.duplicate(true)
		var direct_errors: Array[String] = Content.validate(direct)
		return {"ok": direct_errors.is_empty(), "content": direct, "errors": direct_errors, "conflicts": []}
	if remote == base:
		var direct: Dictionary = local.duplicate(true)
		var direct_errors: Array[String] = Content.validate(direct)
		return {"ok": direct_errors.is_empty(), "content": direct, "errors": direct_errors, "conflicts": []}
	var conflicts: Array[String] = []
	var merged: Dictionary = _merge_dict(base, local, remote, "scenario", conflicts)
	if not conflicts.is_empty():
		return {"ok": false, "reason": "Authored project has conflicting changes", "conflicts": conflicts, "candidate": merged}
	var payload := merged.duplicate(true)
	payload.erase("version")
	merged.version = "merge-" + JSON.stringify(payload).sha256_text().substr(0, 16)
	var errors: Array[String] = Content.validate(merged)
	if not errors.is_empty():
		return {"ok": false, "reason": "Combined authored project is invalid", "errors": errors, "candidate": merged, "conflicts": []}
	return {"ok": true, "content": merged, "conflicts": []}

static func _merge_dict(base: Dictionary, local: Dictionary, remote: Dictionary, path: String, conflicts: Array[String]) -> Dictionary:
	var result := {}
	var keys := {}
	for key in base: keys[key] = true
	for key in local: keys[key] = true
	for key in remote: keys[key] = true
	for key in keys:
		if path == "scenario" and key == "version":
			continue
		var has_base := base.has(key)
		var has_local := local.has(key)
		var has_remote := remote.has(key)
		var key_path := path + "." + str(key)
		if not has_local and not has_remote:
			continue
		if not has_local:
			if not has_base:
				result[key] = remote[key].duplicate(true) if remote[key] is Dictionary or remote[key] is Array else remote[key]
				continue
			if remote[key] == base[key]:
				continue
			conflicts.append(key_path)
			continue
		if not has_remote:
			if not has_base:
				result[key] = local[key].duplicate(true) if local[key] is Dictionary or local[key] is Array else local[key]
				continue
			if local[key] == base[key]:
				continue
			conflicts.append(key_path)
			continue
		if not has_base:
			if local[key] == remote[key]:
				result[key] = local[key].duplicate(true) if local[key] is Dictionary or local[key] is Array else local[key]
			else:
				conflicts.append(key_path)
			continue
		result[key] = _merge_value(base[key], local[key], remote[key], key_path, conflicts)
	return result

static func _merge_value(base: Variant, local: Variant, remote: Variant, path: String, conflicts: Array[String]) -> Variant:
	if local == remote:
		return local.duplicate(true) if local is Dictionary or local is Array else local
	if local == base:
		return remote.duplicate(true) if remote is Dictionary or remote is Array else remote
	if remote == base:
		return local.duplicate(true) if local is Dictionary or local is Array else local
	if base is Dictionary and local is Dictionary and remote is Dictionary:
		return _merge_dict(base, local, remote, path, conflicts)
	if base is Array and local is Array and remote is Array and _id_array(base) and _id_array(local) and _id_array(remote):
		return _merge_id_array(base, local, remote, path, conflicts)
	conflicts.append(path)
	return local.duplicate(true) if local is Dictionary or local is Array else local

static func _id_array(items: Array) -> bool:
	for item in items:
		if not item is Dictionary or not item.has("id"):
			return false
	return true

static func _merge_id_array(base: Array, local: Array, remote: Array, path: String, conflicts: Array[String]) -> Array:
	var base_map := {}
	var local_map := {}
	var remote_map := {}
	var order: Array = []
	for item in base:
		base_map[item.id] = item
		order.append(item.id)
	for item in local:
		local_map[item.id] = item
		if not order.has(item.id): order.append(item.id)
	for item in remote:
		remote_map[item.id] = item
		if not order.has(item.id): order.append(item.id)
	var merged_map := _merge_dict(base_map, local_map, remote_map, path, conflicts)
	var result: Array = []
	for id in order:
		if merged_map.has(id): result.append(merged_map[id])
	return result
