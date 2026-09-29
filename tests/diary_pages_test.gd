extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Save = preload("res://mission1/save.gd")
const PATH := "res://build/diary-body.journal"

func _initialize() -> void: call_deferred("checks")

func checks() -> void:
	Save.clear(PATH)
	var run := Sim.new(false)
	run.memory.hints = {"highlight":true,"wait":true}
	run.s.room = "docks"
	run._death("chandelier_guest","A death I could not see.","foyer")
	Sim.Hints.update(run)
	assert(run.memory.reset and run.s.get("body_thought_queue",[]).is_empty())
	assert(run.s.get("dialogue",{}).get("hint","") != "diary")
	run.s.room = "foyer"
	run._observe_rescues()
	run.s.dialogue = {"busy":true}
	Sim.Hints.update(run)
	assert(run.s.body_thought_queue == ["chandelier_guest"])
	run.s.dialogue = {}
	Sim.Hints.update(run)
	assert(run.s.dialogue.victim == "chandelier_guest" and run.s.dialogue.kind == "thought")
	assert(run.s.dialogue.text == "What a tragedy. Hmmm, my diary is shaking, I feel like I should take a look.")
	assert(Sim.Hints.prompt("diary",false,false) == "Tab — Open diary")
	assert(Save.new().save_run(run,PATH).ok)
	var restored := Sim.new(false)
	Save.new().restore_run(restored,Save.load_saved(PATH).data)
	assert(restored.s.dialogue == JSON.parse_string(JSON.stringify(run.s.dialogue)))
	restored.s.dialogue = {}
	restored._observe_rescues()
	Sim.Hints.update(restored)
	assert(restored.s.body_thought_queue.is_empty() and restored.s.dialogue.is_empty())
	for victim in ["guest","chatterbox"]:
		var room := "salon" if victim == "guest" else "controls"
		restored.s.room = room
		restored._death(victim,"A witnessed death.",room)
		restored._observe_rescues()
		Sim.Hints.update(restored)
		assert(restored.s.dialogue.is_empty())
		restored.s.dialogue = {}
	restored.reset()
	restored.s.room = "foyer"
	restored._death("chandelier_guest","Another loop.","foyer")
	restored._observe_rescues()
	Sim.Hints.update(restored)
	assert(restored.s.dialogue.is_empty())
	assert(restored.memory.hints.diary)
	var fresh := Sim.new(false)
	fresh.memory.hints = {"highlight":true,"wait":true}
	fresh.s.room = "foyer"
	fresh._death("chandelier_guest","A new playthrough.","foyer")
	fresh._observe_rescues()
	Sim.Hints.update(fresh)
	assert(fresh.s.dialogue.get("hint","") == "diary")
	var game = preload("res://mission1/play.tscn").instantiate()
	game.sim = Sim.new(false)
	game.configure({},false)
	root.add_child(game)
	current_scene = game
	game.enable_controls()
	game.set_physics_process(false)
	game.set_process(false)
	for i in 75:
		game.sim.memory.notes.append("01:%02d — Entry %d. A passenger crossed the foyer and stopped to speak beside the staircase. I should remember what I saw." % [i%60,i])
	game.sim.memory.reset = true
	game._toggle_diary()
	game.diary_presentation.advance(0.2)
	assert(game.diary_pages.spread == game.diary_pages.last_spread() and game.diary_pages.pages.size() > 5)
	assert(game.diary_reset.visible and not game.diary_instructions.visible)
	assert(game.diary_reset.text == "Turn back to the start (R)")
	assert(game.diary_reset.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(not game.diary_text.scroll_active and not game.diary_right_text.scroll_active)
	await capture("last")
	game.diary_close.grab_focus()
	var previous := InputEventKey.new()
	previous.physical_keycode = KEY_LEFT
	previous.pressed = true
	root.push_input(previous,true)
	assert(game.diary_pages.spread == game.diary_pages.last_spread()-1)
	var next := InputEventJoypadButton.new()
	next.button_index = JOY_BUTTON_RIGHT_SHOULDER
	next.pressed = true
	root.push_input(next,true)
	assert(game.diary_pages.spread == game.diary_pages.last_spread())
	var pages_text: String = " ".join(game.diary_pages.pages)
	for i in 75: assert(pages_text.contains("Entry %d." % i))
	game._turn_diary(-1000)
	assert(game.diary_pages.spread == 0 and game.diary_reset.visible and not game.diary_close.visible)
	assert(game.diary_right_text.visible and not game.diary_instructions.visible)
	await capture("first")
	for spread in range(game.diary_pages.last_spread()+1):
		game.diary_pages.spread = spread
		game._refresh_diary()
		assert(game.diary_reset.visible == (spread == 0 or spread == game.diary_pages.last_spread()))
		await process_frame
		await process_frame
		assert(game.diary_text.get_content_height() <= game.diary_text.size.y)
		if game.diary_right_text.visible: assert(game.diary_right_text.get_content_height() <= game.diary_right_text.size.y)
	game._turn_diary(-1000)
	game._toggle_diary()
	game.diary_presentation.advance(0.2)
	game._toggle_diary()
	assert(game.diary_pages.spread == game.diary_pages.last_spread())
	game.diary_presentation.advance(0.2)
	game._toggle_diary()
	game.diary_presentation.advance(0.2)
	game.sim.s.tutorial = "done"
	game.sim.s.room = "foyer"
	game.sim.s.flags.chandelier_fallen = true
	game.sim.s.dead = ["chandelier_guest"]
	game.sim.s.actors = game.sim.actor_positions()
	game.sim.s.dialogue = run.s.dialogue.duplicate(true)
	game.sim.s.dialogue.room = "foyer"
	game.sim.s.frame = 100
	game.sim.s.dialogue.started = 0
	game.sim.s.dialogue.until = 200
	game._refresh()
	await capture("magic")
	game.sim.s.finished = true
	game._refresh()
	game.diary_presentation.advance(0.2)
	await process_frame
	await process_frame
	assert(game.diary_text.text.contains("The unmooring party is over"))
	assert(game.diary_text.get_content_height() <= game.diary_text.size.y)
	await capture("outcome")
	game.sim.s.finished = false
	game.sim.memory.notes = []
	game._refresh_diary()
	assert(game.diary_pages.spread == 0 and game.diary_pages.last_spread() == 0)
	assert(game.diary_reset.visible and not game.diary_instructions.visible)
	game.queue_free()
	await process_frame
	Save.clear(PATH)
	print("DIARY PAGES PASS: seen bodies only, once per playthrough, queue and save continuity, fresh New discovery, fitted pages, end opening and final actions")
	quit()

func capture(label: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/diary-pages-"+label+".png")
