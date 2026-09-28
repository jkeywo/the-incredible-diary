extends RefCounted
class_name FoundationAuthoringDocument

const Content = preload("res://foundation/content.gd")

# The document owns edits. A rejected draft never replaces applied simulation content.
var content: Dictionary
var source_draft: String
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []

func _init(initial_content: Dictionary) -> void:
	content = initial_content.duplicate(true)
	source_draft = str(content.get("dialogue", ""))

func set_source(source: String, label: String = "Edit scene source") -> void:
	if source == source_draft:
		return
	_record(label, _snapshot())
	source_draft = source

func replace_content(next_content: Dictionary, label: String) -> void:
	if next_content == content:
		return
	_record(label, _snapshot())
	content = next_content.duplicate(true)
	source_draft = str(content.get("dialogue", ""))

func undo() -> String:
	if undo_stack.is_empty():
		return ""
	var operation: Dictionary = undo_stack.pop_back()
	redo_stack.append({"label": operation.label, "state": _snapshot()})
	_restore(operation.state)
	return str(operation.label)

func redo() -> String:
	if redo_stack.is_empty():
		return ""
	var operation: Dictionary = redo_stack.pop_back()
	undo_stack.append({"label": operation.label, "state": _snapshot()})
	_restore(operation.state)
	return str(operation.label)

func candidate() -> Dictionary:
	var result := content.duplicate(true)
	result.dialogue = source_draft
	if result.dialogue != content.dialogue:
		result.version = "edit-" + JSON.stringify(result).sha256_text().substr(0, 16)
	return result

func validate() -> Array[String]:
	return Content.validate(candidate())

func apply_to(simulation: FoundationRun, from_tick: int = -1) -> Dictionary:
	var proposed := candidate()
	var errors := Content.validate(proposed)
	if not errors.is_empty():
		return {"ok": false, "reason": "; ".join(errors), "restart": false}
	var result: Dictionary = simulation.continue_with_content(proposed, from_tick)
	if result.ok:
		content = proposed.duplicate(true)
	return result

func _snapshot() -> Dictionary:
	return {"content": content.duplicate(true), "source_draft": source_draft}

func _restore(snapshot: Dictionary) -> void:
	content = snapshot.content.duplicate(true)
	source_draft = str(snapshot.source_draft)

func _record(label: String, previous: Dictionary) -> void:
	undo_stack.append({"label": label, "state": previous})
	redo_stack.clear()
