extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Content = preload("res://mission1/authoring_content.gd")
const Grid = preload("res://mission1/authoring_grid.gd")
const Document = preload("res://foundation/authoring_document.gd")
const Store = preload("res://foundation/authoring_store.gd")
const Save = preload("res://mission1/save.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func run() -> void:
	var simulation := Sim.new(false)
	var data := Content.seed(simulation.s.actors)
	check(Content.validate(data).is_empty(), "Migrated content validates")
	var document := Document.new(data)
	var next := data.duplicate(true)
	next.templates.prop.name = "Shared name"
	next.instances.example = {"template":"prop","room":"docks","position":[500,500],"overrides":{"initial_state":"custom"}}
	document.replace_content(next,"Create linked instance")
	check(Content.resolve(document.content,"example").name == "Shared name", "Template values inherited")
	next = document.content.duplicate(true)
	next.templates.prop.name = "Updated name"
	document.replace_content(next,"Edit template")
	check(Content.resolve(document.content,"example").name == "Updated name" and Content.resolve(document.content,"example").initial_state == "custom", "Template propagation preserves overrides")
	document.undo()
	check(Content.resolve(document.content,"example").name == "Shared name", "Shared undo restores template")
	document.redo()
	var room := {"size":[200,200],"blocked":{}}
	Grid.stroke(room,Vector2(5,5),Vector2(195,195),true)
	check(room.blocked.has("3,3") and room.blocked.has("7,7"), "Continuous square paint stroke")
	Grid.stroke(room,Vector2(5,5),Vector2(195,195),false)
	check(room.blocked.is_empty(), "Erase stroke")
	Grid.stroke(room,Vector2(75,0),Vector2(75,125),true)
	var route := Grid.path(room,Vector2(25,25),Vector2(125,25))
	check(route.size() > 1, "NPC grid route avoids painted wall")
	var applied := simulation.apply_authored(data)
	check(applied.ok,"Apply migrated definitions: " + applied.reason)
	var before := simulation.s.duplicate(true)
	for i in 4: simulation.step()
	check(simulation.history[0] == before, "Running authored content preserves past records")
	check(simulation.s.has("content_version"), "Frames carry content identity")
	var old_history := simulation.history.duplicate(true)
	var broken := data.duplicate(true)
	broken.rooms.docks.blocked[Grid.key(Grid.cell(Vector2(simulation.s.pos[0],simulation.s.pos[1])))] = true
	check(not simulation.apply_authored(broken,1).ok and simulation.history == old_history,"Incompatible continuation preserves future")
	check(simulation.apply_authored(data,1).ok and simulation.history.size() == 2,"Compatible continuation truncates only after validation")
	simulation.step()
	var save := Save.new()
	check(save.save_run(simulation,"res://build/authoring-run.journal").ok,"Save authored run")
	simulation.step()
	check(save.save_run(simulation,"res://build/authoring-run.journal").ok,"Append frames without duplicating immutable definitions")
	var loaded := Save.load_saved("res://build/authoring-run.journal")
	check(loaded.ok,"Reload authored run")
	if loaded.ok:
		var restored := Sim.new(false)
		restored.restore_record(loaded.data)
		check(restored.authored_content == JSON.parse_string(JSON.stringify(simulation.authored_content)) and restored.history == JSON.parse_string(JSON.stringify(simulation.history)),"Definitions and recorded history survive load")
		check(restored.content_versions.has(data.version),"Historical content versions survive load")
	document.set_scenario_source("unfinished {")
	var store := Store.new("res://build/authoring-draft.json")
	check(store.save(document).ok,"Persist invalid draft")
	var saved := Store.load("res://build/authoring-draft.json")
	check(saved.ok,"Recover persisted document")
	if saved.ok:
		var reopened := Document.new(data)
		check(reopened.restore(saved.data) and reopened.scenario_draft == "unfinished {" and not reopened.undo_stack.is_empty(),"Invalid source and undo survive reopen")
	var fresh := Sim.new(false)
	var event_content := data.duplicate(true)
	for story in event_content.storylets:
		if story.id == "chandelier_warning": story.start_tick = 1; story.end_tick = 1
	check(fresh.apply_authored(event_content).ok,"Apply edited storylet")
	fresh.step()
	check(fresh.s.flags.get("chandelier_warning",false),"Authored storylet changes actual Mission 1 behaviour")
	var custom := data.duplicate(true)
	custom.rooms.workshop = {"title":"Workshop","scene":"","background_asset":"","size":[1175,700],"blocked":{}}
	custom.connections.append({"id":"workshop_door","a":"docks","ap":[580,490],"b":"workshop","bp":[500,450],"b_arrival":[500,500]})
	custom.instances.lever = {"template":"prop","room":"workshop","position":[500,500],"overrides":{"interactions":[{"label":"Pull lever","position":[500,500],"duration":2,"effects":[{"command":"flag","key":"custom_lever","value":true}]}]}}
	custom.instances.mechanic = {"template":"character","room":"workshop","position":[650,550],"overrides":{}}
	custom.actors.append({"id":"mechanic"})
	custom.schedules.mechanic = {"mode":"custom","commitments":[{"tick":0,"room":"workshop","position":[750,550],"speed":10}]}
	var workshop := Sim.new(false)
	check(workshop.apply_authored(custom).ok,"Create connected room and working prop")
	workshop.step(Vector2.RIGHT)
	check(workshop.s.room == "workshop","Authored door traverses to new room")
	check(workshop.start("authored:lever:0"),"Authored local prop offers interaction")
	workshop.step()
	workshop.step()
	check(workshop.s.flags.get("custom_lever",false),"Authored interaction executes its effect")
	check(workshop.s.actors.has("mechanic") and workshop.s.actors.mechanic.pos[0] > 650,"New templated character follows authored schedule")
	var unreachable := custom.duplicate(true)
	unreachable.connections.pop_back()
	check(not Content.validate(unreachable).is_empty(),"Disconnected required interaction blocks application")
	var protected := data.duplicate(true)
	workshop.s.action = {"id":"authored:lever:0","progress":0,"duration":10,"room":"workshop","pos":[500,500]}
	protected = custom.duplicate(true)
	protected.templates.prop.name = "Unrelated inherited change"
	check(not workshop.apply_authored(protected).ok,"Changing an active interaction definition is rejected")
	protected = custom.duplicate(true)
	protected.scenes.bags = "~ start\nguest: An unrelated scene edit.\n=> END"
	check(workshop.apply_authored(protected).ok,"Unrelated scene edits do not interrupt an active interaction")
	var roundtrip := workshop.apply_authored(JSON.parse_string(JSON.stringify(protected)))
	check(roundtrip.ok,"JSON round trip does not invent placement or active-state incompatibilities: " + roundtrip.reason)
	Save.clear("res://build/authoring-run.journal")
	print(JSON.stringify({"passed":failures.is_empty(),"suite":"mission1_authoring","failures":failures}))
	quit(0 if failures.is_empty() else 1)
