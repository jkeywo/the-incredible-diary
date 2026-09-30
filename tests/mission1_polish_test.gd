extends SceneTree
const Play = preload("res://mission1/play.tscn")
const Sim = preload("res://mission1/simulation.gd")
const Save = preload("res://mission1/save.gd")
const Title = preload("res://assets/ui/mission_1/title_screen.tscn")
const Accents = preload("res://assets/effects/mission_1/physical_accents.gd")
const PATH := "res://build/polish-save.journal"

func _initialize() -> void: call_deferred("checks")

func checks() -> void:
	Save.clear(PATH)
	var game = Play.instantiate()
	game.sim = Sim.new(false)
	game.configure({},false)
	root.add_child(game)
	current_scene = game
	game.enable_controls()
	game.set_physics_process(false)
	game.set_process(false)
	await process_frame
	var last_watch := -1.0
	for i in 120:
		game._physics_process(1.0/60.0)
		game._process(1.0/60.0)
		assert(game.watch.elapsed_seconds >= last_watch)
		last_watch = game.watch.elapsed_seconds
	game._toggle_diary()
	var tick: int = game.sim.s.tick
	game.diary_presentation.advance(0.08)
	game._physics_process(1.0)
	assert(game.sim.s.tick == tick and game.diary_open)
	game._toggle_diary()
	game.diary_presentation.advance(0.02)
	game._toggle_diary()
	game.diary_presentation.advance(0.2)
	assert(game.diary_presentation.phase == "open" and game.diary.modulate.a == 1.0)
	await capture("diary")
	game._toggle_diary()
	assert(game.diary_open)
	game.diary_presentation.advance(0.2)
	assert(not game.diary_open and not game.diary.visible)
	game.sim.s.room = "foyer"
	game.sim.s.flags.chandelier_fallen = true
	game.sim.s.flags.chandelier_impact_frame = game.sim.s.frame
	game._refresh()
	var hud_position: Vector2 = game.watch.global_position
	assert(game.entity_layer.position.length() <= 2.0 and game.entity_layer.position != Vector2.ZERO)
	for i in 3: game.sim.step()
	game._refresh()
	assert(game.entity_layer.position == Vector2.ZERO and game.watch.global_position == hud_position)
	assert(game.props.chandelier.get_node("Dust").visible)
	await capture("impact")
	var fixture = game.props.chandelier
	fixture.show_at(false,1.0,0.4,0.4)
	var sampled: Vector2 = fixture.get_node("Dust").scale
	fixture.show_at(false,1.0,0.75,0.75)
	fixture.show_at(false,1.0,0.4,0.4)
	assert(fixture.get_node("Dust").scale == sampled)
	fixture.show_at(false,1.0,0.81,0.81)
	assert(not fixture.get_node("Dust").visible and not fixture.accents.visible)
	for age in [0.0,0.05,0.1,0.15,0.2]: assert(Accents.impact_offset(age).length() <= 2.0)
	game.sim.s.room = "salon"
	game.sim.s.flags.party_arrived = true
	game.sim.s.flags.spilled = true
	game.sim.s.flags.spill_frame = game.sim.s.frame-2
	game.sim.s.flags.spill_tick = game.sim.s.tick
	game.sim.s.flags.glass_drop = [880,450]
	game._refresh()
	assert(game.props.drink.accents.visible)
	assert((game.props.drink.scale*game.props.drink.accents.scale).is_equal_approx(Vector2.ONE))
	await capture("spill")
	game.sim.s.room = "controls"
	game.sim.s.pos = [350,300]
	game.sim.s.tick = Sim.TRAP+5
	game.sim.s.flags.trapped = true
	game.sim.s.code_open = true
	game.sim.s.entry = game.sim.s.code
	assert(game.sim.submit_code())
	assert(game.sim.s.flags.steam_shutdown_visible and not Sim.Rooms.steam_blocked(game.sim.s.flags))
	game.sim.step()
	game.sim.step()
	game._refresh()
	assert(game.props.room_steam.visible and game.props.room_steam.density < 1.0)
	var density: float = game.props.room_steam.density
	assert(Save.new().save_run(game.sim,PATH).ok)
	var resumed := Sim.new(false)
	Save.new().restore_run(resumed,Save.load_saved(PATH).data)
	game._sync_props(resumed.s)
	assert(is_equal_approx(game.props.room_steam.density,density))
	await capture("steam")
	var recorded: Dictionary = resumed.s.duplicate(true)
	resumed.s.flags.steam_off = false
	game._sync_props(resumed.s)
	assert(game.props.room_steam.density == 1.0)
	game._sync_props(recorded)
	assert(is_equal_approx(game.props.room_steam.density,density))
	resumed.s.flags.steam_off = true
	resumed.s.flags.erase("steam_shutdown_frame")
	game._sync_props(resumed.s)
	assert(not game.props.room_steam.visible)
	var early := Sim.new(false)
	early.s.room = "controls"
	early.s.pos = [350,300]
	early.s.code_open = true
	early.s.entry = early.s.code
	assert(early.submit_code() and not early.s.flags.steam_shutdown_visible)
	game.sim.s.room = "docks"
	game._refresh()
	assert(game.entity_layer.position == Vector2.ZERO)
	game.time_presentation.waiting = true
	game.time_presentation.advance(0.2)
	assert(game.time_presentation.halo == 1.0)
	game.time_presentation.announce_hour(3)
	assert(game.time_presentation.hour_text == "3:00")
	await capture("watch")
	game.sim.memory.reset = true
	game._begin_reset()
	game._rewind(1.0)
	game._process(0.0)
	await capture("rewind")
	game._begin_reset()
	assert(game.rewind_index == -1 and game.time_presentation.finish_remaining > 0.0)
	game._physics_process(0.5)
	assert(game.sim.s.tick == 0)
	game._process(0.2)
	assert(game.time_presentation.finish_remaining == 0.0 and not game.time_presentation.rewinding)
	game.queue_free()
	await process_frame
	var title = Title.instantiate()
	title.mission_save_path = PATH
	root.add_child(title)
	current_scene = title
	await process_frame
	assert(title.preview.visible and title.preview.text.contains("All Aboard"))
	await create_timer(0.3).timeout
	await capture("title")
	title._on_new()
	assert(title.new_confirm.visible and not title._opening)
	title._on_continue()
	assert(not title._opening)
	title.new_confirm.canceled.emit()
	await create_timer(0.2).timeout
	assert(not title.new_confirm.visible)
	var settings = root.get_node("AudioSettings")
	settings.settings_path = "res://build/polish-settings.cfg"
	settings.open_settings()
	await create_timer(0.2).timeout
	await capture("settings")
	settings.close_settings()
	assert(paused)
	await create_timer(0.2).timeout
	assert(not paused and not settings.dialog.visible)
	title.queue_free()
	await process_frame
	Save.clear(PATH)
	print("MISSION1 POLISH PASS: reversible diary, sampled impacts/spill/steam, save/history, rewind finish, watch, preview and modal pause")
	await preload("res://tests/shutdown.gd").finish(self)

func capture(label: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/polish-"+label+".png")
