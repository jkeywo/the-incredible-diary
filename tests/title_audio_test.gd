extends SceneTree
const Title = preload("res://assets/ui/mission_1/title_screen.tscn")
const Sim = preload("res://mission1/simulation.gd")
const Save = preload("res://mission1/save.gd")
const Rooms = preload("res://mission1/rooms.gd")
const PATH := "res://build/title-audio-save.json"
func _initialize(): call_deferred("checks")
func make_title():
 var title = Title.instantiate()
 title.mission_save_path = PATH
 root.add_child(title)
 return title
func saved_room(id: String):
 Save.clear(PATH)
 var run := Sim.new(false)
 run.s.room = id
 run.s.pos = [350,300] if id == "controls" else [580,490]
 for i in 700: run.step()
 assert(Save.new().save_run(run,PATH).ok)
func check_preview(title, id: String):
 var room = load("res://assets/rooms/mission_1/%s.tscn" % Rooms.ROOMS[id].scene).instantiate()
 var config = room.get_node("RoomAudioSettings")
 for slot in ["music","ambience","secondary_ambience"]:
  var stream = config.get(slot)
  if stream == null: assert(not title._menu_audio._players.has(slot))
  else:
   var player = title._menu_audio._players[slot]
   assert(player.get_meta("source_path") == stream.resource_path)
   assert(is_equal_approx(player.volume_linear,db_to_linear(config.get(slot+"_volume_db"))*0.5))
 room.free()
func checks():
 Save.clear(PATH)
 var fresh = make_title()
 await process_frame
 assert(not fresh.continue_button.visible)
 check_preview(fresh,"docks")
 var dock_player = fresh._menu_audio._players.ambience
 fresh._on_new()
 assert(fresh._game_world.room_audio._players.ambience == dock_player)
 await create_timer(1.9).timeout
 assert(is_equal_approx(fresh._game_world.room_audio.presentation_gain,1.0))
 fresh.queue_free()
 await process_frame
 for id in ["foyer","controls","salon"]:
  saved_room(id)
  var title = make_title()
  await process_frame
  assert(title.continue_button.visible)
  check_preview(title,id)
  var audio = title._menu_audio
  var players: Dictionary = audio._players.duplicate()
  var hiss = audio._hiss_player
  title._on_continue()
  assert(title._game_world.room_audio == audio)
  for slot in players: assert(audio._players[slot] == players[slot])
  assert(audio._hiss_player == hiss)
  await create_timer(0.8).timeout
  assert(audio.presentation_gain > 0.5 and audio.presentation_gain < 1.0)
  await create_timer(1.1).timeout
  assert(is_equal_approx(audio.presentation_gain,1.0) and title._game_world.controls_enabled)
  title.queue_free()
  await process_frame
 saved_room("salon")
 var title = make_title()
 await process_frame
 var audio = title._menu_audio
 var outgoing = audio._players.music
 title._on_new()
 assert(title.new_confirm.visible and audio.presentation_gain == 0.5 and outgoing.playing)
 title.new_confirm.hide()
 title.new_confirm.canceled.emit()
 assert(title._game_world == null and audio._players.music == outgoing)
 title._on_new()
 title.new_confirm.hide()
 title.new_confirm.confirmed.emit()
 assert(title._game_world.room_audio == audio and outgoing.playing)
 assert(audio._players.has("ambience") and not audio._players.has("music"))
 await create_timer(1.9).timeout
 assert(not is_instance_valid(outgoing) and is_equal_approx(audio.presentation_gain,1.0))
 assert(audio.get_child_count() == audio._players.size())
 title.queue_free()
 await process_frame
 Save.clear(PATH)
 print("TITLE AUDIO PASS: destination previews, half gain, continuous handoff, fade-up, cancellation and confirmed New crossfade")
 quit()
