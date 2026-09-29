extends SceneTree
## Build native PCKs from the engine's exported ZIP, preserving imported bytes.
func _initialize() -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/web-pack-plan.json"))
	var archive := ZIPReader.new()
	assert(archive.open("res://build/web-full.zip") == OK)
	var scratch := "res://build/web-pack-entry.tmp"
	var groups: Array = plan.chunks.duplicate()
	groups.append(plan.bootstrap)
	for i in groups.size():
		var pack := PCKPacker.new()
		var target := "res://build/web/chunk-%d.pck" % i if i < plan.chunks.size() else "res://build/web/index.pck"
		assert(pack.pck_start(target) == OK)
		for path in groups[i]:
			var file := FileAccess.open(scratch, FileAccess.WRITE)
			file.store_buffer(archive.read_file(path))
			file.close()
			assert(pack.add_file("res://"+path, scratch) == OK)
		assert(pack.flush() == OK)
	archive.close()
	DirAccess.remove_absolute(scratch)
	quit()
