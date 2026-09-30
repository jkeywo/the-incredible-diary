extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Save = preload("res://mission1/save.gd")
const SAVE_PATH := "res://build/ending-test.journal"

func _initialize() -> void: call_deferred("checks")

func finish(room: String, dead: Array, authored := false):
	var run := Sim.new(false)
	if authored: assert(run.apply_authored(preload("res://mission1/authoring_content.gd").seed(run.s.actors)).ok)
	run.s.room = room
	run.s.pos = [580,490]
	run.s.safe = ["guest","chandelier_guest","chatterbox"]
	for id in dead: run.s.safe.erase(id)
	run.s.dead = dead.duplicate()
	run.s.flags.steam_off = true
	run.s.flags.chandelier_fallen = dead.has("chandelier_guest")
	run.s.flags.shove_target = [730,430]
	run.s.flags.guest_collapse = {"room":"salon","pos":[950,215],"action":"poison_collapse","facing":"down"}
	run.s.flags.spill_tick = 4000
	run.s.flags.escape_tick = 4000
	run.s.tick = Sim.END-Sim.Departure.LEAD_TICKS-1
	run.s.actors = run.actor_positions()
	assert(not run.s.actors.has("captain"))
	assert(run.s.actors.keys().filter(func(id): return str(id).begins_with("sendoff_guest_")).is_empty())
	run.step()
	if dead.is_empty():
		assert(run.s.actors.sendoff_guest_1.pos[1] > 740)
	else:
		assert(Sim.Rooms.point(run.s.actors.captain.pos).distance_to(Sim.Departure.CAPTAIN_ENTRANCES[Sim.Departure.room_for(Sim.Departure.victim(dead))]) < 15)
	var moved := false
	var before: Dictionary = run.s.actors.duplicate(true)
	var restored: RefCounted
	while not run.s.finished:
		run.step()
		if restored != null: restored.step()
		if run.s.frame == 30:
			Save.clear(SAVE_PATH)
			assert(Save.new().save_run(run,SAVE_PATH).ok)
			restored = Sim.new(false)
			Save.new().restore_run(restored,Save.load_saved(SAVE_PATH).data)
			Save.clear(SAVE_PATH)
		if not dead.is_empty() and run.s.actors.captain.action == "walk": moved = true
	assert(JSON.parse_string(JSON.stringify(restored.s)) == JSON.parse_string(JSON.stringify(run.s)))
	if dead.is_empty():
		for i in 10:
			var id := "sendoff_guest_%d" % (i+1)
			assert(run.s.actors.has(id))
			assert(Sim.Rooms.point(run.s.actors[id].pos).distance_to(Sim.Departure.SPECTATOR_POSITIONS[i]) < 15,"Spectator missed position: "+id+" "+str(run.s.actors[id]))
	else:
		assert(moved and run.s.actors.captain.pos != before.captain.pos)
		var body: Dictionary = run.s.actors[Sim.Departure.victim(dead)]
		assert(run.s.actors.captain.room == body.room)
		assert(Sim.Rooms.point(run.s.actors.captain.pos).distance_to(Sim.Departure.captain_target(body)) < 15,"Captain missed body: "+str(run.s.actors.captain))
	assert(run.s.finished and run.s.tick == Sim.END)
	return run

func checks() -> void:
	var game = preload("res://mission1/play.tscn").instantiate()
	game.configure({},false)
	root.add_child(game)
	current_scene = game
	game.enable_controls()
	game.set_process(false)
	game.set_physics_process(false)
	for scenario in [
		["foyer",[],"docks"],
		["docks",[],"docks"],
		["docks",["guest","chatterbox","chandelier_guest"],"foyer"],
		["docks",["chatterbox","guest"],"salon"],
		["docks",["chatterbox"],"controls"],
		["foyer",[],"docks",true],
		["foyer",["guest","chatterbox","chandelier_guest"],"foyer",true],
		["salon",["guest"],"salon",true],
		["controls",["chatterbox"],"controls",true]]:
		game.ending.clear()
		game.end_presented = false
		game.sim = finish(scenario[0],scenario[1],scenario.size()>3)
		game._show_room(scenario[0])
		var final_state := JSON.stringify(game.sim.s)
		var final_history := JSON.stringify(game.sim.history)
		game._refresh()
		if scenario[0] != scenario[2]:
			assert(game.cut_fade_phase == "out" and game.shown_room == scenario[0])
			game.application_focused = false
			game._process(0.1)
			assert(game.cut_fade_elapsed == 0.0)
			game.application_focused = true
			paused = true
			game._process(0.1)
			assert(game.cut_fade_elapsed == 0.0)
			paused = false
			game._process(game.CUT_FADE_SECONDS/2)
			assert(is_equal_approx(game.cut_fade.modulate.a,0.5) and game.shown_room == scenario[0])
			game._process(game.CUT_FADE_SECONDS/2)
			assert(game.cut_fade_phase == "in" and game.cut_fade.modulate.a == 1.0)
			assert(game.cut_fade.size == game.get_viewport_rect().size)
			assert(game.shown_room == scenario[2] and game.ending.elapsed == 0.0)
			game._process(game.CUT_FADE_SECONDS)
			assert(not game.cut_fade.visible and game.ending.elapsed == 0.0)
		else:
			assert(game.cut_fade_phase.is_empty() and not game.cut_fade.visible)
		assert(game.ending.active() and not game.diary_open and not game.hud.visible)
		assert(game.shown_room == scenario[2])
		for id in game.sim.s.actors:
			if game.sim.s.actors[id].room == game.shown_room:
				assert(game.actors[id].visible)
				assert(game.actors[id].position == Sim.Rooms.point(game.sim.s.actors[id].pos))
		game._begin_reset()
		assert(game.rewind_index == -1)
		game.application_focused = false
		game._process(1.0)
		assert(game.ending.elapsed == 0.0)
		game.application_focused = true
		paused = true
		game._process(1.0)
		assert(game.ending.elapsed == 0.0)
		paused = false
		if scenario[1].is_empty():
			var docks = game.room_slot.get_child(0)
			var start_x: float = docks.ship.position.x
			var pier: Vector2 = docks.get_node("PierAndStairs").position
			game._process(3.0)
			assert(docks.ship.position.x < start_x-300)
			assert(docks.get_node("PierAndStairs").position == pier)
			assert(game.actors.amelia.visible == (scenario[0] == "docks"))
			for i in 10:
				var id := "sendoff_guest_%d" % (i+1)
				assert(game.actors[id].character_id == Sim.Departure.skin(id))
				assert(game.actors[id].animation == "wave" and not game.actors[id].is_playing())
				assert(game.actors[id].sprite_frames.get_frame_count("wave") == 8)
				assert(game.sim.s.actors[id].action != "wave")
			var first_frame: int = game.actors.sendoff_guest_1.frame
			game._process(0.2)
			assert(game.actors.sendoff_guest_1.frame != first_frame)
			first_frame = game.actors.sendoff_guest_1.frame
			paused = true
			game._process(0.5)
			assert(game.actors.sendoff_guest_1.frame == first_frame)
			paused = false
			await capture(game,"departure-"+scenario[0])
		else:
			game._process(4.0)
			assert(game.actors.captain.grief.visible)
			assert(game.ending.speech.visible and game.ending.speech.message.contains("cancelled"))
			assert(game.actors[game.ending.victim].visible)
			assert(game.actors.amelia.visible == (scenario[0] == scenario[2]))
			await capture(game,"cancelled-"+scenario[2])
		game._process(8.0)
		game.diary_presentation.advance(0.3)
		assert(game.ending.done and game.diary_open and game.hud.visible)
		assert(JSON.stringify(game.sim.s) == final_state and JSON.stringify(game.sim.history) == final_history)
		var missed: bool = scenario[0] == "docks" and scenario[1].is_empty()
		assert(game.sim.flag("missed_boat") == missed)
		assert(game.diary_next.visible == (scenario[1].is_empty() and not missed))
		assert(game.diary_reset.visible == (not scenario[1].is_empty() or missed))
		if missed:
			assert(not game.sim.memory.completed and not game.sim.memory.get("location_rewriting",false))
			assert(game.sim.summary().contains("MISSED THE BOAT"))
			Save.clear(SAVE_PATH)
			assert(Save.new().save_run(game.sim,SAVE_PATH).ok)
			var restored := Sim.new(false)
			Save.new().restore_run(restored,Save.load_saved(SAVE_PATH).data)
			assert(restored.flag("missed_boat") and not restored.succeeded())
			Save.clear(SAVE_PATH)
			await capture(game,"missed-boat-diary")
		game._begin_reset()
		assert(game.rewind_index >= 0 and game.ending.state.is_empty())
		game._finish_reset()
		game.time_presentation.advance(0.2)
		assert(not game.sim.s.finished and not game.ending.active() and game.actors.amelia.visible)
		assert(game.room_slot.get_child(0).departure_time == 0.0)
	game.queue_free()
	await process_frame
	print("MISSION1 ENDING PASS: recorded 5:25 arrivals, ten spectators, captain walk, retained cast, authored rooms, saved routes, departure, missed boat and rewind")
	quit()

func capture(_game, label: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/ending-"+label+".png")
