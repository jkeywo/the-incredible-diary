extends SceneTree
const Title = preload("res://assets/ui/mission_1/title_screen.tscn")
const Sim = preload("res://mission1/simulation.gd")
const Save = preload("res://mission1/save.gd")
const PATH := "res://build/controller-menu.journal"

func _initialize() -> void: call_deferred("checks")

func button(viewport: Viewport, id: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = id
	event.pressed = true
	viewport.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event,true)

func axis(viewport: Viewport, id: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = id
	event.axis_value = value
	viewport.push_input(event,true)

func checks() -> void:
	Save.clear(PATH)
	var run := Sim.new(false)
	run.s.finished = true
	run.s.room = "salon"
	assert(Save.new().save_run(run,PATH).ok)
	var title = Title.instantiate()
	title.mission_save_path = PATH
	root.add_child(title)
	current_scene = title
	await process_frame
	await process_frame
	assert(title.preview.get_parent() == title.menu)
	assert(title.preview.position.y >= title.continue_button.position.y+title.continue_button.size.y)
	assert(title.get_node("Menu/NewButton").position.y >= title.preview.position.y+title.preview.size.y)
	assert(title.preview.text.contains("Voyage complete") and not title.preview.text.contains("Salon"))
	assert(root.gui_get_focus_owner() == title.continue_button)
	axis(root,JOY_AXIS_LEFT_Y,0.2)
	assert(root.gui_get_focus_owner() == title.continue_button)
	axis(root,JOY_AXIS_LEFT_Y,0.8)
	assert(root.gui_get_focus_owner() == title.get_node("Menu/NewButton"))
	axis(root,JOY_AXIS_LEFT_Y,0.0)
	axis(root,JOY_AXIS_LEFT_Y,0.8)
	axis(root,JOY_AXIS_LEFT_Y,0.0)
	assert(root.gui_get_focus_owner() == title.settings_button)
	button(root,JOY_BUTTON_A)
	var settings = root.get_node("AudioSettings")
	settings.settings_path = "res://build/controller-settings.cfg"
	assert(settings._opened and paused and not title.new_confirm.visible)
	assert(settings.dialog.gui_get_focus_owner() == settings.sliders.Master)
	var volume: float = settings.volumes.Master
	axis(settings.dialog,JOY_AXIS_LEFT_X,-0.8)
	axis(settings.dialog,JOY_AXIS_LEFT_X,0.0)
	assert(settings.volumes.Master == maxf(0,volume-5))
	axis(settings.dialog,JOY_AXIS_LEFT_Y,0.8)
	axis(settings.dialog,JOY_AXIS_LEFT_Y,0.0)
	assert(settings.dialog.gui_get_focus_owner() == settings.sliders.SFX)
	settings.touch_available = true
	settings._refresh_controls_tab()
	button(settings.dialog,JOY_BUTTON_RIGHT_SHOULDER)
	assert(settings.tabs.current_tab == 1 and settings.dialog.gui_get_focus_owner() == settings.stick_side)
	var original_side: bool = settings.stick_on_right
	button(settings.dialog,JOY_BUTTON_A)
	assert(settings.stick_on_right != original_side)
	button(settings.dialog,JOY_BUTTON_LEFT_SHOULDER)
	assert(settings.tabs.current_tab == 0 and settings.dialog.gui_get_focus_owner() == settings.sliders.Master)
	settings.touch_available = false
	settings._refresh_controls_tab()
	button(settings.dialog,JOY_BUTTON_RIGHT_SHOULDER)
	assert(settings.tabs.current_tab == 0)
	button(settings.dialog,JOY_BUTTON_B)
	await create_timer(0.2).timeout
	assert(not settings._opened and not paused)
	assert(root.gui_get_focus_owner() == title.settings_button)
	button(root,JOY_BUTTON_START)
	assert(settings._opened and paused)
	button(settings.dialog,JOY_BUTTON_B)
	await create_timer(0.2).timeout
	title.get_node("Menu/NewButton").grab_focus()
	button(root,JOY_BUTTON_A)
	await process_frame
	assert(title.new_confirm.visible and title.new_confirm.gui_get_focus_owner() == title.new_confirm.get_cancel_button())
	button(title.new_confirm,JOY_BUTTON_B)
	await create_timer(0.2).timeout
	assert(not title.new_confirm.visible and Save.load_saved(PATH).ok)
	assert(root.gui_get_focus_owner() == title.get_node("Menu/NewButton"))
	await capture("menu")
	# Start opens Settings in gameplay and does not invoke editor pause or a game action.
	title.continue_button.grab_focus()
	button(root,JOY_BUTTON_A)
	await create_timer(1.9).timeout
	var game = title._game_world
	assert(is_instance_valid(game) and game.controls_enabled)
	game.sim.s.finished = false
	game.sim.s.action = {}
	var highlight: bool = game.highlight
	button(root,JOY_BUTTON_START)
	assert(settings._opened and paused and not root.get_node("PauseEditor").owns_pause)
	var tick: int = game.sim.s.tick
	button(settings.dialog,JOY_BUTTON_A)
	await create_timer(0.15).timeout
	assert(game.sim.s.tick == tick and game.highlight == highlight and game.sim.s.action.is_empty())
	await capture("settings")
	button(settings.dialog,JOY_BUTTON_B)
	await create_timer(0.2).timeout
	assert(not paused and not settings._opened)
	game.save_enabled = false
	title.queue_free()
	await process_frame
	Save.clear(PATH)
	print("CONTROLLER MENU PASS: preview gap/outcome, stick focus, A/B, Start, sliders, visible tabs, confirmation and gameplay isolation")
	quit()

func capture(label: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/controller-"+label+".png")
