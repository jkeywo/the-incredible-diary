extends RefCounted
class_name FoundationInspector

static func describe(snapshot: Dictionary, room_id: String) -> String:
	var lines: Array[String] = ["Recorded tick %d · %s" % [int(snapshot.tick), str(snapshot.content_version)], "Room: " + room_id]
	var diagnostics: Dictionary = snapshot.get("diagnostics", {})
	var npc: Dictionary = diagnostics.get("npc", {})
	var actor_ids: Array = npc.keys()
	actor_ids.sort()
	for actor_id in actor_ids:
		var actor: Dictionary = npc[actor_id]
		if str(actor.get("room", "")) != room_id:
			continue
		var target: Dictionary = actor.get("target", {})
		var intention := "No scheduled destination"
		if not target.is_empty():
			intention = "%s → %s (tick %d)" % [target.commitment, target.room, int(target.at_tick)]
		lines.append("%s · %s · %s · %s" % [actor_id, actor.get("activity", "idle"), actor.get("reason", ""), intention])
	var storylets: Dictionary = diagnostics.get("storylets", {})
	var storylet_ids: Array = storylets.keys()
	storylet_ids.sort()
	for storylet_id in storylet_ids:
		var storylet: Variant = storylets[storylet_id]
		if not storylet is Dictionary or str(storylet.get("room", "")) != room_id:
			continue
		lines.append("%s · %s · %s" % [storylet.get("label", storylet_id), storylet.status, storylet.scene])
		for condition in storylet.get("conditions", []):
			lines.append("  %s %s: %s" % ["✓" if condition.met else "×", condition.name, condition.detail])
	for event in snapshot.get("events", []):
		lines.append("Event: %s · %s · %s" % [event.get("category", ""), event.get("actor", ""), event.get("detail", "")])
	return "\n".join(lines)
