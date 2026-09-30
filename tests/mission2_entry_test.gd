extends SceneTree
const Title = preload("res://assets/ui/mission_1/title_screen.tscn")
const Sim = preload("res://mission1/simulation.gd")
const Save = preload("res://mission1/save.gd")
const PATH := "res://build/mission2-entry-regression.journal"

func _initialize() -> void: call_deferred("checks")

func checks() -> void:
 Save.clear(PATH)
 var old := Sim.new(false)
 old.start_mission_two()
 for i in 5: old.step()
 old.s.room = "foredeck"
 old.s.pos = [600,420]
 old.record_current_frame()
 assert(Save.new().save_run(old,PATH).ok)
 for turn_page in [false,true]:
  if turn_page: set_meta("open_mission2",true)
  var title = Title.instantiate()
  title.mission_save_path = "res://build/mission2-entry-unused.journal"
  title.mission_two_save_path = PATH
  root.add_child(title)
  current_scene = title
  if not turn_page: title._on_mission_two()
  await process_frame
  await process_frame
  var state: Dictionary = title._pending_saved.current
  assert(state.room == ("passage" if turn_page else "foredeck"))
  assert(Sim.Rooms.point(state.pos) == (Vector2(205,275) if turn_page else Vector2(600,420)))
  assert(state.tick == (0 if turn_page else old.s.tick))
  assert(not has_meta("open_mission2"))
  if is_instance_valid(title._game_world): title._game_world.save_enabled = false
  title.queue_free()
  await process_frame
 Save.clear(PATH)
 print("MISSION2 ENTRY PASS: Turn the Page starts in cabin; Dev Menu resumes saved visit")
 await preload("res://tests/shutdown.gd").finish(self)
