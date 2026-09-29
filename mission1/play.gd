extends Node2D
## Mission 1 presentation; all consequential state lives in the deterministic simulation.
const Simulation = preload("res://mission1/simulation.gd")
const Rooms = preload("res://mission1/rooms.gd")
const Watch = preload("res://mission1/pocket_watch.gd")
const Character = preload("res://assets/characters/character_sprite.tscn")
const RoomAudio = preload("res://mission1/room_audio.gd")
const EventAudio = preload("res://mission1/event_audio.gd")
var sim := Simulation.new()
var controls_enabled := false
var save_path := "user://mission1_v2.json"
var save_enabled := false
var room_slot: Node2D
var actors := {}
var props := {}
var room_audio: Node
var sounds: Node
var watch: Control
var heading: Label
var message: Label
var help: Label
var hud: Control
var wheel: Control
var wheel_labels: Array = []
var choices: Array = []
var selected := 0
var progress: ProgressBar
var shown_room := ""
var accumulator := 0.0
var highlight := false
var wait_latched := false
var initial: Dictionary = {}
var diary: PanelContainer
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
 room_audio = RoomAudio.new()
 add_child(room_audio)
 sounds = EventAudio.new()
 add_child(sounds)
 for id in ["amelia", "guest", "chandelier_guest", "chatterbox", "crew"]:
  var actor := Character.instantiate()
  actor.character_id = {"amelia":"player", "guest":"rake", "chandelier_guest":"glamorous", "chatterbox":"matron", "crew":"ex_army"}[id]
  add_child(actor)
  actors[id] = actor
 _build_hud()
 _restore_initial()
 _refresh()

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
 heading = _label(Vector2(25,18), Vector2(800,35), 23)
 message = _label(Vector2(25,620), Vector2(900,65), 18)
 help = _label(Vector2(25,696), Vector2(1110,36), 15)
 help.text = "WASD / left stick: move   1–6 / right stick + RB: interact   Tab / Y: diary   Hold F / LT: wait   H / X: highlight   Space: editor"
 progress = ProgressBar.new()
 progress.position = Vector2(440,585)
 progress.size = Vector2(280,14)
 progress.show_percentage = false
 hud.add_child(progress)
 wheel = Control.new()
 wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 hud.add_child(wheel)
 wheel.draw.connect(_draw_wheel)
 diary = PanelContainer.new()
 diary.position = Vector2(135,70)
 diary.size = Vector2(850,600)
 hud.add_child(diary)
 var style := StyleBoxFlat.new()
 style.bg_color = Color("e3d4ac")
 style.set_content_margin_all(24)
 diary.add_theme_stylebox_override("panel", style)
 var column := VBoxContainer.new()
 diary.add_child(column)
 var title := Label.new()
 title.text = "THE DIARY OF AMELIA ASHCOMBE"
 title.add_theme_color_override("font_color", Color("342f29"))
 title.add_theme_font_size_override("font_size", 24)
 column.add_child(title)
 diary_text = RichTextLabel.new()
 diary_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
 diary_text.add_theme_color_override("default_color", Color("342f29"))
 diary_text.add_theme_font_size_override("normal_font_size", 18)
 column.add_child(diary_text)
 var close := Button.new()
 close.text = "Close diary (Tab / Y)"
 close.pressed.connect(_toggle_diary)
 column.add_child(close)
 var reset := Button.new()
 reset.text = "Turn back the pages (R / Back)"
 reset.pressed.connect(_begin_reset)
 column.add_child(reset)
 diary.hide()

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
 var held := Input.is_physical_key_pressed(KEY_F) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5
 if not held: wait_latched = false
 var waiting := held and not wait_latched
 accumulator += delta * (20.0 if waiting else 1.0)
 var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down") if not waiting else Vector2.ZERO
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
  sim.s.message = "Action cancelled."
 elif key >= KEY_1 and key <= KEY_6:
  _choose(key-KEY_1)
 elif key == KEY_ENTER and sim.s.code_open:
  _submit_code()
 elif key == KEY_BACKSPACE and sim.s.code_open:
  sim.s.entry = ""
 elif button == JOY_BUTTON_RIGHT_SHOULDER:
  _choose(selected)
 elif event is InputEventJoypadMotion:
  var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
  if stick.length() > 0.35 and not choices.is_empty():
   selected = posmod(roundi((stick.angle()+PI/2.0)/TAU*choices.size()), choices.size())
 _refresh()

func _choose(index: int) -> void:
 if sim.s.code_open:
  if index < 6 and sim.s.entry.length() < 3: sim.s.entry += str(index+1)
  elif index == 6: _submit_code()
  elif index == 7: sim.s.entry = ""
 elif index < choices.size():
  sim.start(choices[index].id)

func _submit_code() -> void:
 pass

func _refresh(direction := Vector2.ZERO) -> void:
 var state: Dictionary = sim.history[rewind_index] if rewind_index >= 0 else sim.s
 if shown_room != state.room: _show_room(state.room)
 watch.elapsed_seconds = float(state.tick)/10.0
 heading.text = "MISSION 1  ·  " + str(Rooms.ROOMS[state.room].title)
 message.text = state.message
 room_audio.set_game_time(int(state.tick)*100)
 actors.amelia.position = Rooms.point(state.pos)
 actors.amelia.play_action("walk" if direction.length_squared()>0.01 else "idle", state.facing)
 var live := sim.s
 sim.s = state
 var positions := sim.actor_positions()
 for id in positions:
  var info: Dictionary = positions[id]
  actors[id].visible = info.room == state.room
  actors[id].position = Rooms.point(info.pos)
  actors[id].play_action(info.action, "down")
 choices = sim.options()
 if state.code_open:
  choices = []
  for i in 6: choices.append({"label":str(i+1)})
  choices.append({"label":"Confirm"})
  choices.append({"label":"Clear"})
  message.text = "CONTROL PANEL   [ %s ]   Enter three digits · Enter: confirm · Backspace: clear" % state.entry
 selected = clampi(selected, 0, maxi(0, choices.size()-1))
 _sync_props(state)
 sim.s = live
 progress.visible = not state.action.is_empty()
 if progress.visible: progress.value = 100.0*float(state.action.progress)/float(state.action.duration)
 wheel.visible = not diary_open and rewind_index < 0 and not state.finished
 wheel.position = Vector2(clampf(float(state.pos[0]), 220, 900), clampf(float(state.pos[1])-110, 240, 465))
 wheel.queue_redraw()
 queue_redraw()
 if state.finished:
  message.text = _summary()
  help.text = "Enter / A: turn back the pages and play again    Tab / Y: read diary"
 elif rewind_index >= 0:
  message.text = "The pages turn backwards…  R / Back to skip"
 if diary_open: _refresh_diary()

func _draw_wheel() -> void:
 if choices.is_empty(): return
 var font := ThemeDB.fallback_font
 wheel.draw_circle(Vector2.ZERO, 112, Color("17252de8"))
 wheel.draw_arc(Vector2.ZERO, 113, 0, TAU, 60, Color("d8b86c"), 2, true)
 for i in choices.size():
  var angle := -PI/2 + TAU*i/choices.size()
  var p := Vector2.from_angle(angle)*78
  var label := "%d %s" % [i+1, choices[i].label]
  if sim.s.code_open: label = choices[i].label
  wheel.draw_circle(p, 15, Color("9e7337") if i == selected else Color("344957"))
  var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
  wheel.draw_string(font, p+Vector2(-width/2,5), label, HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff1cc"))

func _draw() -> void:
 if not controls_enabled: return
 var state: Dictionary = sim.history[rewind_index] if rewind_index >= 0 else sim.s
 for door in Rooms.exits(state.room, state.flags.get("shortcut", false)):
  var p := Rooms.point(door.point)
  draw_circle(p, 12, Color("d4b571a0"))
  draw_string(ThemeDB.fallback_font, p+Vector2(-45,-20), Rooms.ROOMS[door.room].title.split(" /")[0], HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fff1cc"))
 if highlight and rewind_index < 0:
  for option in sim.options(false):
   var p := Rooms.point(option.pos)
   draw_arc(p, 27, 0, TAU, 28, Color("f8d873"), 2)
   draw_string(ThemeDB.fallback_font, p+Vector2(-45,35), option.label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff1cc"))

func _show_room(id: String) -> void:
 for child in room_slot.get_children():
  room_slot.remove_child(child)
  child.queue_free()
 props.clear()
 var room := load("res://assets/rooms/mission_1/%s.tscn" % Rooms.ROOMS[id].scene).instantiate() as Node2D
 room_slot.add_child(room)
 room_audio.set_room(room.get_node("RoomAudioSettings"), int(sim.s.tick)*100, 1.0)
 shown_room = id
 match id:
  "docks":
   _prop("suitcase", Vector2(340,430))
   _prop("bag_hiding", Vector2(235,420))
  "foyer": _prop("chandelier", Vector2(680,375))
  "controls":
   _prop("code_panel", Vector2(350,280))
   _prop("steam_vent", Vector2(915,420))
  "salon": _prop("drink", Vector2(815,310))
  "cabins": _prop("cabin_door", Vector2(580,427))

func _prop(id: String, p: Vector2) -> void:
 var prop := load("res://assets/props/mission_1/%s.tscn" % id).instantiate() as Node2D
 prop.position = p
 room_slot.add_child(prop)
 props[id] = prop

func _sync_props(state: Dictionary) -> void:
 if props.has("suitcase"):
  props.suitcase.set_state("hidden" if state.flags.get("bag_hidden",false) else "present")
  props.bag_hiding.set_state("occupied" if state.flags.get("bag_hidden",false) else "empty")

func _events() -> void:
 for event in sim.events:
  if event.kind == "sound": sounds.play_cue(StringName(event.text))

func _toggle_diary() -> void:
 diary_open = not diary_open
 diary.visible = diary_open
 accumulator = 0.0
 _refresh()
 _persist()

func _refresh_diary() -> void:
 diary_text.text = "Junior purser · Voyage notebook\n\n" + "\n\n".join(sim.memory.notes)
 if sim.memory.reset:
  diary_text.text += "\n\nThe pages can turn back time. R returns the whole leg to the docks. Your observations remain."
 else:
  diary_text.text += "\n\nObservations are recorded here as you explore."

func _summary() -> String:
 return "The party has ended."
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
 help.text = "WASD / left stick: move   1–6 / right stick + RB: interact   Tab / Y: diary   Hold F / LT: wait   H / X: highlight   Space: editor"
 _refresh()
 _persist()
func _persist() -> void:
 pass
func _restore_initial() -> void:
 pass

