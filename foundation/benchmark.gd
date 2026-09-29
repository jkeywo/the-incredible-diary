extends RefCounted
class_name FoundationBenchmark

const Simulation = preload("res://foundation/run.gd")

static func run(save_path: String) -> Dictionary:
	var simulation := Simulation.new()
	simulation.attach_journal(save_path)
	var saved := simulation.persist()
	if not saved.ok:
		return {"passed": false, "reason": saved.reason}
	var start_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var start_usec := Time.get_ticks_usec()
	var save_usec := 0
	var slowest_save_usec := 0
	var event_counts := {}
	for index in range(Simulation.LEG_TICKS):
		var command := {}
		if index < 10: command.x = 1.0
		if index == 10: command.start_dialogue = true
		if index == 11 or index == 23: command.advance_dialogue = true
		if index >= 35 and index < 73: command.x = 1.0
		if index == 73: command.start_interaction = "valve"
		simulation.tick(command)
		for event in simulation.events:
			event_counts[event.category] = int(event_counts.get(event.category, 0)) + 1
		var save_start := Time.get_ticks_usec()
		saved = simulation.persist()
		var cost := Time.get_ticks_usec() - save_start
		save_usec += cost
		slowest_save_usec = maxi(slowest_save_usec, cost)
		if not saved.ok:
			return {"passed": false, "reason": saved.reason, "failed_tick": simulation.state.tick}
	var total_usec := Time.get_ticks_usec() - start_usec
	var end_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var final_categories: Array[String] = []
	for event in simulation.state.events: final_categories.append(event.category)
	var final_state := simulation.inspect()
	var no_more_events: bool = simulation.step_next_event() == final_state
	var seek_usec := 0
	var sampled_correct := true
	for sample in [0, 1, 20, 100, 1799, 1800, 5400, 10799, 10800]:
		var seek_start := Time.get_ticks_usec()
		var snapshot := simulation.inspect_at(sample)
		seek_usec += Time.get_ticks_usec() - seek_start
		if snapshot.is_empty() or snapshot.tick != sample:
			sampled_correct = false
	var restore_start := Time.get_ticks_usec()
	var restored := Simulation.new()
	restored.attach_journal(save_path)
	var loaded := restored.load_saved()
	var restored_ok: bool = loaded.ok
	var restore_usec := Time.get_ticks_usec() - restore_start
	var bytes := FileAccess.get_file_as_bytes(save_path).size()
	var report := {
		"passed": sampled_correct and restored_ok and restored.inspect() == simulation.inspect() and final_categories == ["hour_boundary", "leg_end"] and no_more_events,
		"platform": OS.get_name(),
		"godot": Engine.get_version_info().string,
		"ticks": simulation.state.tick,
		"simulated_seconds": 1080,
		"room_count": simulation.content.rooms.size(),
		"event_counts": event_counts,
		"final_event_order": final_categories,
		"leg_end_stable": no_more_events,
		"history_states": simulation.history.size(),
		"persisted_bytes": bytes,
		"wall_seconds": float(total_usec) / 1000000.0,
		"mean_save_ms": float(save_usec) / float(Simulation.LEG_TICKS) / 1000.0,
		"max_save_ms": float(slowest_save_usec) / 1000.0,
		"mean_seek_ms": float(seek_usec) / 9.0 / 1000.0,
		"restore_ms": float(restore_usec) / 1000.0,
		"memory_start_bytes": start_memory,
		"memory_end_bytes": end_memory,
		"processor": OS.get_processor_name(),
		"browser_user_agent": JavaScriptBridge.eval("navigator.userAgent") if OS.has_feature("web") else "",
		"storage_report": loaded.reason if loaded.ok else loaded.reason,
	}
	return report
