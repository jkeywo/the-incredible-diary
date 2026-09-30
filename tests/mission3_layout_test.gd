extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Content = preload("res://mission1/authoring_content.gd")
const Save = preload("res://mission1/save.gd")

func _initialize() -> void:
	var run := Sim.new(false)
	run.start_mission_three()
	var data: Dictionary = run.authored_content
	var errors := Content.validate(data)
	assert(errors.is_empty(),str(errors))
	assert(run.mission_number() == 3 and run.exploration())
	assert(run.s.room == "docks" and run.s.actors.size() == 14)
	var previous := preload("res://mission2/content.gd").seed()
	for room in previous.rooms:
		if room != "docks": assert(data.rooms[room] == previous.rooms[room],room)
	for door in data.connections:
		for side in ["a","b"]:
			run.s.actors = {}
			run.s.room = door[side]
			run.s.pos = door[side+"p"].duplicate()
			run.s.door_cooldown = 0
			run.step(Vector2(0.01,0.11))
			assert(run.s.room == door["b" if side == "a" else "a"],str(door.id)+side)
	assert(Content.reachable(data,"docks",[580,350],"restaurant",[580,225]))
	assert(Content.reachable(data,"docks",[580,350],"market",[580,550]))
	run.start_mission_three()
	for i in 30: run.step(Vector2.DOWN)
	const PATH := "res://build/mission3-test.journal"
	Save.clear(PATH)
	assert(Save.new().save_run(run,PATH).ok)
	var saved := Save.load_saved(PATH)
	assert(saved.ok)
	var restored := Sim.new(false)
	restored.restore_record(saved.data)
	assert(restored.mission_number() == 3)
	assert(restored.history == JSON.parse_string(JSON.stringify(run.history)))
	assert(restored.s == JSON.parse_string(JSON.stringify(run.s)))
	Save.clear(PATH)
	print("MISSION3 LAYOUT PASS: full ship, shore routes, both-way exits, save and recorded history")
	quit()
