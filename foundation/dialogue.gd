extends RefCounted
class_name FoundationDialogue

# Dialogue Manager validates the authored scene. This adapter admits a deliberately
# small command vocabulary so world effects remain tick-stamped and serializable.
static func parse(source: String, actor_ids: Array[String]) -> Dictionary:
	var errors: Array[String] = []
	var compiled := DMCompiler.compile_string(source, "")
	for error in compiled.errors:
		errors.append("Line %d: %s" % [error.line_number + 1, DMConstants.get_error_message(error.error)])
	if not compiled.cues.has("start"):
		errors.append("A ~ start cue is required")
	var steps: Array[Dictionary] = []
	var pending_commands: Array[Dictionary] = []
	var in_start := false
	for raw_line in source.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("~ "):
			in_start = line == "~ start"
			continue
		if not in_start or line.is_empty() or line == "=> END":
			continue
		if line.begins_with("do "):
			var expression := line.trim_prefix("do ")
			if not expression.begins_with("delay_guest(") or not expression.ends_with(")"):
				errors.append("Unknown world command: " + expression)
				continue
			var amount := expression.trim_prefix("delay_guest(").trim_suffix(")")
			if not amount.is_valid_int() or int(amount) < 1 or int(amount) > 1800:
				errors.append("delay_guest needs an integer from 1 to 1800")
			elif not actor_ids.has("guest"):
				errors.append("delay_guest references missing actor guest")
			else:
				pending_commands.append({"name": "delay_guest", "ticks": int(amount)})
			continue
		var colon := line.find(":")
		if colon < 1:
			errors.append("Unsupported dialogue line: " + line)
			continue
		var speaker := line.substr(0, colon)
		if not actor_ids.has(speaker.to_lower()):
			errors.append("Dialogue speaker has no actor: " + speaker)
		steps.append({"speaker": speaker, "text": line.substr(colon + 1).strip_edges(), "commands_before": pending_commands.duplicate(true)})
		pending_commands.clear()
	if not pending_commands.is_empty():
		errors.append("World command after last spoken line has no step boundary")
	if steps.is_empty():
		errors.append("Dialogue needs at least one spoken line")
	return {"errors": errors, "steps": steps}
