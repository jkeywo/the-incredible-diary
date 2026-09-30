extends Node2D
## Mission 1 presentation; all consequential state lives in the deterministic simulation.
const ContentPlan = preload("res://mission1/content_plan.gd")
const LoadingDiary = preload("res://assets/ui/loading/level_wait.gd")
const TouchControls = preload("res://assets/ui/mission_1/touch_controls.gd")
const Simulation = preload("res://mission1/simulation.gd")
const Rooms = preload("res://mission1/rooms.gd")
const Watch = preload("res://mission1/pocket_watch.gd")
const Character = preload("res://assets/characters/character_sprite.tscn")
const RoomAudio = preload("res://mission1/room_audio.gd")
const EventAudio = preload("res://mission1/event_audio.gd")
const Save = preload("res://mission1/save.gd")
# A position-only actor keeps interaction/bubble anchors correct while art loads.
class PendingCharacter extends AnimatedSprite2D:
 var stained_outfit := false
 func play_action(_action: String, _direction: String) -> void: pass
 func set_outfit_stained(value: bool) -> void: stained_outfit = value

var character_ticket: Dictionary = {}
var _character_retry_at := 0
var stream_resources := false
var _content_key := ""
var _content_ticket: Dictionary = {}
var _content_overlay: CanvasLayer
var _content_diary: Control
var _content_error: Label
var _prefetched_room := ""
var _neighbour_ticket: Dictionary = {}
var _content_failure_shown := false
var journal := Save.new()
var sim := Simulation.new()
var controls_enabled := false
var save_path := Save.DEFAULT_PATH
var save_enabled := false
var room_slot: Node2D
var entity_layer: Node2D
var world_overlay: Node2D
var actors := {}
var props := {}
var prop_images := {}
var opening_audio_fade := 1.0
var room_audio: Node
var sounds: Node
var watch: Control
var heading: Label
var message: Label
var notice: Label
var help: Label
var touch_controls: Control
var movement_prompt: Control
var carrying: Label
var using_controller := false
var hud: Control
var bubble: Control
var wheel: Control
var wheel_labels: Array = []
var choices: Array = []
var progress: ProgressBar
var shown_room := ""
var accumulator := 0.0
var highlight := false
var idle_seconds := 0.0
var application_focused := true
var hint_prompt: Label
var wait_latched := false
var initial: Dictionary = {}
var diary: Control
var diary_title: Label
var diary_page_title: Label
var diary_instructions: Label
var diary_close: Button
var diary_reset: Button
var diary_next: Button
var diary_menu: Button
var end_presented := false
var ending: Control
const CUT_FADE_SECONDS := 0.18
var cut_fade: ColorRect
var cut_fade_phase := ""
var cut_fade_elapsed := 0.0
var bubble_identity := ""
var bubble_offset := Vector2.ZERO
var diary_text: RichTextLabel
var diary_right_text: RichTextLabel
var diary_space: Control
var diary_previous_page: Button
var diary_following_page: Button
var diary_page_numbers: Label
var diary_pages = preload("res://assets/ui/mission_1/diary_pages.gd").new()
var diary_cached_text := ""
var diary_seek_end := true
var diary_navigation: Node
var diary_open := false
var _save_counter := 0
var rewind_index := -1
var rewind_accumulator := 0.0
var _footstep := 0.0
var diary_presentation: Node
var time_presentation: Control
var waiting_active := false
var rewind_start := 0
var visual_elapsed := 0.0
var authoring_editor: CanvasLayer
var pending_authoring_restart: Dictionary = {}

func configure(saved: Dictionary = {}, enable_save := true) -> void:
 initial = saved.duplicate(true)
 save_enabled = enable_save

func _ready() -> void:
 if stream_resources and character_ticket.is_empty():
  character_ticket = get_node("/root/ResourceStream").request_resources(ContentPlan.level_characters(),false,2)
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 room_slot = Node2D.new()
 add_child(room_slot)
 entity_layer = Node2D.new()
 entity_layer.y_sort_enabled = true
 add_child(entity_layer)
 if room_audio == null:
  room_audio = RoomAudio.new()
  add_child(room_audio)
 elif room_audio.get_parent() != self:
  room_audio.reparent(self)
 sounds = EventAudio.new()
 add_child(sounds)
 world_overlay = Node2D.new()
 world_overlay.z_index = 10
 add_child(world_overlay)
 world_overlay.draw.connect(_draw_world_markers)
 _build_hud()
 var fade_layer := CanvasLayer.new()
 fade_layer.layer = 20
 add_child(fade_layer)
 cut_fade = ColorRect.new()
 cut_fade.color = Color.BLACK
 cut_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 cut_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fade_layer.add_child(cut_fade)
 cut_fade.hide()
 hint_prompt = _label(Vector2.ZERO,Vector2(350,32),17)
 hint_prompt.hide()
 _restore_initial()
 if initial.is_empty() and sim.authored_content.is_empty():
  var content := preload("res://mission1/authoring_content.gd").seed(Simulation.new(false).s.actors)
  var applied := sim.apply_authored(content)
  if not applied.ok: push_error(applied.reason)
 _refresh()
 if get_tree().current_scene == self: enable_controls()

func enable_controls() -> void:
 controls_enabled = true

func is_pause_editor_available() -> bool:
 return controls_enabled and (_content_ticket.is_empty() or (_content_ticket.done and str(_content_ticket.error).is_empty()))

func _build_hud() -> void:
 var layer := CanvasLayer.new()
 layer.layer = 5
 add_child(layer)
 hud = Control.new()
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 layer.add_child(hud)
 ending = preload("res://assets/ui/mission_1/ending_sequence.gd").new()
 layer.add_child(ending)
 watch = Watch.new()
 watch.position = Vector2(1010, 36)
 hud.add_child(watch)
 heading = _label(Vector2(64,18), Vector2(760,35), 23)
 notice = _label(Vector2(25,62), Vector2(870,85), 17)
 message = _label(Vector2(25,620), Vector2(900,65), 18)
 help = _label(Vector2(25,696), Vector2(1110,36), 15)
 help.text = ""
 help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 help.size = Vector2(320,60)
 movement_prompt = preload("res://assets/ui/mission_1/movement_prompt.gd").new()
 movement_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
 hud.add_child(movement_prompt)
 carrying = _label(Vector2(25,665),Vector2(500,28),17)
 progress = ProgressBar.new()
 progress.position = Vector2(440,585)
 progress.size = Vector2(280,14)
 progress.show_percentage = false
 hud.add_child(progress)
 wheel = preload("res://assets/ui/mission_1/action_wheel.tscn").instantiate()
 wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 hud.add_child(wheel)
 wheel.option_confirmed.connect(func(index: int, _label: String): _choose(index))
 bubble = preload("res://assets/ui/mission_1/speech_bubble.tscn").instantiate()
 bubble.bubble_size = Vector2(350,154)
 bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
 hud.add_child(bubble)
 bubble.hide()
 diary = preload("res://assets/ui/mission_1/open_diary.tscn").instantiate()
 diary.get_node("LeftPageContent").offset_bottom = 580
 diary.get_node("RightPageContent").offset_bottom = 580
 hud.add_child(diary)
 var column := VBoxContainer.new()
 diary.get_node("LeftPageContent").add_child(column)
 column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 column.offset_left = 55
 column.offset_right = -15
 column.add_theme_constant_override("separation", 18)
 var title := Label.new()
 diary_title = title
 title.text = "VOYAGE NOTEBOOK"
 title.add_theme_color_override("font_color", Color("342f29"))
 title.add_theme_font_size_override("font_size", 24)
 column.add_child(title)
 diary_text = RichTextLabel.new()
 diary_text.scroll_active = false
 diary_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
 diary_text.add_theme_color_override("default_color", Color("342f29"))
 diary_text.add_theme_font_size_override("normal_font_size", 18)
 column.add_child(diary_text)
 var right_page := VBoxContainer.new()
 diary.get_node("RightPageContent").add_child(right_page)
 right_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 right_page.offset_left = 40
 right_page.offset_right = -10
 right_page.add_theme_constant_override("separation", 18)
 var page_title := Label.new()
 diary_page_title = page_title
 page_title.text = "THE VOYAGE"
 page_title.add_theme_color_override("font_color", Color("342f29"))
 page_title.add_theme_font_size_override("font_size", 24)
 right_page.add_child(page_title)
 diary_right_text = RichTextLabel.new()
 diary_right_text.scroll_active = false
 diary_right_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
 diary_right_text.add_theme_color_override("default_color",Color("342f29"))
 diary_right_text.add_theme_font_size_override("normal_font_size",18)
 right_page.add_child(diary_right_text)
 var instructions := Label.new()
 diary_instructions = instructions
 instructions.text = "Observations from the current voyage, recorded as they happen."
 instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 instructions.add_theme_color_override("font_color", Color("342f29"))
 instructions.add_theme_font_size_override("font_size", 18)
 right_page.add_child(instructions)
 var space := Control.new()
 diary_space = space
 space.size_flags_vertical = Control.SIZE_EXPAND_FILL
 right_page.add_child(space)
 right_page.theme = preload("res://assets/ui/mission_1/diary_buttons.gd").make_theme()
 var close := Button.new()
 diary_close = close
 close.text = "X"
 close.tooltip_text = "Close diary (Tab / Y)"
 close.position = Vector2(970,65)
 close.size = Vector2(44,40)
 close.theme = right_page.theme
 preload("res://assets/ui/mission_1/diary_buttons.gd").square(close)
 close.pressed.connect(_toggle_diary)
 diary.add_child(close)
 var reset := Button.new()
 diary_reset = reset
 reset.theme = right_page.theme
 reset.text = "Turn back to the start (R)"
 reset.pressed.connect(_begin_reset)
 right_page.add_child(reset)
 reset.add_child(preload("res://assets/ui/mission_1/diary_sparkles.gd").new())
 diary_next = Button.new()
 diary_next.text = "Turn the Page"
 diary_next.pressed.connect(_next_mission)
 right_page.add_child(diary_next)
 diary_menu = Button.new()
 diary_menu.text = "Return to main menu"
 diary_menu.pressed.connect(_return_to_menu)
 right_page.add_child(diary_menu)
 var page_navigation := HBoxContainer.new()
 page_navigation.position = Vector2(205,590)
 page_navigation.size = Vector2(795,38)
 page_navigation.theme = right_page.theme
 diary.add_child(page_navigation)
 diary_previous_page = Button.new()
 diary_previous_page.text = "‹ Previous"
 diary_previous_page.pressed.connect(func(): _turn_diary(-1))
 page_navigation.add_child(diary_previous_page)
 diary_page_numbers = Label.new()
 diary_page_numbers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 diary_page_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 diary_page_numbers.add_theme_color_override("font_color",Color("342f29"))
 page_navigation.add_child(diary_page_numbers)
 diary_following_page = Button.new()
 diary_following_page.text = "Next ›"
 diary_following_page.pressed.connect(func(): _turn_diary(1))
 page_navigation.add_child(diary_following_page)
 for page_button in [diary_previous_page,diary_following_page]:
  page_button.add_theme_font_size_override("font_size",18)
  page_button.custom_minimum_size = Vector2(124,44)
 diary_navigation = preload("res://foundation/controller_menu.gd").new()
 diary_navigation.available = func(): return [diary_previous_page,diary_following_page,diary_close,diary_reset,diary_next,diary_menu]
 diary_navigation.enabled = func(): return diary_open and diary_presentation.wanted and not get_tree().paused
 diary_navigation.back = _toggle_diary
 diary_navigation.change_tab = _turn_diary
 diary.add_child(diary_navigation)
 diary.hide()
 diary_presentation = preload("res://assets/ui/mission_1/diary_presentation.gd").new()
 add_child(diary_presentation)
 diary_presentation.setup(diary)
 diary_presentation.closed.connect(func(): diary_open = false; accumulator = 0.0)
 time_presentation = preload("res://assets/ui/mission_1/time_presentation.gd").new()
 hud.add_child(time_presentation)
 touch_controls = TouchControls.new()
 hud.add_child(touch_controls)
 touch_controls.action_pressed.connect(_touch_action)

func _touch_action(action: String) -> void:
 var display := _display_state()
 if stream_resources and not _prepare_visible(display): return
 get_node("/root/ButtonFeedback").activate()
 idle_seconds = 0.0
 if not controls_enabled or get_tree().paused or not application_focused or time_presentation.finish_remaining > 0.0: return
 match action:
  "diary": _toggle_diary()
  "cancel":
   if diary_open: _toggle_diary()
   else:
    sim.s.action = {}
    sim.s.code_open = false
    sim.s.hospitality.menu = ""
    sim.s.message = "Action cancelled."
  "highlight":
   if not diary_open and rewind_index<0: highlight = not highlight
 _refresh()

func _movement_input() -> Vector2:
 var direction := Input.get_vector("move_left","move_right","move_up","move_down")
 if touch_controls != null and touch_controls.active and touch_controls.movement.length_squared()>0.0:
  direction = touch_controls.movement
 return direction

func _label(p: Vector2, dimensions: Vector2, font_size: int) -> Label:
 var label := Label.new()
 label.position = p
 label.size = dimensions
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size", font_size)
 label.add_theme_color_override("font_color", Color("fff1cc"))
 label.add_theme_color_override("font_outline_color", Color("14222c"))
 label.add_theme_constant_override("outline_size", 7)
 hud.add_child(label)
 return label

func _process(delta: float) -> void:
 if stream_resources:
  _refresh_character_art()
 if not is_instance_valid(time_presentation): return
 if stream_resources and not _prepare_visible(_display_state()): return
 time_presentation.suppressed = diary_open or sim.s.finished or not application_focused
 time_presentation.waiting = waiting_active and not diary_open and application_focused and controls_enabled
 time_presentation.rewinding = rewind_index >= 0
 time_presentation.rewind_progress = 1.0-float(rewind_index)/maxf(1.0,rewind_start) if rewind_index >= 0 else 0.0
 if not application_focused: return
 if not cut_fade_phase.is_empty():
  if cut_fade_phase == "in":
   for id in ending.state.actors:
    if ending.state.actors[id].room != ending.state.room: continue
    _ensure_actor(id)
    if actors[id] is PendingCharacter: return
  if not get_tree().paused: _advance_cut_fade(delta)
  return
 if ending.active():
  if get_tree().paused: return
  # The cutscene waits for its cast as well as its destination room.
  for id in ending.state.actors:
   if ending.state.actors[id].room != ending.state.room: continue
   _ensure_actor(id)
   if actors[id] is PendingCharacter: return
  ending.advance(delta)
  _refresh()
  return
 diary_presentation.advance(delta)
 time_presentation.advance(delta)
 if time_presentation.finish_remaining > 0.0: return
 if controls_enabled and not diary_open and rewind_index < 0 and not sim.s.finished:
  visual_elapsed = minf(0.099,visual_elapsed+delta)
  _sync_props(sim.s)
  if not sim.tutorial_active():
   watch.elapsed_seconds = minf(sim.timing("end",Simulation.END),float(sim.s.tick)+float(sim.s.get("clock_fraction",0.0))+minf(0.99,(accumulator+visual_elapsed)/0.1)*Simulation.CLOCK_RATE)/10.0

func _physics_process(delta: float) -> void:
 if stream_resources and not _prepare_visible(_display_state()):
  accumulator = 0.0
  return
 visual_elapsed = 0.0
 waiting_active = false
 _update_idle_hint(delta)
 if not controls_enabled or get_tree().paused or not application_focused or time_presentation.finish_remaining > 0.0: return
 if rewind_index >= 0:
  _rewind(delta)
  return
 if diary_open or sim.s.finished: return
 var held: bool = Input.is_physical_key_pressed(KEY_F) or Input.is_joy_button_pressed(0,JOY_BUTTON_B) or touch_controls.wait_held
 if not held: wait_latched = false
 var waiting: bool = held and not wait_latched and not sim.tutorial_active() and not sim.s.code_open and sim.s.hospitality.menu == "" and sim.s.action.is_empty()
 waiting_active = waiting
 accumulator += delta * (20.0 if waiting else 1.0)
 var direction := _movement_input() if not waiting else Vector2.ZERO
 while accumulator >= 0.1:
  accumulator -= 0.1
  var old_hour := int(sim.s.tick/Simulation.HOUR)
  sim.step(direction)
  _events()
  if stream_resources and not _prepare_visible(sim.s):
   accumulator = 0.0
   break
  _save_counter += 1
  if waiting and int(sim.s.tick/Simulation.HOUR) > old_hour:
   wait_latched = true
   waiting_active = false
   accumulator = 0.0
   break
  if sim.s.finished: break
 if direction.length_squared() > 0.01:
  _footstep += delta
  if _footstep >= 0.35:
   _footstep = 0.0
   sounds.play_cue(&"footstep_dock" if sim.s.room == "docks" else &"footstep_wood")
 _refresh(direction)
 if _save_counter >= 10:
  _save_counter = 0
  _persist()

func _unhandled_input(event: InputEvent) -> void:
 if stream_resources and not _prepare_visible(_display_state()): return
 if not controls_enabled or get_tree().paused or not application_focused or time_presentation.finish_remaining > 0.0: return
 if ending.active(): return
 if event is InputEventJoypadButton or event is InputEventJoypadMotion: using_controller = true
 elif event is InputEventKey or event is InputEventMouseButton: using_controller = false
 var key: int = event.physical_keycode if event is InputEventKey and event.pressed and not event.echo else 0
 var button: int = event.button_index if event is InputEventJoypadButton and event.pressed else -1
 if button == JOY_BUTTON_Y:
  _toggle_diary()
 elif key == KEY_R:
  _begin_reset()
 elif sim.s.finished and (key == KEY_ENTER or button == JOY_BUTTON_A):
  if sim.exploration(): _return_to_menu()
  elif sim.succeeded(): _next_mission()
  else: _begin_reset()
 elif button == JOY_BUTTON_B and diary_open:
  _toggle_diary()
 elif diary_open or rewind_index >= 0: return
 elif key == KEY_H or button == JOY_BUTTON_A:
  highlight = not highlight
 elif key == KEY_ESCAPE or button == JOY_BUTTON_B:
  sim.s.action = {}
  sim.s.code_open = false
  sim.s.hospitality.menu = ""
  sim.s.message = "Action cancelled."
 elif key >= KEY_1 and key <= KEY_8:
  wheel.activate_slot(key-KEY_1)
 elif key == KEY_ENTER and sim.s.code_open:
  _submit_code()
 elif key == KEY_BACKSPACE and sim.s.code_open:
  sim.s.entry = ""
 elif button == JOY_BUTTON_X:
  wheel.confirm_selected()
 elif event is InputEventJoypadMotion:
  var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
  if stick.length() > 0.35 and not choices.is_empty():
   wheel.select_from_vector(stick)
 _refresh()

func _choose(index: int) -> void:
 if stream_resources and not _prepare_visible(_display_state()): return
 if diary_open or rewind_index >= 0 or time_presentation.finish_remaining > 0.0: return
 idle_seconds = 0.0
 if sim.s.code_open:
  if index < 6 and sim.s.entry.length() < 3: sim.s.entry += str(index+1)
  elif index == 6: _submit_code()
  elif index == 7: sim.s.entry = ""
 elif index < choices.size():
  sim.start(choices[index].id)

func _submit_code() -> void:
 sim.submit_code()
 _events()

func _refresh(direction := Vector2.INF) -> void:
 if direction == Vector2.INF:
  direction = _movement_input() if rewind_index < 0 else Vector2.ZERO
 touch_controls.set_context(controls_enabled,diary_open or rewind_index>=0 or sim.s.finished)
 var state: Dictionary = _display_state()
 if cut_fade_phase == "out": return
 if stream_resources and not _prepare_visible(state): return
 _ensure_actor("amelia")
 if shown_room != state.room: _show_room(state.room)
 watch.elapsed_seconds = float(state.tick)/10.0
 heading.text = ("Mission %d  ·  " % sim.mission_number() if sim.exploration() else "All Aboard  ·  ") + str(sim.room_definition(state.room).title)
 message.text = state.message
 notice.text = state.get("notice", "") if int(state.tick) < int(state.get("notice_until",0)) else ""
 room_audio.set_game_time(int(state.tick)*100)
 actors.amelia.position = _display_position(state, "amelia", Rooms.point(state.pos))
 actors.amelia.visible = rewind_index >= 0 or state.room == sim.s.room
 var player_action := "walk" if direction.length_squared()>0.01 and not state.finished else "idle"
 if state.get("tutorial", "done") == "briefing": player_action = "idle"
 if not state.action.is_empty(): player_action = {"hide_bag":"hide_bag", "shove":"shove", "bump":"bump"}.get(state.action.id,"idle")
 actors.amelia.play_action(player_action, state.facing)
 var live := sim.s
 sim.s = state
 var positions: Dictionary = state.get("actors", sim.actor_positions())
 for id in actors:
  if id != "amelia": actors[id].hide()
 for id in positions:
  var info: Dictionary = positions[id]
  if info.room != state.room: continue
  _ensure_actor(id)
  actors[id].visible = true
  actors[id].position = _display_position(state, id, Rooms.point(info.pos))
  actors[id].play_action(info.action, info.get("facing",_actor_facing(id, info)))
  if not ending.state.is_empty() and rewind_index < 0 and info.action == "wave" and actors[id].has_method("present_wave"):
   actors[id].present_wave(ending.elapsed,int(str(id).trim_prefix("sendoff_guest_")))
  if not ending.state.is_empty() and rewind_index < 0 and state.dead.has(id) and not actors[id] is PendingCharacter:
   actors[id].set_frame_and_progress(actors[id].sprite_frames.get_frame_count(actors[id].animation)-1,0.0)
   actors[id].pause()
 choices = sim.options()
 if state.code_open:
  choices = []
  for i in 6: choices.append({"label":str(i+1)})
  choices.append({"label":"Commit"})
  choices.append({"label":"Clear"})
  message.text = ""
 _sync_props(state)
 _sync_authored_props(state)
 _sync_prop_occlusion()
 _sync_highlights()
 sim.s = live
 _refresh_prompt(state)
 progress.visible = not state.action.is_empty()
 if progress.visible: progress.value = 100.0*float(state.action.progress)/float(state.action.duration)
 wheel.visible = not diary_open and rewind_index < 0 and not state.finished and not choices.is_empty()
 var anchor: Vector2 = Vector2(350,280) if state.code_open else Rooms.point(choices[0].pos) if not choices.is_empty() else actors.amelia.position
 wheel.position = Vector2(clampf(anchor.x-wheel.size.x/2,12,1148-wheel.size.x),clampf(anchor.y-wheel.size.y/2,12,650-wheel.size.y))
 var labels := PackedStringArray()
 for i in choices.size(): labels.append(choices[i].label)
 if touch_controls.active:
  wheel.position.y = minf(wheel.position.y,touch_controls.top_edge-20-wheel.size.y)
 wheel.options = labels
 if help.visible and not choices.is_empty():
  help.position = Vector2(clampf(anchor.x-help.size.x/2,12,1148-help.size.x),minf(wheel.position.y+wheel.size.y+8,635))
  if touch_controls.active: help.position.y = minf(help.position.y,touch_controls.top_edge-64)

 world_overlay.queue_redraw()
 if room_slot.get_child_count() > 0 and room_slot.get_child(0).has_method("set_motion_time"):
  room_slot.get_child(0).set_motion_time(float(state.get("frame",state.tick))/10.0)
 hud.visible = not ending.active()
 if room_slot.get_child_count() > 0:
  var docks := room_slot.get_child(0)
  if docks.has_method("set_departure_time"):
   var departure: float = ending.elapsed if not ending.state.is_empty() and rewind_index < 0 and ending.departing else 0.0
   docks.set_motion_time(float(state.get("frame",state.tick))/10.0+departure)
   docks.set_departure_time(departure)
 if state.finished and rewind_index < 0 and ending.done:
  diary_open = true
  if not end_presented:
   diary_seek_end = true
   diary_presentation.set_open(true)
  message.text = ""
  help.hide()
  if not end_presented:
   end_presented = true
   (diary_menu if sim.exploration() else diary_next if sim.succeeded() else diary_reset).call_deferred("grab_focus")
 elif rewind_index >= 0:
  message.text = "The pages turn backwards…  R to skip"
 _refresh_bubble(state)
 if diary_open: _refresh_diary()

func _refresh_bubble(state: Dictionary) -> void:
 var line: Dictionary = state.get("dialogue",{})
 bubble.visible = not line.is_empty() and not diary_open and not state.finished and line.get("room","") == state.room and int(state.get("frame",state.tick)) < int(line.get("until",0))
 if not bubble.visible:
  hint_prompt.hide()
  touch_controls.tutorial_action = ""
  bubble_identity = ""
  return
 var actor: Node2D = actors.get(line.speaker,actors.amelia)
 if not actor.visible:
  bubble.hide()
  hint_prompt.hide()
  touch_controls.tutorial_action = ""
  bubble_identity = ""
  return
 var font: Font = bubble.message_label.get_theme_font("font")
 var font_size: int = bubble.message_label.get_theme_font_size("font_size")
 var text_height := font.get_multiline_string_size(str(line.text),HORIZONTAL_ALIGNMENT_LEFT,298,font_size).y
 bubble.bubble_size = Vector2(350,maxf(154,text_height+94))
 var anchor := actor.position-Vector2(0,52)
 var identity := "%s:%s:%s:%s" % [line.room,line.speaker,line.started,line.text]
 if identity != bubble_identity:
  bubble.position = Vector2(clampf(anchor.x-bubble.size.x/2,12,1150-bubble.size.x),clampf(anchor.y-bubble.size.y,12,590-bubble.size.y))
  _place_bubble(anchor)
  bubble_offset = bubble.position-actor.position
  bubble_identity = identity
 else:
  bubble.position = actor.position+bubble_offset
 var player_rect := Rect2(actors.amelia.position-Vector2(20,55),Vector2(40,60)).grow(6)
 bubble.background_opacity = 0.5 if Rect2(bubble.position,bubble.size).intersects(player_rect) else 1.0
 bubble.point_tail_at(anchor-bubble.position)
 var fraction := accumulator if controls_enabled and rewind_index < 0 and not diary_open else 0.0
 bubble.present(line,maxf(0,(float(state.get("frame",state.tick))-float(line.started))/10.0+fraction))
 var hint: String = line.get("hint","")
 touch_controls.tutorial_action = hint
 hint_prompt.visible = not hint.is_empty()
 hint_prompt.text = Simulation.Hints.prompt(hint,using_controller,touch_controls.active)
 hint_prompt.position = Vector2(bubble.position.x,clampf(bubble.position.y+bubble.size.y,12,680))
 # Dialogue belongs to the character; keep the status strip for controls/results.
 if not state.code_open: message.text = ""

func _refresh_prompt(state: Dictionary) -> void:
 var visible_now: bool = not diary_open and rewind_index < 0 and not state.finished
 var phase: String = state.get("tutorial","done")
 help.visible = visible_now
 if state.finished and not diary_open:
  help.visible = true
 help.position = Vector2(clampf(actors.amelia.position.x-160,12,828),minf(actors.amelia.position.y+18,635))
 help.size = Vector2(320,60)
 if phase == "approach" and choices.is_empty(): help.position.y = minf(help.position.y,580)
 if state.finished:
  help.position = Vector2(25,696)
  help.size = Vector2(1110,36)
 movement_prompt.visible = visible_now and phase == "approach" and choices.is_empty()
 movement_prompt.position = help.position+Vector2(111,0)
 movement_prompt.controller = using_controller
 if phase == "approach":
  help.text = "Nearby actions: right stick to choose, X to report for duty" if using_controller else "Nearby actions appear here.\nClick the action or press 1: Report for duty"
  if choices.is_empty():
   help.position.y += 60
   help.text = "Report to the captain for duty."
 elif phase == "briefing": help.text = ""
 else: help.text = ("Right stick + X: interact" if using_controller else "Click an action or press its number") if not choices.is_empty() else ""
 if int(sim.memory.get("interactions",0)) >= 3: help.hide()
 var drink: String = state.get("hospitality",{}).get("carried","")
 carrying.visible = visible_now and drink != ""
 carrying.text = "Carrying: "+Simulation.Hospitality.DRINKS.get(drink,"")
 if touch_controls.active:
  movement_prompt.hide()
  help.text = "Use the left stick to reach the captain." if phase == "approach" and choices.is_empty() else "Tap an action to interact." if not choices.is_empty() else ""
  if state.finished: help.text = "Open Diary to read your notes or turn back the pages."
  carrying.position.y = touch_controls.top_edge-52
  message.position = Vector2(220,touch_controls.top_edge-28)
  if help.position.y > touch_controls.top_edge-64: help.position.y = touch_controls.top_edge-64


# Interpolate adjacent recorded ticks at a fixed rate, never chase the target
# with lerp(delta), which produces visible acceleration and deceleration.
func _display_position(state: Dictionary, id: String, current: Vector2) -> Vector2:
 if state.finished or rewind_index >= 0 or diary_open or not controls_enabled or sim.history.size() < 2: return current
 var previous: Dictionary = sim.history[-2]
 if previous.room != state.room: return current
 var old: Vector2
 if id == "amelia": old = Rooms.point(previous.pos)
 else:
  var before: Dictionary = previous.get("actors", {}).get(id, {})
  if before.is_empty() or before.room != state.actors[id].room: return current
  old = Rooms.point(before.pos)
 if old.distance_to(current) > 50: return current
 return old.lerp(current, clampf(accumulator / 0.1, 0, 1))

func _actor_facing(id: String, info: Dictionary) -> String:
 if info.action != "walk" or sim.history.size() < 2:
  if info.room == "docks" and info.action == "talk": return "left" if id == "dock_sailor" else "right"
  return "down"
 var before: Dictionary = sim.history[-2].get("actors", {}).get(id, {})
 if before.is_empty() or before.room != info.room: return "down"
 var delta := Rooms.point(info.pos) - Rooms.point(before.pos)
 if absf(delta.x) > absf(delta.y): return "right" if delta.x > 0 else "left"
 return "down" if delta.y >= 0 else "up"

func _draw_world_markers() -> void:
 if not controls_enabled: return
 if sim.s.finished and rewind_index < 0: return
 var state: Dictionary = sim.history[rewind_index] if rewind_index >= 0 else sim.s
 var prior := Rooms.authored
 var prior_connections := Rooms.authored_connections
 Rooms.authored = sim.authored_content.get("rooms",{})
 Rooms.authored_connections = sim.authored_content.get("connections",[])
 var exits := Rooms.exits(state.room,state.flags.get("shortcut",false))
 Rooms.authored = prior
 Rooms.authored_connections = prior_connections
 for door in exits:
  world_overlay.draw_rect(door.bounds,Color(0.83,0.71,0.44,0.35 if highlight else 0.13))
  world_overlay.draw_rect(door.bounds,Color(0.83,0.71,0.44,0.85 if highlight else 0.4),false,1)
 for door in Rooms.locked_doors(state.room,sim.exploration(),sim.mission_number() == 2):
  world_overlay.draw_rect(door.bounds,Color(0.75,0.5,0.3,0.7 if highlight else 0.3),false,1)
 if highlight and rewind_index < 0 and not diary_open:
  for option in sim.options(false):
   if not _highlight_entity(option.get("target","")):
    world_overlay.draw_circle(Rooms.point(option.pos),12,Color("f8d87390"))

func _display_state() -> Dictionary:
 if sim.exploration() and sim.s.finished:
  ending.done = true
  return sim.s
 if rewind_index >= 0: return sim.history[rewind_index]
 if sim.s.finished:
  if ending.state.is_empty():
   diary_open = false
   diary_presentation.clear()
   touch_controls.release_all()
   ending.start(sim.s)
   if ending.state.room != sim.s.room and not shown_room.is_empty():
    cut_fade_phase = "out"
    cut_fade_elapsed = 0.0
    cut_fade.modulate.a = 0.0
    cut_fade.show()
    ending.hide()
   _persist()
  if cut_fade_phase == "out": return sim.s
  return ending.state
 if not ending.state.is_empty():
  ending.clear()
  end_presented = false
 return sim.s

func _advance_cut_fade(delta: float) -> void:
 cut_fade_elapsed = minf(CUT_FADE_SECONDS,cut_fade_elapsed+delta)
 var amount := cut_fade_elapsed/CUT_FADE_SECONDS
 cut_fade.modulate.a = amount if cut_fade_phase == "out" else 1.0-amount
 if cut_fade_elapsed < CUT_FADE_SECONDS: return
 if cut_fade_phase == "out":
  # Swap the room only under full black; hold the cutscene clock until revealed.
  cut_fade_phase = "in"
  cut_fade_elapsed = 0.0
  ending.show()
  _refresh()
 else:
  cut_fade_phase = ""
  cut_fade.hide()

func _refresh_character_art() -> void:
 if not character_ticket.is_empty() and not str(character_ticket.error).is_empty():
  if _character_retry_at == 0: _character_retry_at = Time.get_ticks_msec()+5000
  elif Time.get_ticks_msec() >= _character_retry_at:
   character_ticket = get_node("/root/ResourceStream").request_resources(ContentPlan.level_characters(),false,2)
   _character_retry_at = 0
 var changed := false
 for id in actors.keys():
  if actors[id] is PendingCharacter:
   _ensure_actor(id)
   if not actors[id] is PendingCharacter: changed = true
 if changed: _refresh()

func _ensure_actor(id: String) -> void:
 var skin: String = preload("res://mission1/authoring_content.gd").resolve(sim.authored_content,id).get("appearance",ContentPlan.skin_for(id))
 if actors.has(id) and not actors[id] is PendingCharacter: return
 if stream_resources:
  var cache: Dictionary = get_node("/root/ResourceStream").resources
  if not ContentPlan.character_paths(id,skin).all(func(path): return cache.has(path)):
   if character_ticket.is_empty() or character_ticket.get("done",false): character_ticket = get_node("/root/ResourceStream").request_resources(ContentPlan.character_paths(id,skin))
   if not actors.has(id):
    var pending := PendingCharacter.new()
    pending.self_modulate.a = 0.0
    entity_layer.add_child(pending)
    actors[id] = pending
   return
 if actors.has(id):
  entity_layer.remove_child(actors[id])
  actors[id].queue_free()
  actors.erase(id)
 var actor: AnimatedSprite2D
 if skin == "captain":
  actor = AnimatedSprite2D.new()
  actor.set_script(preload("res://assets/characters/captain.gd"))
 elif skin in ["player","rake","glamorous","matron","ex_army"]:
  actor = Character.instantiate()
  actor.character_id = skin
 else:
  actor = preload("res://assets/characters/generic/generic_animated_character.tscn").instantiate()
  actor.character_id = skin
 entity_layer.add_child(actor)
 actors[id] = actor

func _prepare_visible(state: Dictionary) -> bool:
 var key := str(state.room)
 var stream := get_node("/root/ResourceStream")
 if key != _content_key:
  _content_key = key
  if not _content_ticket.is_empty(): _content_ticket.cancelled = true
  _content_ticket = stream.request_resources(ContentPlan.for_state(state,sim.authored_content),true)
 if not _content_ticket.done or not str(_content_ticket.error).is_empty():
  if not is_instance_valid(_content_overlay):
   _content_overlay = CanvasLayer.new()
   _content_overlay.layer = 100
   add_child(_content_overlay)
   _content_diary = LoadingDiary.new()
   _content_overlay.add_child(_content_diary)
   _content_error = Label.new()
   _content_error.position = Vector2(200,555)
   _content_error.size = Vector2(760,65)
   _content_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
   _content_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   _content_diary.add_child(_content_error)
   var retry := Button.new()
   retry.text = "Retry"
   retry.position = Vector2(470,700)
   retry.pressed.connect(func(): _content_key = "")
   _content_diary.add_child(retry)
   var back := Button.new()
   back.text = "Main menu"
   back.position = Vector2(585,700)
   back.pressed.connect(_return_to_menu)
   _content_diary.add_child(back)
   var navigator := preload("res://foundation/controller_menu.gd").new()
   navigator.available = func(): return [retry,back]
   navigator.enabled = func(): return not str(_content_ticket.error).is_empty() and not get_tree().paused
   navigator.back = _return_to_menu
   _content_diary.add_child(navigator)
   _content_failure_shown = false
  _content_diary.progress = _content_ticket.progress
  _content_error.text = _content_ticket.error
  for button in _content_diary.get_children():
   if button is Button:
    button.visible = not str(_content_ticket.error).is_empty()
    if button.visible and not _content_failure_shown:
     button.grab_focus()
     _content_failure_shown = true
  touch_controls.release_all()
  return false
 if is_instance_valid(_content_overlay):
  _content_overlay.queue_free()
  _content_overlay = null
  # Refresh immediately after the wait, even with the diary open or rewinding.
  _refresh.call_deferred()
 if _prefetched_room != str(state.room):
  _prefetched_room = str(state.room)
  if not _neighbour_ticket.is_empty(): _neighbour_ticket.cancelled = true
  _neighbour_ticket = stream.request_resources(ContentPlan.neighbours(_prefetched_room,sim.authored_content))
 return true

func _show_room(id: String) -> void:
 for child in room_slot.get_children():
  room_slot.remove_child(child)
  child.queue_free()
 for prop in props.values():
  entity_layer.remove_child(prop)
  prop.queue_free()
 props.clear()
 var definition := sim.room_definition(id)
 var room: Node2D
 if not str(definition.get("background_asset", "")).is_empty() or str(definition.get("scene", "")).is_empty():
  room = Node2D.new()
  var picture := Sprite2D.new()
  picture.centered = false
  var asset: Dictionary = sim.authored_content.get("assets",{}).get(definition.get("background_asset", ""),{})
  if not asset.is_empty(): picture.texture = preload("res://foundation/project_assets.gd").texture(asset)
  if picture.texture != null: picture.scale = Vector2(definition.size[0],definition.size[1]) / picture.texture.get_size()
  room.add_child(picture)
 else:
  room = load(("res://assets/rooms/mission_1/%s.tscn" % definition.scene).simplify_path()).instantiate() as Node2D
 room_slot.add_child(room)
 if room.has_method("set_motion_time"): room.animate_bobbing = false
 if room.has_node("RoomAudioSettings"): room_audio.set_room(room.get_node("RoomAudioSettings"), int(sim.s.tick)*100, opening_audio_fade)
 opening_audio_fade = 1.0
 shown_room = id
 match ("" if sim.exploration() else id):
  "docks":
   _prop("suitcase", Rooms.LUGGAGE)
   _prop("bag_hiding", Vector2(210,335))
  "foyer":
   _prop("chandelier", Rooms.CHANDELIER_FLOOR)
  "controls":
   _prop("code_panel", Vector2(350,280))
   var digits := Label.new()
   digits.name = "Digits"
   digits.position = Vector2(-23,-47)
   digits.size = Vector2(46,15)
   digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
   digits.add_theme_font_size_override("font_size",11)
   digits.add_theme_color_override("font_color",Color("ffe8a3"))
   digits.mouse_filter = Control.MOUSE_FILTER_IGNORE
   props.code_panel.add_child(digits)
   _prop("steam_vent", Vector2(940,290))
   var smoke := preload("res://assets/effects/mission_1/room_steam.gd").new()
   smoke.z_index = 8
   entity_layer.add_child(smoke)
   props.room_steam = smoke
  "salon":
   _prop("drink", Rooms.BAR_GLASS)
   props.drink.scale = Vector2(0.38,0.38)
   props.drink.z_index = 2
   # Reuse the existing pillar pixels as a foreground mask for the hidden arm.
   var pillar := Sprite2D.new()
   pillar.texture = load("res://assets/rooms/mission_1/05_party_salon.png")
   pillar.centered = false
   pillar.region_enabled = true
   pillar.region_rect = Rect2(935,0,50,133)
   pillar.position = Vector2(935,0)
   pillar.z_index = 3
   entity_layer.add_child(pillar)
   props.bar_pillar = pillar
  "cabins":
   for door_id in Rooms.CABIN_DOORS:
    _prop("cabin_door", Vector2(Rooms.CABIN_DOORS[door_id],427), door_id)

 for key in props.keys():
  var authored := preload("res://mission1/authoring_content.gd").resolve(sim.authored_content,key)
  if not authored.is_empty() and authored.room != id:
   entity_layer.remove_child(props[key])
   props[key].queue_free()
   props.erase(key)
 for entity_id in sim.authored_content.get("instances",{}):
  var entity := preload("res://mission1/authoring_content.gd").resolve(sim.authored_content,entity_id)
  if entity.kind != "character" and entity.room == id and not props.has(entity_id):
   _prop(str(entity.appearance),Vector2(entity.position[0],entity.position[1]),entity_id)

func _prop(id: String, p: Vector2, key := "") -> void:
 var instance_key := id if key.is_empty() else key
 var authored := preload("res://mission1/authoring_content.gd").resolve(sim.authored_content,id if key.is_empty() else key)
 if not authored.is_empty():
  p = Vector2(authored.position[0],authored.position[1])
  id = str(authored.get("appearance", id))
 var prop := load("res://assets/props/mission_1/%s.tscn" % id).instantiate() as Node2D
 prop.position = p
 entity_layer.add_child(prop)
 props[instance_key] = prop

func _effect_fraction() -> float:
 return clampf((accumulator+visual_elapsed)/0.1,0.0,0.99) if controls_enabled and rewind_index < 0 and not diary_open and not get_tree().paused and application_focused else 0.0

func _sync_props(state: Dictionary) -> void:
 var effect_fraction := _effect_fraction()
 var world_offset := Vector2.ZERO
 for door_id in Rooms.CABIN_DOORS:
  if props.has(door_id): props[door_id].set_state("open" if state.flags.get(door_id,false) else "closed")
 for door_id in preload("res://mission2/content.gd").CREW_DOORS:
  if props.has(door_id): props[door_id].set_state("open" if state.flags.get(door_id,false) else "closed")
 if props.has("drink"):
  props.drink.visible = state.flags.get("party_arrived",false)
  props.drink.show_at(state,effect_fraction)
 var stained: bool = state.flags.get("spilled", false)
 if actors.has("guest") and actors.guest.stained_outfit != stained: actors.guest.set_outfit_stained(stained)
 if props.has("code_panel") and props.code_panel.has_node("Digits"):
  props.code_panel.get_node("Digits").text = " ".join(str(state.entry).rpad(3,"_").split("")) if state.code_open else ""
 if props.has("steam_vent"):
  var active := Rooms.steam_blocked(state.flags)
  props.steam_vent.set_state("active" if active else "off")
  var plume: AnimatedSprite2D = props.steam_vent.get_node("SteamPlume")
  plume.pause()
  plume.frame = int(state.get("frame",state.tick)/2) % 4
  var shutdown_age := -1.0
  if state.flags.get("steam_off",false) and state.flags.get("steam_shutdown_visible",false) and state.flags.has("steam_shutdown_frame"):
   shutdown_age = (float(state.get("frame",state.tick))+effect_fraction-float(state.flags.steam_shutdown_frame))/10.0
  props.room_steam.show_at((float(state.get("frame",state.tick))+effect_fraction)/10.0,active,shutdown_age)
  props.code_panel.set_state("rejected" if state.flags.get("panel_rejected",false) else "entry" if state.code_open else "rejected" if state.flags.get("steam_off",false) else "accepted")
 if props.has("chandelier"):
  var fraction := effect_fraction
  var tick := float(state.tick)+fraction
  var frame := float(state.get("frame",state.tick))+fraction
  var drop := (tick-float(state.flags.chandelier_drop_tick))/8.0 if state.flags.has("chandelier_drop_tick") else -1.0
  if state.flags.has("chandelier_drop_frame"): drop = (frame-float(state.flags.chandelier_drop_frame))/Simulation.DROP_FRAMES
  var impact := (tick-float(state.flags.get("chandelier_impact_tick",Simulation.FALL)))/10.0 if state.flags.get("chandelier_fallen",false) else -1.0
  if state.flags.has("chandelier_impact_frame"): impact = (frame-float(state.flags.chandelier_impact_frame))/10.0
  if sim.exploration():
   drop = 1.0
   impact = 10.0
  props.chandelier.show_at(state.flags.get("chandelier_warning",false),drop,impact,frame/10.0)
  world_offset = preload("res://assets/effects/mission_1/physical_accents.gd").impact_offset(impact)
 if props.has("janitor"):
  props.janitor.show_at((float(state.get("frame",state.tick))+effect_fraction)/10.0)
 if props.has("suitcase"):
  props.suitcase.visible = not state.flags.get("bag_found",false)
  props.suitcase.set_state("hidden" if state.flags.get("bag_hidden",false) else "present")
  props.bag_hiding.set_state("occupied" if state.flags.get("bag_hidden",false) else "empty")

 room_slot.position = world_offset
 entity_layer.position = world_offset
 world_overlay.position = world_offset

func _events() -> void:
 for event in sim.events:
  if event.kind == "sound":
   sounds.play_cue(StringName(event.text))
   if event.text == "hour_chime" and rewind_index < 0:
    time_presentation.announce_hour(1+int(sim.s.tick/Simulation.HOUR))


func _toggle_diary() -> void:
 if sim.s.finished or rewind_index >= 0 or time_presentation.finish_remaining > 0.0: return
 idle_seconds = 0.0
 diary_open = true
 waiting_active = false
 if not diary_presentation.wanted: diary_seek_end = true
 diary_presentation.set_open(not diary_presentation.wanted)
 accumulator = 0.0
 _refresh()
 if diary_presentation.wanted: diary_close.call_deferred("grab_focus")
 _persist()

func _next_mission() -> void:
 get_tree().set_meta("open_mission3" if sim.mission_number() == 2 else "open_mission2",true)
 _return_to_menu()

func _return_to_menu() -> void:
 _persist()
 get_node("/root/AudioSettings").return_to_main_menu()

func _refresh_diary() -> void:
 var ended: bool = sim.s.finished
 var victory: bool = ended and sim.succeeded()
 var text := "\n\n".join(sim.memory.notes)
 var outcome := "5:30 · The unmooring party is over.\n\n"+sim.summary().replace(" · ","\n") if ended else ""
 if ended and sim.exploration(): outcome = "7:00 · Six hours %s.\n\nEnd of the exploration schedule." % ("in Greece" if sim.mission_number() == 3 else "aboard")
 if text+outcome != diary_cached_text or diary_pages.pages.is_empty():
  diary_cached_text = text+outcome
  diary_pages.rebuild(text,diary_text.get_theme_font("normal_font"),18,334,340,outcome)
 if diary_seek_end:
  diary_pages.spread = diary_pages.last_spread()
  diary_seek_end = false
 var final_page: bool = diary_pages.spread == diary_pages.last_spread()
 diary_title.text = "VOYAGE COMPLETE" if victory and final_page else "VOYAGE ENDED" if ended and final_page else "VOYAGE NOTEBOOK"
 diary_page_title.text = ("THE NEXT PAGE" if victory else "THE VOYAGE") if final_page else "THE VOYAGE"
 diary_text.text = diary_pages.left_text()
 diary_right_text.text = diary_pages.right_text()
 diary_right_text.visible = not final_page
 diary_instructions.visible = final_page and victory
 diary_space.visible = final_page
 diary_instructions.text = "Everyone survived. Now I can turn to the next page." if victory else ""
 diary_close.visible = not ended
 var reset_parent: Node = diary_text.get_parent() if diary_pages.spread == 0 else diary_right_text.get_parent()
 if diary_reset.get_parent() != reset_parent: diary_reset.reparent(reset_parent)
 reset_parent.move_child(diary_reset,1 if diary_pages.spread == 0 else 4)
 diary_reset.visible = (diary_pages.spread == 0 or final_page) and not victory
 diary_reset.disabled = not sim.memory.reset and not ended
 diary_next.visible = final_page and victory and not sim.exploration()
 if sim.exploration():
  diary_reset.hide()
  diary_instructions.hide()
  if ended: diary_title.text = "SCHEDULE COMPLETE"
  diary_next.visible = final_page and ended and sim.mission_number() == 2
 diary_menu.visible = final_page and ended
 diary_previous_page.disabled = diary_pages.spread == 0
 diary_following_page.disabled = final_page
 diary_page_numbers.text = "%d–%d / %d    ·    Left / Right · LB / RB" % [diary_pages.spread*2+1,diary_pages.spread*2+2,diary_pages.pages.size()+1]

func _turn_diary(direction: int) -> void:
 if not diary_open or not diary_presentation.wanted: return
 var old_spread: int = diary_pages.spread
 diary_pages.turn(direction)
 if old_spread != diary_pages.spread: diary_presentation.turn_page(direction)
 _refresh_diary()
 var focus := get_viewport().gui_get_focus_owner()
 if focus is BaseButton and (not focus.is_visible_in_tree() or focus.disabled):
  (diary_previous_page if not diary_previous_page.disabled else diary_following_page if not diary_following_page.disabled else diary_close if diary_close.visible else diary_next if diary_next.visible else diary_reset).grab_focus()

func _summary() -> String:
 return sim.summary()
func _begin_reset() -> void:
 if sim.exploration(): return
 if ending.active(): return
 if time_presentation.finish_remaining > 0.0: return
 if not sim.memory.reset and not sim.s.finished:
  sim.s.message = "The diary has no earlier pages to turn to yet."
  return
 if rewind_index >= 0:
  _finish_reset()
  return
 diary_open = false
 ending.clear()
 diary_presentation.clear()
 time_presentation.clear_announcements()
 rewind_accumulator = 0.0
 rewind_start = sim.history.size()-1
 rewind_index = rewind_start
 _refresh()
func _rewind(delta: float) -> void:
 rewind_accumulator += delta
 rewind_index = maxi(0,rewind_start-int(float(rewind_start)*rewind_accumulator/2.5))
 _refresh()
 if rewind_index == 0: _finish_reset()
func _finish_reset() -> void:
 rewind_index = -1
 time_presentation.rewinding = false
 time_presentation.clear_announcements()
 time_presentation.finish_remaining = 0.15
 waiting_active = false
 if not pending_authoring_restart.is_empty():
  sim.authored_content = pending_authoring_restart.duplicate(true)
  sim.content_versions[sim.authored_content.version] = sim.authored_content.duplicate(true)
  pending_authoring_restart = {}
  shown_room = ""
  _content_key = ""
 sim.reset()
 ending.clear()
 end_presented = false
 accumulator = 0.0
 help.text = ""
 _refresh()
 _persist()
func save_before_leaving() -> bool:
 if not save_enabled: return true
 var result := journal.save_run(sim,save_path)
 if not result.ok:
  message.text = result.reason
  return false
 return true

func _persist() -> void:
 if not save_enabled: return
 var result := journal.save_run(sim, save_path)
 if not result.ok:
  message.text = result.reason
  push_warning(result.reason)
func _restore_initial() -> void:
 idle_seconds = 0.0
 if initial.is_empty(): return
 journal.restore_run(sim, initial)

func _exit_tree() -> void:
 if not character_ticket.is_empty(): character_ticket.cancelled = true
 if not _content_ticket.is_empty(): _content_ticket.cancelled = true
 if not _neighbour_ticket.is_empty(): _neighbour_ticket.cancelled = true
 _persist()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  application_focused = false
  idle_seconds = 0.0
  if is_node_ready(): _persist()
 elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
  application_focused = true
  idle_seconds = 0.0

func _input(event: InputEvent) -> void:
 if stream_resources and not _content_ticket.is_empty() and (not _content_ticket.done or not str(_content_ticket.error).is_empty()): return
 # Handle Tab before focused controls consume it as focus navigation.
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
  if controls_enabled and not get_tree().paused and application_focused and time_presentation.finish_remaining <= 0.0:
   using_controller = false
   _toggle_diary()
   get_viewport().set_input_as_handled()
   return
 if diary_open and not get_tree().paused and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_LEFT,KEY_PAGEUP,KEY_RIGHT,KEY_PAGEDOWN]:
  _turn_diary(-1 if event.physical_keycode in [KEY_LEFT,KEY_PAGEUP] else 1)
  get_viewport().set_input_as_handled()
  return
 if event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed or event is InputEventJoypadButton and event.pressed:
  idle_seconds = 0.0
 elif event is InputEventJoypadMotion and absf(event.axis_value)>0.2:
  idle_seconds = 0.0

func _update_idle_hint(delta: float) -> void:
 var eligible: bool = controls_enabled and application_focused and not get_tree().paused and not diary_open and rewind_index<0 and not sim.s.finished and not sim.tutorial_active() and sim.s.dialogue.is_empty() and sim.s.get("conversation",{}).is_empty() and sim.s.action.is_empty() and not sim.s.code_open and sim.s.hospitality.menu == ""
 var active_input: bool = _movement_input().length_squared()>0.01 or Input.is_physical_key_pressed(KEY_F) or Input.is_joy_button_pressed(0,JOY_BUTTON_B) or touch_controls.wait_held
 if not eligible or active_input:
  idle_seconds = 0.0
  return
 idle_seconds += delta
 if idle_seconds >= 10.0:
  Simulation.Hints.queue(sim,"wait")
  idle_seconds = 0.0

func _highlight_entity(id: String) -> bool:
 var entity: Node = actors.get(id,props.get(id,null))
 return entity != null and (entity is Sprite2D or entity is AnimatedSprite2D) and entity.visible

func _sync_highlights() -> void:
 var targets := {}
 if highlight and not diary_open and rewind_index<0:
  for option in sim.options(false): targets[option.get("target","")] = true
 for collection in [actors,props]:
  for id in collection:
   var entity: Node = collection[id]
   if entity is PendingCharacter: continue
   if not (entity is Sprite2D or entity is AnimatedSprite2D): continue
   if entity.material == null:
    entity.material = ShaderMaterial.new()
    entity.material.shader = preload("res://assets/ui/mission_1/entity_outline.gdshader")
   if not entity.material is ShaderMaterial: continue
   entity.material.set_shader_parameter("interaction_outline",targets.has(id))
   if entity is Sprite2D:
    entity.material.set_shader_parameter("frame_origin",entity.region_rect.position if entity.region_enabled else Vector2.ZERO)
    entity.material.set_shader_parameter("outline_frame_size",entity.region_rect.size if entity.region_enabled else entity.texture.get_size())

func _place_bubble(anchor: Vector2) -> void:
 var player_rect := Rect2(actors.amelia.position-Vector2(20,55),Vector2(40,60)).grow(6)
 var candidates := [bubble.position,anchor+Vector2(35,-bubble.size.y/2),anchor-Vector2(bubble.size.x+35,bubble.size.y/2),anchor+Vector2(-bubble.size.x/2,35)]
 var chosen: Vector2 = bubble.position
 var score := INF
 for candidate in candidates:
  var p := Vector2(clampf(candidate.x,12,1148-bubble.size.x),clampf(candidate.y,12,680-bubble.size.y))
  var rect := Rect2(p,bubble.size)
  var overlap := rect.intersection(player_rect)
  var cost := overlap.get_area()*100.0+p.distance_to(bubble.position)
  if wheel.visible: cost += rect.intersection(Rect2(wheel.position,wheel.size)).get_area()*5.0
  if touch_controls.active and rect.end.y > touch_controls.top_edge: cost += (rect.end.y-touch_controls.top_edge)*350
  if cost < score: score = cost; chosen = p
 bubble.position = chosen
 bubble.tail_position = clampf((anchor.x-chosen.x)/bubble.size.x,0.15,0.85)
 bubble.background_opacity = 0.5 if Rect2(chosen,bubble.size).intersects(player_rect) else 1.0

func _sync_prop_occlusion() -> void:
 for prop in props.values():
  if not prop is Sprite2D or not prop.visible or prop.texture == null: continue
  var bounds: Rect2 = prop.get_rect()
  if bounds.size.y*prop.scale.y < 80: continue
  var obscures := false
  for actor in actors.values():
   if actor is PendingCharacter: continue
   if not actor.visible: continue
   if prop.z_index < actor.z_index or (prop.z_index == actor.z_index and prop.position.y < actor.position.y): continue
   var character_bounds := Rect2(actor.position-Vector2(12,46),Vector2(24,44))
   var overlap: Rect2 = (prop.transform*bounds).intersection(character_bounds)
   if not overlap.has_area(): continue
   var texture_id: int = prop.texture.get_instance_id()
   if not prop_images.has(texture_id): prop_images[texture_id] = prop.texture.get_image()
   var pixels: Image = prop_images[texture_id]
   var region: Vector2 = prop.region_rect.position if prop.region_enabled else Vector2.ZERO
   for y in range(int(overlap.position.y),int(overlap.end.y)+1,4):
    for x in range(int(overlap.position.x),int(overlap.end.x)+1,4):
     var local: Vector2 = prop.transform.affine_inverse()*Vector2(x,y)
     var uv: Vector2 = local-bounds.position+region
     if uv.x>=0 and uv.y>=0 and uv.x<pixels.get_width() and uv.y<pixels.get_height() and pixels.get_pixel(int(uv.x),int(uv.y)).a>0.2:
      obscures = true
      break
    if obscures: break
   if obscures: break
  prop.self_modulate.a = 0.5 if obscures else 1.0

func toggle_pause_editor() -> void:
 if authoring_editor == null:
  authoring_editor = preload("res://mission1/authoring_editor.gd").new()
  authoring_editor.game = self
  add_child(authoring_editor)
 authoring_editor.toggle()

func _sync_authored_props(state: Dictionary) -> void:
 for id in state.get("prop_states",{}):
  if not props.has(id): continue
  var entity := preload("res://mission1/authoring_content.gd").resolve(sim.authored_content,id)
  var definition: Dictionary = entity.get("states",{}).get(state.prop_states[id],{})
  props[id].visible = definition.get("visible",true)
  if props[id].has_method("set_state"): props[id].set_state(str(definition.get("appearance",state.prop_states[id])))
