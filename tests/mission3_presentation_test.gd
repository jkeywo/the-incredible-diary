extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Play = preload("res://mission1/play.tscn")

func _initialize() -> void: call_deferred("checks")

func checks() -> void:
	var run := Sim.new(false)
	run.start_mission_three()
	var game = Play.instantiate()
	game.configure({"current":run.s,"memory":run.memory,"history":run.history,"authored_content":run.authored_content,"content_versions":run.content_versions},false)
	root.add_child(game)
	current_scene = game
	game.enable_controls()
	game.set_process(false)
	game.set_physics_process(false)
	for room in ["docks","restaurant","market"]:
		game.sim.s.room = room
		game.sim.s.pos = [1010,465] if room == "restaurant" else [580,500]
		game.sim.s.actors = {"guest":{"room":room,"pos":[600,450],"action":"idle","facing":"down"},"dock_sailor":{"room":room,"pos":[900,500],"action":"idle","facing":"down"}}
		game._refresh()
		assert(game.heading.text.begins_with("Mission 3"))
		if room == "docks":
			var dock = game.room_slot.get_child(0)
			assert(dock.get_node("Ship").texture.resource_path == "res://assets/rooms/mission_1/01_docks_ship.png")
			assert(dock.get_node("Water").texture.resource_path == "res://assets/rooms/mission_1/01_docks_water.png")
		await process_frame
		await process_frame
		if "--screenshots" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/mission3-%s.png" % room)
	game.sim.s.finished = true
	game.sim.s.tick = 10800
	game._refresh()
	assert(game.diary_title.text == "SCHEDULE COMPLETE")
	assert(not game.diary_next.visible and game.diary_menu.visible)
	print("MISSION3 PRESENTATION PASS: Greek rooms, character scale staging and reused ship/sea layers")
	quit()
