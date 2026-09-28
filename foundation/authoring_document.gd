extends RefCounted
class_name FoundationAuthoringDocument

signal changed

const Content = preload("res://foundation/content.gd")

# The document owns edits. A rejected draft never replaces applied simulation content.
var content: Dictionary
var applied_content: Dictionary
var source_draft: String
var scenario_draft: String
var scenario_error := ""
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var baseline_head := "local"
var revision := 0
var source_group_open := false
var scenario_group_open := false

func _init(initial_content: Dictionary) -> void:
	content = initial_content.duplicate(true)
	applied_content = initial_content.duplicate(true)
	source_draft = str(content.get("dialogue", ""))
	scenario_draft = JSON.stringify(content, "\t")

func set_source(source: String, label: String = "Edit scene source") -> void:
	if source == source_draft:
		return
	finish_scenario_group()
	if not source_group_open:
		_record(label, _snapshot())
	source_group_open = true
	source_draft = source
	_changed()

func finish_source_group() -> void:
	source_group_open = false

func set_scenario_source(source: String) -> void:
	if source == scenario_draft:
		return
	finish_source_group()
	if not scenario_group_open:
		_record("Edit scenario source", _snapshot())
	scenario_group_open = true
	scenario_draft = source
	var parser := JSON.new()
	if parser.parse(source) != OK or not parser.data is Dictionary:
		scenario_error = "Scenario source is not a JSON object: " + parser.get_error_message()
	else:
		var errors := Content.validate(parser.data)
		if not errors.is_empty():
			scenario_error = "; ".join(errors)
		else:
			var source_was_unmodified := source_draft == str(content.get("dialogue", ""))
			content = parser.data.duplicate(true)
			if source_was_unmodified:
				source_draft = str(content.dialogue)
			scenario_error = ""
	_changed()

func finish_scenario_group() -> void:
	scenario_group_open = false

func replace_content(next_content: Dictionary, label: String) -> void:
	if next_content == content:
		return
	finish_source_group()
	finish_scenario_group()
	_record(label, _snapshot())
	var source_was_unmodified := source_draft == str(content.get("dialogue", ""))
	content = next_content.duplicate(true)
	if source_was_unmodified:
		source_draft = str(content.get("dialogue", ""))
	if scenario_error.is_empty():
		scenario_draft = JSON.stringify(content, "\t")
	_changed()

func undo() -> String:
	if undo_stack.is_empty():
		return ""
	finish_source_group()
	finish_scenario_group()
	var operation: Dictionary = undo_stack.pop_back()
	redo_stack.append({"label": operation.label, "state": _snapshot()})
	_restore(operation.state)
	_changed()
	return str(operation.label)

func redo() -> String:
	if redo_stack.is_empty():
		return ""
	finish_source_group()
	finish_scenario_group()
	var operation: Dictionary = redo_stack.pop_back()
	undo_stack.append({"label": operation.label, "state": _snapshot()})
	_restore(operation.state)
	_changed()
	return str(operation.label)

func candidate() -> Dictionary:
	var result := content.duplicate(true)
	result.dialogue = source_draft
	var payload := result.duplicate(true)
	payload.erase("version")
	var applied_payload := applied_content.duplicate(true)
	applied_payload.erase("version")
	if payload != applied_payload:
		result.version = "edit-" + JSON.stringify(payload).sha256_text().substr(0, 16)
	else:
		result.version = applied_content.version
	return result

func validate() -> Array[String]:
	if not scenario_error.is_empty():
		return [scenario_error]
	return Content.validate(candidate())

func apply_to(simulation: FoundationRun, from_tick: int = -1) -> Dictionary:
	finish_source_group()
	finish_scenario_group()
	var proposed := candidate()
	var errors := validate()
	if not errors.is_empty():
		return {"ok": false, "reason": "; ".join(errors), "restart": false}
	var result: Dictionary = simulation.continue_with_content(proposed, from_tick)
	if result.ok:
		var applied_changed := content != proposed or applied_content != proposed
		content = proposed.duplicate(true)
		applied_content = proposed.duplicate(true)
		if scenario_error.is_empty():
			scenario_draft = JSON.stringify(content, "\t")
		if applied_changed:
			_changed()
	return result

func change_head(next_head: String) -> void:
	if next_head == baseline_head:
		return
	finish_source_group()
	finish_scenario_group()
	baseline_head = next_head
	undo_stack.clear()
	redo_stack.clear()
	_changed()

func serialize() -> Dictionary:
	return {"schema": 1, "revision": revision, "baseline_head": baseline_head, "content": content.duplicate(true), "applied_content": applied_content.duplicate(true), "source_draft": source_draft, "scenario_draft": scenario_draft, "scenario_error": scenario_error, "undo_stack": undo_stack.duplicate(true), "redo_stack": redo_stack.duplicate(true)}

func restore(data: Dictionary) -> bool:
	if data.get("schema") != 1 or not data.get("content") is Dictionary or not data.get("applied_content") is Dictionary or not data.get("source_draft") is String:
		return false
	if not data.get("undo_stack") is Array or not data.get("redo_stack") is Array or not data.get("baseline_head") is String:
		return false
	if not Content.validate(data.applied_content).is_empty():
		return false
	for stack in [data.undo_stack, data.redo_stack]:
		for operation in stack:
			if not operation is Dictionary or not operation.get("state") is Dictionary or not operation.get("label") is String:
				return false
	content = data.content.duplicate(true)
	applied_content = data.applied_content.duplicate(true)
	source_draft = str(data.source_draft)
	scenario_draft = str(data.get("scenario_draft", JSON.stringify(content, "\t")))
	scenario_error = str(data.get("scenario_error", ""))
	undo_stack.assign(data.undo_stack)
	redo_stack.assign(data.redo_stack)
	baseline_head = str(data.baseline_head)
	revision = int(data.get("revision", 0))
	source_group_open = false
	scenario_group_open = false
	return true

func _snapshot() -> Dictionary:
	return {"content": content.duplicate(true), "source_draft": source_draft, "scenario_draft": scenario_draft, "scenario_error": scenario_error}

func _restore(snapshot: Dictionary) -> void:
	content = snapshot.content.duplicate(true)
	source_draft = str(snapshot.source_draft)
	scenario_draft = str(snapshot.get("scenario_draft", JSON.stringify(content, "\t")))
	scenario_error = str(snapshot.get("scenario_error", ""))

func _record(label: String, previous: Dictionary) -> void:
	undo_stack.append({"label": label, "state": previous})
	redo_stack.clear()

func _changed() -> void:
	revision += 1
	changed.emit()
