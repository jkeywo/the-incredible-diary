extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
func _initialize() -> void:
 var rooms = preload("res://mission1/rooms.gd")
 # The entire wide base blocks walking, including when the steam is off.
 for flags in [{},{"steam_off":true},{"panel_rejected":true}]:
  for x in [240,350,460]:
   assert(not rooms.can_stand("controls",Vector2(x,275),flags))
   assert(rooms.move("controls",Vector2(x,295),Vector2(0,-10),flags) == Vector2(x,295))
  assert(rooms.can_stand("controls",Vector2(225,275),flags))
  assert(rooms.can_stand("controls",Vector2(475,275),flags))
 var content := preload("res://mission1/authoring_content.gd").seed({})
 rooms.authored = content.rooms
 rooms.behaviour = content
 for state in content.templates.code_panel.states:
  rooms.prop_states = {"code_panel":state}
  assert(content.templates.code_panel.states[state].solid)
  assert(not rooms.can_stand("controls",Vector2(350,275)))
  assert(rooms.can_stand("controls",Vector2(350,300)))
 rooms.authored = {}
 rooms.behaviour = {}
 rooms.prop_states = {}
 # Existing saves gain collision without changing their recorded positions.
 var old_run := Sim.new(false)
 old_run.s.room = "controls"
 old_run.s.pos = [350,275]
 old_run.record_current_frame()
 var old_content := content.duplicate(true)
 old_content.version = "mission1-layout-6"
 for state in old_content.templates.code_panel.states.values(): state.solid = false
 var old_history: Array = old_run.history.duplicate(true)
 var resumed := Sim.new(false)
 resumed.restore_record({"authored_content":old_content,"content_versions":{},"current":old_run.s,"memory":old_run.memory,"history":old_history})
 assert(resumed.authored_content.version == "mission1-layout-7")
 assert(resumed.authored_content.templates.code_panel.states.standby.solid)
 assert(rooms.point(resumed.s.pos) == Vector2(350,292))
 assert(resumed.history[0] == old_history[0])
 assert(not resumed.content_versions["mission1-layout-6"].templates.code_panel.states.standby.solid)
 var run := Sim.new(false)
 run.s.room = "controls"
 run.s.pos = [350,300]
 run.s.tick = Sim.DEMO_START-1
 for i in 91: run.step()
 assert(run.memory.procedure and run.s.flags.known_code == run.s.code)
 assert(run.s.code.length() == 3)
 assert(run.start("panel"))
 run.s.entry = "000"
 assert(not run.submit_code())
 run.s.entry = run.s.code
 assert(run.submit_code() and run.flag("steam_off"))
 while run.s.tick < Sim.TRAP: run.step()
 assert(not run.flag("steam_off") and run.flag("trapped"))
 assert(run.start("panel"))
 run.s.entry = run.s.code
 assert(run.submit_code() and run.s.safe.has("chatterbox"))
 var old: String = run.s.code
 run.reset()
 assert(run.memory.procedure and run.s.code != old and not run.s.flags.has("known_code"))
 run.s.tick = Sim.STEAM_FATAL-1
 run.step()
 assert(run.s.dead.has("chatterbox"))
 var late := Sim.new(false)
 late.s.tick = Sim.DEMO_END-140
 for i in 66: late.step()
 late.s.room = "controls"
 late.s.pos = [350,300]
 for i in 30: late.step()
 assert(not late.memory.procedure and late.s.flags.has("known_code"))
 print("MISSION1 STEAM PASS: procedure, late lines, code retry, early restoration, rescue, reset")
 quit()
