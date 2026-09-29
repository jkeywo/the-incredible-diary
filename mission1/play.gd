extends Node2D
## Mission 1 presentation; all consequential state lives in the deterministic simulation.
const TouchControls = preload("res://assets/ui/mission_1/touch_controls.gd")
const Simulation = preload("res://mission1/simulation.gd")
const Rooms = preload("res://mission1/rooms.gd")
const Watch = preload("res://mission1/pocket_watch.gd")
const Character = preload("res://assets/characters/character_sprite.tscn")
const RoomAudio = preload("res://mission1/room_audio.gd")
const EventAudio = preload("res://mission1/event_audio.gd")
const Save = preload("res://mission1/save.gd")
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
var wait_latched := false
var initial: Dictionary = {}
var diary: Control
var diary_text: RichTextLabel
var diary_open := false
var _save_counter := 0
var rewind_index := -1
var rewind_accumulator := 0.0
var _footstep := 0.0

func configure(saved: Dictionary = {}, enable_save := true) -> void:
 initial = saved.duplicate(true)
 save_enabled = enable_save

func _ready() -> void:
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
 for id in ["amelia", "guest", "chandelier_guest", "chatterbox", "crew", "porter", "dock_sailor"]:
  var actor := preload("res://assets/characters/mission_1/sailor.tscn").instantiate() if id in ["crew", "dock_sailor"] else Character.instantiate()
  actor.character_id = {"amelia":"player", "guest":"rake", "chandelier_guest":"glamorous", "chatterbox":"matron", "crew":"sailor", "porter":"ex_army", "dock_sailor":"sailor"}[id]
  entity_layer.add_child(actor)
  actors[id] = actor
 var captain := AnimatedSprite2D.new()
 captain.set_script(preload("res://assets/characters/captain.gd"))
 entity_layer.add_child(captain)
 actors.captain = captain
 world_overlay = Node2D.new()
 world_overlay.z_index = 10
 add_child(world_overlay)
 world_overlay.draw.connect(_draw_world_markers)
 _build_hud()
 _restore_initial()
 _refresh()
 if get_tree().current_scene == self: enable_controls()

func enable_controls() -> void:
 controls_enabled = true

func _build_hud() -> void:
 var layer := CanvasLayer.new()
 layer.layer = 5
 add_child(layer)
 hud = Control.new()
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 layer.add_child(hud)
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
 hud.add_child(diary)
 var column := VBoxContainer.new()
 diary.get_node("LeftPageContent").add_child(column)
 column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 column.offset_left = 35
 column.offset_right = -15
 column.add_theme_constant_override("separation", 18)
 var title := Label.new()
 title.text = "VOYAGE NOTEBOOK"
 title.add_theme_color_override("font_color", Color("342f29"))
 title.add_theme_font_size_override("font_size", 24)
 column.add_child(title)
 diary_text = RichTextLabel.new()
 diary_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
 diary_text.add_theme_color_override("default_color", Color("342f29"))
 diary_text.add_theme_font_size_override("normal_font_size", 18)
 column.add_child(diary_text)
 var right_page := VBoxContainer.new()
 diary.get_node("RightPageContent").add_child(right_page)
 right_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 right_page.offset_left = 20
 right_page.offset_right = -10
 right_page.add_theme_constant_override("separation", 18)
 var page_title := Label.new()
 page_title.text = "THE VOYAGE"
 page_title.add_theme_color_override("font_color", Color("342f29"))
 page_title.add_theme_font_size_override("font_size", 24)
 right_page.add_child(page_title)
 var instructions := Label.new()
 instructions.text = "Observations from the current voyage, recorded as they happen."
 instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 instructions.add_theme_color_override("font_color", Color("342f29"))
 instructions.add_theme_font_size_override("font_size", 18)
 right_page.add_child(instructions)
 var space := Control.new()
 space.size_flags_vertical = Control.SIZE_EXPAND_FILL
 right_page.add_child(space)
 right_page.theme = preload("res://assets/ui/popup/popup_skin.gd").make_theme()
 var close := Button.new()
 close.text = "Close diary (Tab / Y)"
 close.pressed.connect(_toggle_diary)
 right_page.add_child(close)
 var reset := Button.new()
 reset.text = "Turn back the pages (R / Back)"
 reset.pressed.connect(_begin_reset)
 right_page.add_child(reset)
 diary.hide()
 touch_controls = TouchControls.new()
 hud.add_child(touch_controls)
 touch_controls.action_pressed.connect(_touch_action)

func _touch_action(action: String) -> void:
 if not controls_enabled or get_tree().paused: return
 match action:
  "diary": _toggle_diary()
  "rewind": _begin_reset()
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

func _physics_process(delta: float) -> void:
 if not controls_enabled or get_tree().paused: return
 if rewind_index >= 0:
  _rewind(delta)
  return
 if diary_open or sim.s.finished: return
 var held: bool = Input.is_physical_key_pressed(KEY_F) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5 or touch_controls.wait_held
 if not held: wait_latched = false
 var waiting := held and not wait_latched and not sim.tutorial_active()
 accumulator += delta * (20.0 if waiting else 1.0)
 var direction := _movement_input() if not waiting else Vector2.ZERO
 while accumulator >= 0.1:
  accumulator -= 0.1
  sim.step(direction)
  _events()
  _save_counter += 1
  if waiting and sim.s.tick % Simulation.HOUR == 0:
   wait_latched = true
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
 if not controls_enabled or get_tree().paused: return
 if event is InputEventJoypadButton or event is InputEventJoypadMotion: using_controller = true
 elif event is InputEventKey or event is InputEventMouseButton: using_controller = false
 var key: int = event.physical_keycode if event is InputEventKey and event.pressed and not event.echo else 0
 var button: int = event.button_index if event is InputEventJoypadButton and event.pressed else -1
 if key == KEY_TAB or button == JOY_BUTTON_Y:
  _toggle_diary()
 elif key == KEY_R or button == JOY_BUTTON_BACK:
  _begin_reset()
 elif sim.s.finished and (key == KEY_ENTER or button == JOY_BUTTON_A):
  _begin_reset()
 elif diary_open or rewind_index >= 0: return
 elif key == KEY_H or button == JOY_BUTTON_X:
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
 elif button == JOY_BUTTON_RIGHT_SHOULDER:
  wheel.confirm_selected()
 elif event is InputEventJoypadMotion:
  var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
  if stick.length() > 0.35 and not choices.is_empty():
   wheel.select_from_vector(stick)
 _refresh()

func _choose(index: int) -> void:
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
 var state: Dictionary = sim.history[rewind_index] if rewind_index >= 0 else sim.s
 if shown_room != state.room: _show_room(state.room)
 watch.elapsed_seconds = float(state.tick)/10.0
 heading.text = "All Aboard  ·  " + str(Rooms.ROOMS[state.room].title)
 message.text = state.message
 notice.text = state.get("notice", "") if int(state.tick) < int(state.get("notice_until",0)) else ""
 room_audio.set_game_time(int(state.tick)*100)
 actors.amelia.position = _display_position(state, "amelia", Rooms.point(state.pos))
 var player_action := "walk" if direction.length_squared()>0.01 else "idle"
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
  actors[id].visible = info.room == state.room
  actors[id].position = _display_position(state, id, Rooms.point(info.pos))
  actors[id].play_action(info.action, info.get("facing",_actor_facing(id, info)))
 choices = sim.options()
 if state.code_open:
  choices = []
  for i in 6: choices.append({"label":str(i+1)})
  choices.append({"label":"Commit"})
  choices.append({"label":"Clear"})
  message.text = "CONTROL PANEL   [ %s ]   Enter: commit · Backspace: clear\n%s" % [state.entry, state.message]
 _sync_props(state)
 sim.s = live
 _refresh_prompt(state)
 progress.visible = not state.action.is_empty()
 if progress.visible: progress.value = 100.0*float(state.action.progress)/float(state.action.duration)
 wheel.visible = not diary_open and rewind_index < 0 and not state.finished and not choices.is_empty()
 wheel.position = Vector2(clampf(actors.amelia.position.x-wheel.size.x/2,12,1148-wheel.size.x),clampf(actors.amelia.position.y-140,155,650-wheel.size.y))
 var labels := PackedStringArray()
 for i in choices.size(): labels.append(choices[i].label)
 if touch_controls.active:
  wheel.position.y = minf(wheel.position.y,touch_controls.top_edge-20-wheel.size.y)
 wheel.options = labels

 world_overlay.queue_redraw()
 if room_slot.get_child_count() > 0 and room_slot.get_child(0).has_method("set_motion_time"):
  room_slot.get_child(0).set_motion_time(float(state.get("frame",state.tick))/10.0)
 if state.finished:
  message.text = _summary()
  help.text = "Enter / A: turn back the pages and play again    Tab / Y: read diary"
 elif rewind_index >= 0:
  message.text = "The pages turn backwards…  R / Back to skip"
 _refresh_bubble(state)
 if diary_open: _refresh_diary()

func _refresh_bubble(state: Dictionary) -> void:
 var line: Dictionary = state.get("dialogue",{})
 bubble.visible = not line.is_empty() and not diary_open and not state.finished and line.get("room","") == state.room and int(state.get("frame",state.tick)) < int(line.get("until",0))
 if not bubble.visible: return
 var actor: Node2D = actors.get(line.speaker,actors.amelia)
 if not actor.visible:
  bubble.hide()
  return
 var font: Font = bubble.message_label.get_theme_font("font")
 var font_size: int = bubble.message_label.get_theme_font_size("font_size")
 var text_height := font.get_multiline_string_size(str(line.text),HORIZONTAL_ALIGNMENT_LEFT,298,font_size).y
 bubble.bubble_size = Vector2(350,maxf(154,text_height+94))
 var anchor := actor.position-Vector2(0,52)
 bubble.position = Vector2(clampf(anchor.x-bubble.size.x/2,12,1150-bubble.size.x),clampf(anchor.y-bubble.size.y,12,590-bubble.size.y))
 bubble.tail_position = clampf((anchor.x-bubble.position.x)/bubble.size.x,0.15,0.85)
 var fraction := accumulator if controls_enabled and rewind_index < 0 and not diary_open else 0.0
 bubble.present(line,maxf(0,(float(state.get("frame",state.tick))-float(line.started))/10.0+fraction))
 if wheel.visible and Rect2(wheel.position,wheel.size).intersects(Rect2(bubble.position,bubble.size)):
  wheel.position.y = minf(650-wheel.size.y,bubble.position.y+bubble.size.y+8)
 if touch_controls.active and wheel.visible:
  wheel.position.y = minf(wheel.position.y,touch_controls.top_edge-20-wheel.size.y)
  if Rect2(wheel.position,wheel.size).intersects(Rect2(bubble.position,bubble.size)):
   bubble.position.y = maxf(12,wheel.position.y-bubble.size.y-8)
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
  help.text = "Nearby actions: right stick to choose, RB to report for duty" if using_controller else "Nearby actions appear here.\nPress 1: Report for duty"
  if choices.is_empty():
   help.position.y += 60
   help.text = "Report to the captain for duty."
 elif phase == "briefing": help.text = ""
 else: help.text = ("Right stick + RB: interact" if using_controller else "Number keys: interact") if not choices.is_empty() else ""
 var drink: String = state.get("hospitality",{}).get("carried","")
 carrying.visible = visible_now and drink != ""
 carrying.text = "Carrying: "+Simulation.Hospitality.DRINKS.get(drink,"")
 if touch_controls.active:
  movement_prompt.hide()
  help.text = "Use the left stick to reach the captain." if phase == "approach" and choices.is_empty() else "Tap an action to interact." if not choices.is_empty() else ""
  if state.finished: help.text = "Tap Rewind to play again, or Diary to read your notes."
  carrying.position.y = touch_controls.top_edge-52
  message.position = Vector2(220,touch_controls.top_edge-28)
  if help.position.y > touch_controls.top_edge-64: help.position.y = touch_controls.top_edge-64


# Interpolate adjacent recorded ticks at a fixed rate, never chase the target
# with lerp(delta), which produces visible acceleration and deceleration.
func _display_position(state: Dictionary, id: String, current: Vector2) -> Vector2:
 if rewind_index >= 0 or diary_open or not controls_enabled or sim.history.size() < 2: return current
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
 var state: Dictionary = sim.history[rewind_index] if rewind_index >= 0 else sim.s
 if state.room == "cabins":
  for id in Simulation.Hospitality.GUESTS:
   var guest: Dictionary = Simulation.Hospitality.GUESTS[id]
   var p := Vector2(Rooms.CABIN_DOORS[guest.door]-96,376)
   world_overlay.draw_rect(Rect2(p,Vector2(192,34)),Color("172b35"))
   world_overlay.draw_rect(Rect2(p,Vector2(192,34)),Color("bd9149"),false,2)
   world_overlay.draw_string(ThemeDB.fallback_font,p+Vector2(6,22),"%d · %s" % [guest.number,guest.name],HORIZONTAL_ALIGNMENT_LEFT,180,13,Color("fff1cc"))
 if state.room == "foyer":
  var p: Vector2 = Simulation.Hospitality.STATION
  world_overlay.draw_string(ThemeDB.fallback_font,p+Vector2(-58,-48),"Refreshments",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("fff1cc"))
 for door in Rooms.exits(state.room, state.flags.get("shortcut", false)):
  var p := Rooms.point(door.point)
  world_overlay.draw_circle(p, 12, Color("d4b571a0"))
  world_overlay.draw_string(ThemeDB.fallback_font, p+Vector2(-45,-20), Rooms.ROOMS[door.room].title.split(" /")[0], HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fff1cc"))
 if highlight and rewind_index < 0:
  for option in sim.options(false):
   var p := Rooms.point(option.pos)
   world_overlay.draw_arc(p, 27, 0, TAU, 28, Color("f8d873"), 2)
   world_overlay.draw_string(ThemeDB.fallback_font, p+Vector2(-45,35), option.label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff1cc"))

func _show_room(id: String) -> void:
 for child in room_slot.get_children():
  room_slot.remove_child(child)
  child.queue_free()
 for prop in props.values():
  entity_layer.remove_child(prop)
  prop.queue_free()
 props.clear()
 var room := load("res://assets/rooms/mission_1/%s.tscn" % Rooms.ROOMS[id].scene).instantiate() as Node2D
 room_slot.add_child(room)
 if room.has_method("set_motion_time"): room.animate_bobbing = false
 room_audio.set_room(room.get_node("RoomAudioSettings"), int(sim.s.tick)*100, opening_audio_fade)
 opening_audio_fade = 1.0
 shown_room = id
 match id:
  "docks":
   _prop("suitcase", Rooms.LUGGAGE)
   _prop("bag_hiding", Vector2(210,335))
  "foyer":
   _prop("chandelier", Rooms.CHANDELIER_FLOOR)
   var station := preload("res://assets/props/mission_1/refreshment_station.gd").new()
   station.position = Simulation.Hospitality.STATION
   entity_layer.add_child(station)
   props.refreshments = station
  "controls":
   _prop("code_panel", Vector2(350,280))
   _prop("steam_vent", Vector2(915,420))
  "salon": _prop("drink", Vector2(815,310))
  "cabins":
   for door_id in Rooms.CABIN_DOORS:
    _prop("cabin_door", Vector2(Rooms.CABIN_DOORS[door_id],427), door_id)

func _prop(id: String, p: Vector2, key := "") -> void:
 var prop := load("res://assets/props/mission_1/%s.tscn" % id).instantiate() as Node2D
 prop.position = p
 entity_layer.add_child(prop)
 props[id if key.is_empty() else key] = prop

func _sync_props(state: Dictionary) -> void:
 for door_id in Rooms.CABIN_DOORS:
  if props.has(door_id): props[door_id].set_state("open" if state.flags.get(door_id,false) else "closed")
 if props.has("drink"):
  props.drink.visible = state.flags.get("party_arrived",false)
  props.drink.set_state("spilled" if state.flags.get("spilled",false) else "empty" if state.dead.has("guest") else "spiked" if state.flags.get("spiked",false) else "full")
 var stained: bool = state.flags.get("spilled", false)
 if actors.guest.stained_outfit != stained: actors.guest.set_outfit_stained(stained)
 if props.has("steam_vent"):
  props.steam_vent.set_state("off" if state.flags.get("steam_off",false) or int(state.tick) < Simulation.TRAP else "active")
  props.code_panel.set_state("rejected" if state.flags.get("panel_rejected",false) else "entry" if state.code_open else "accepted" if state.flags.get("steam_off",false) else "standby")
 if props.has("chandelier"):
  var fraction := accumulator/0.1 if controls_enabled and rewind_index<0 and not diary_open else 0.0
  var tick := float(state.tick)+fraction
  var drop := (tick-float(state.flags.chandelier_drop_tick))/Simulation.DROP_TICKS if state.flags.has("chandelier_drop_tick") else -1.0
  var impact := (tick-Simulation.FALL)/10.0 if state.flags.get("chandelier_fallen",false) else -1.0
  props.chandelier.show_at(state.flags.get("chandelier_warning",false),drop,impact,tick/10.0)
 if props.has("suitcase"):
  props.suitcase.visible = not state.flags.get("bag_found",false)
  props.suitcase.set_state("hidden" if state.flags.get("bag_hidden",false) else "present")
  props.bag_hiding.set_state("occupied" if state.flags.get("bag_hidden",false) else "empty")

func _events() -> void:
 for event in sim.events:
  if event.kind == "sound": sounds.play_cue(StringName(event.text))
  elif event.kind == "spike" and props.has("drink"): props.drink.play_spiking()

func _toggle_diary() -> void:
 diary_open = not diary_open
 diary.visible = diary_open
 accumulator = 0.0
 _refresh()
 _persist()

func _refresh_diary() -> void:
 diary_text.text = "Boy · Voyage notebook\n\n" + "\n\n".join(sim.memory.notes)
 if sim.memory.reset:
  diary_text.text += "\n\nThe pages can turn back time. R returns the whole leg to the docks. These pages record the current voyage."
 else:
  diary_text.text += "\n\nObservations are recorded here as you explore."

func _summary() -> String:
 return sim.summary()
func _begin_reset() -> void:
 if not sim.memory.reset and not sim.s.finished:
  sim.s.message = "The diary has no earlier pages to turn to yet."
  return
 if rewind_index >= 0:
  _finish_reset()
  return
 diary_open = false
 diary.hide()
 rewind_index = sim.history.size()-1
 _refresh()
func _rewind(delta: float) -> void:
 rewind_accumulator += delta
 rewind_index = maxi(0, rewind_index - maxi(1, int(sim.history.size()*delta/2.5)))
 _refresh()
 if rewind_index == 0: _finish_reset()
func _finish_reset() -> void:
 rewind_index = -1
 sim.reset()
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
 if initial.is_empty(): return
 journal.restore_run(sim, initial)

func _exit_tree() -> void:
 _persist()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready(): _persist()
