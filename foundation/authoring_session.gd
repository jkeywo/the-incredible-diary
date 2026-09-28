extends RefCounted
class_name FoundationAuthoringSession

const AuthoringDocument = preload("res://foundation/authoring_document.gd")

var run: FoundationRun
var document: FoundationAuthoringDocument
var paused := false
var viewed_tick := -1
var draft_source: String

func _init(current_run: FoundationRun) -> void:
	run = current_run
	document = AuthoringDocument.new(run.content)
	draft_source = str(run.content.dialogue)

func set_draft(source: String) -> void:
	draft_source = source
	document.set_source(source)

func pause() -> void:
	paused = true

func inspect() -> Dictionary:
	return run.inspect_at(viewed_tick) if viewed_tick >= 0 else run.inspect()

func view_tick(tick_number: int) -> void:
	if paused and tick_number >= 0 and tick_number < run.history.size():
		viewed_tick = tick_number

func return_live() -> void:
	viewed_tick = -1

func resume(from_history: bool = false) -> Dictionary:
	if not paused:
		return {"ok": false, "reason": "Run is not paused"}
	var target_tick := viewed_tick if from_history and viewed_tick >= 0 else -1
	var result := _apply_pending(target_tick)
	if result.ok:
		paused = false
		viewed_tick = -1
	return result

func step_tick() -> Dictionary:
	if not paused:
		return {"ok": false, "reason": "Run is not paused"}
	var result := _apply_pending(-1)
	if result.ok:
		run.tick()
		viewed_tick = -1
	return result

func step_next_event() -> Dictionary:
	if not paused:
		return {"ok": false, "reason": "Run is not paused"}
	var result := _apply_pending(-1)
	if result.ok:
		run.step_next_event()
		viewed_tick = -1
	return result

func begin_rewind() -> void:
	paused = true
	viewed_tick = int(run.state.tick)

func finish_rewind() -> void:
	run.reset_loop()
	viewed_tick = -1
	paused = false

func _apply_pending(target_tick: int) -> Dictionary:
	return document.apply_to(run, target_tick)
