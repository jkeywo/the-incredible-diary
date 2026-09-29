extends Node
## Shared, mission-independent resource cache. Foreground work precedes neighbour
## prefetch; mounted content and Resource references survive scene changes.
var resources: Dictionary = {}
var mounted: Dictionary = {}
var tickets: Array[Dictionary] = []
var manifest: Dictionary = {}
var bridge: JavaScriptObject
var active_packs: Array[String] = []
var active_resource := ""
var failures: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		var parsed = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.DIARY_CONTENT || null)")))
		if parsed is Dictionary:
			manifest = parsed
			bridge = JavaScriptBridge.get_interface("diaryAssets")
			DirAccess.make_dir_recursive_absolute("/tmp/diary-assets")

func request_resources(paths: Array, foreground := false) -> Dictionary:
	var unique: Array = []
	var packs: Dictionary = {}
	for path in paths:
		if unique.has(path): continue
		unique.append(path)
		failures.erase(path)
		for hash in manifest.get("resources",{}).get(path,[]):
			packs[hash] = true
			failures.erase(hash)
	var ticket := {"paths":unique,"packs":packs,"foreground":foreground,"done":false,"cancelled":false,"error":"","progress":0.0}
	if not manifest.is_empty() and bridge == null:
		ticket.done = true
		ticket.error = "Resource downloads could not start. Please reload the page."
		return ticket
	_update_ticket(ticket)
	if not ticket.done: tickets.append(ticket)
	return ticket

func _update_ticket(ticket: Dictionary) -> void:
	var total := 0.0
	var done := 0.0
	for hash in ticket.packs:
		var weight := float(manifest.packs[hash].bytes)
		total += weight
		if mounted.has(hash): done += weight
		elif active_packs.has(hash):
			var status: Dictionary = JSON.parse_string(bridge.status(hash))
			done += weight*float(status.get("progress",0.0))
		if failures.has(hash): ticket.error = failures[hash]
	var loaded := 0
	for path in ticket.paths:
		if resources.has(path): loaded += 1
		if failures.has(path): ticket.error = failures[path]
	var prepared := float(loaded)/maxf(1.0,ticket.paths.size())
	ticket.progress = 0.85*done/total + 0.15*prepared if total > 0 else prepared
	ticket.done = loaded == ticket.paths.size() or not str(ticket.error).is_empty()
	if loaded == ticket.paths.size(): ticket.progress = 1.0

func _process(_delta: float) -> void:
	for hash in active_packs.duplicate(): _poll_pack(hash)
	if not active_resource.is_empty():
		var state := ResourceLoader.load_threaded_get_status(active_resource)
		if state == ResourceLoader.THREAD_LOAD_LOADED:
			resources[active_resource] = ResourceLoader.load_threaded_get(active_resource)
			active_resource = ""
		elif state in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			failures[active_resource] = "A resource could not be prepared. Please try again."
			active_resource = ""
	for ticket in tickets: _update_ticket(ticket)
	tickets = tickets.filter(func(ticket): return not ticket.done and not ticket.cancelled)
	var has_foreground := tickets.any(func(ticket): return ticket.foreground)
	for foreground in [true,false]:
		if not foreground and has_foreground: break
		for ticket in tickets:
			if ticket.foreground != foreground: continue
			for path in ticket.paths:
				if resources.has(path): continue
				var missing := false
				for hash in manifest.get("resources",{}).get(path,[]):
					if mounted.has(hash): continue
					missing = true
					if not active_packs.has(hash) and active_packs.size() < 4:
						active_packs.append(hash)
						bridge.begin(manifest.packs[hash].url,hash)
				if missing or not active_resource.is_empty(): continue
				if ResourceLoader.load_threaded_request(path) != OK:
					failures[path] = "A resource could not be opened. Please try again."
				else: active_resource = path

func _poll_pack(hash: String) -> void:
	var status: Dictionary = JSON.parse_string(bridge.status(hash))
	if status.get("state") == "ready":
		var path := "/tmp/diary-assets/"+hash+".pck"
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file == null:
			failures[hash] = "There is not enough space to open this resource. Please try again."
		else:
			file.store_buffer(JavaScriptBridge.js_buffer_to_packed_byte_array(bridge.bytes(hash)))
			file.close()
			if ProjectSettings.load_resource_pack(path,false): mounted[hash] = true
			else: failures[hash] = "A downloaded resource could not be opened. Please reload and try again."
	elif status.get("state") == "failed":
		failures[hash] = str(status.error)
	else: return
	bridge.release(hash)
	active_packs.erase(hash)

func _exit_tree() -> void:
	# Finish the one outstanding disk read before the engine tears resources down.
	if not active_resource.is_empty() and ResourceLoader.load_threaded_get_status(active_resource) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_get(active_resource)
