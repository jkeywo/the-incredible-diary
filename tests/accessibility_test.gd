extends SceneTree
const Play = preload("res://mission1/play.tscn")
const Sim = preload("res://mission1/simulation.gd")
const Save = preload("res://mission1/save.gd")
const SLOT_A := "res://build/accessibility-a.journal"
const SLOT_B := "res://build/accessibility-b.journal"

func _initialize() -> void: call_deferred("checks")

func key(code: int, echo := false) -> InputEventKey:
 var event := InputEventKey.new()
 event.physical_keycode = code
 event.keycode = code
 event.pressed = true
 event.echo = echo
 return event

func checks() -> void:
 var prefs = root.get_node("Preferences")
 prefs.settings_path = "res://build/accessibility.cfg"
 DirAccess.remove_absolute(prefs.settings_path)
 prefs.load_settings()
 assert(not prefs.high_contrast_text_panels and not prefs.instant_dialogue_text)
 var bindings = root.get_node("InputBindings")
 bindings.reset_device("keyboard")
 bindings.reset_device("controller")
 var game = Play.instantiate()
 game.sim = Sim.new(false)
 game.configure({},false)
 root.add_child(game)
 current_scene = game
 game.enable_controls()
 game.set_physics_process(false)
 await process_frame
 assert(not game.highlight)
 game._unhandled_input(key(KEY_F))
 assert(game.wait_requested)
 game._unhandled_input(key(KEY_F,true))
 assert(game.wait_requested)
 game._physics_process(0.1)
 assert(game.sim.s.frame >= 19)
 game._unhandled_input(key(KEY_F))
 assert(not game.wait_requested)
 # Shared controller B cancels pending interactions, otherwise toggles Wait.
 var cancel := InputEventJoypadButton.new()
 cancel.button_index = JOY_BUTTON_B
 cancel.pressed = true
 game.sim.s.code_open = true
 game._unhandled_input(cancel)
 assert(not game.sim.s.code_open and not game.wait_requested)
 game.sim.s.action = {"id":"inspect_bag"}
 game._unhandled_input(cancel)
 assert(game.sim.s.action.is_empty() and not game.wait_requested)
 game.sim.s.hospitality.menu = "directions"
 game._unhandled_input(cancel)
 assert(game.sim.s.hospitality.menu == "" and not game.wait_requested)
 game._unhandled_input(cancel)
 assert(game.wait_requested)
 game._unhandled_input(cancel)
 assert(not game.wait_requested)
 bindings.assign("wait","controller",0,{"kind":"trigger","code":JOY_AXIS_TRIGGER_RIGHT})
 for value in [0.8,0.9,0.7]:
  var trigger := InputEventJoypadMotion.new()
  trigger.axis = JOY_AXIS_TRIGGER_RIGHT
  trigger.axis_value = value
  game._unhandled_input(trigger)
  assert(game.wait_requested)
 for value in [0.0,0.8]:
  var trigger := InputEventJoypadMotion.new()
  trigger.axis = JOY_AXIS_TRIGGER_RIGHT
  trigger.axis_value = value
  game._unhandled_input(trigger)
 assert(not game.wait_requested)
 game._toggle_wait()
 game.touch_controls.movement = Vector2.RIGHT
 game.touch_controls.active = true
 game._physics_process(0.1)
 assert(not game.wait_requested)
 game.touch_controls.movement = Vector2.ZERO
 game._toggle_wait()
 game._choose(0)
 assert(not game.wait_requested)
 game.sim.s.action = {}
 game._toggle_wait()
 game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 assert(not game.wait_requested)
 game._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
 game._toggle_wait()
 Input.joy_connection_changed.emit(0,false)
 assert(not game.wait_requested)
 game._toggle_wait()
 paused = true
 assert(not game.wait_requested)
 paused = false
 game.sim.s.tick = Sim.HOUR-3
 game._toggle_wait()
 game._physics_process(0.1)
 assert(game.sim.s.tick == Sim.HOUR and not game.wait_requested)
 # Per-slot memory persists immediately, never entering history or device settings.
 Save.clear(SLOT_A)
 Save.clear(SLOT_B)
 game.save_path = SLOT_A
 game.save_enabled = true
 game._toggle_highlight()
 var loaded: Dictionary = Save.load_saved(SLOT_A)
 assert(loaded.ok and loaded.data.memory.highlight_enabled)
 assert(not loaded.data.current.has("highlight_enabled"))
 for frame in loaded.data.history: assert(not frame.has("highlight_enabled"))
 var fresh := Sim.new(false)
 assert(Save.new().save_run(fresh,SLOT_B).ok)
 var other: Dictionary = Save.load_saved(SLOT_B)
 assert(not other.data.memory.get("highlight_enabled",false))
 game.sim.reset()
 assert(game.sim.memory.highlight_enabled)
 game.initial = loaded.data
 game._restore_initial()
 assert(game.highlight and not game.wait_requested)
 game.initial = other.data
 game._restore_initial()
 assert(not game.highlight)
 game.save_enabled = false
 # Preferences change current renderers immediately without changing recorded data.
 game.sim.s.room = "controls"
 game.sim.s.pos = [350,350]
 game.sim.s.code_open = true
 game.sim.s.entry = "123"
 Sim.Conversations.say(game.sim,"amelia","We should look more closely.","thought")
 game._refresh()
 var panel = game.props.code_panel
 assert(panel.digits.text == "1 2 3")
 assert(panel.digits.get_rect() == panel.DISPLAY)
 assert(panel.status.text == "Steam ON")
 var recorded: Dictionary = game.sim.s.duplicate(true)
 var history: Array = game.sim.history.duplicate(true)
 var bubble = game.bubble
 bubble.present(game.sim.s.dialogue,0.1)
 var revealed: int = bubble.message_label.visible_characters
 bubble.background_opacity = 0.5
 prefs.high_contrast_text_panels = true
 prefs.instant_dialogue_text = true
 prefs.accessibility_changed.emit()
 assert(bubble.message_label.visible_characters == -1 and bubble.self_modulate.a == 1.0)
 assert(game.wheel.buttons[0].get_theme_stylebox("normal").high_contrast)
 assert(game.sim.s == recorded and game.sim.history == history)
 # Recorded state still determines the steam label, even after later changes.
 game.sim.s.flags.steam_off = true
 game._sync_props(game.sim.s)
 assert(panel.status.text == "Steam OFF")
 game._sync_props(recorded)
 assert(panel.status.text == "Steam ON")
 await capture("steam-contrast")
 prefs.instant_dialogue_text = false
 prefs.high_contrast_text_panels = false
 prefs.accessibility_changed.emit()
 assert(bubble.message_label.visible_characters == revealed and bubble.self_modulate.a == 0.5)
 # Both render modes produce exactly the same subsequent dialogue and diary history.
 var baseline := Sim.new(false)
 var accessible := Sim.new(false)
 var snapshot := {"current":recorded,"memory":game.sim.memory,"history":history}
 baseline.restore_record(snapshot)
 accessible.restore_record(snapshot)
 for i in 60:
  baseline.step()
  prefs.instant_dialogue_text = true
  prefs.accessibility_changed.emit()
  accessible.step()
 assert(baseline.s == accessible.s and baseline.history == accessible.history and baseline.memory == accessible.memory)
 prefs.high_contrast_text_panels = true
 prefs.save_settings()
 prefs.instant_dialogue_text = false
 prefs.high_contrast_text_panels = false
 prefs.load_settings()
 assert(prefs.high_contrast_text_panels and prefs.instant_dialogue_text)
 var settings = root.get_node("AudioSettings")
 settings.open_settings()
 settings.tabs.current_tab = settings.accessibility_tab.get_index()
 assert(settings._controller_choices()[0] == settings.accessibility_buttons[0])
 assert(settings.accessibility_buttons[0].button_pressed and settings.accessibility_buttons[1].button_pressed)
 settings.accessibility_buttons[0].grab_focus()
 settings.controller_menu.activate()
 assert(not prefs.high_contrast_text_panels and not settings.accessibility_buttons[0].button_pressed)
 settings.controller_menu.activate()
 assert(prefs.high_contrast_text_panels)
 settings.controller_menu.navigate(Vector2i.DOWN)
 settings.controller_menu.activate()
 assert(not prefs.instant_dialogue_text and not settings.accessibility_buttons[1].button_pressed)
 settings.controller_menu.activate()
 assert(prefs.instant_dialogue_text)
 await capture("settings")
 settings.close_settings()
 await create_timer(0.25).timeout
 root.size = Vector2i(740,1160)
 await process_frame
 game._refresh()
 await capture("touch-portrait")
 root.size = Vector2i(1160,740)
 game.queue_free()
 await process_frame
 Save.clear(SLOT_A)
 Save.clear(SLOT_B)
 DirAccess.remove_absolute(prefs.settings_path)
 print("ACCESSIBILITY PASS: toggle input, stop conditions, per-slot Highlight, preference persistence, rendering and recorded-state isolation")
 quit()

func capture(label: String) -> void:
 if "--screenshots" not in OS.get_cmdline_user_args(): return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/accessibility-"+label+".png")
