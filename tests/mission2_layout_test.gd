extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Content = preload("res://mission1/authoring_content.gd")
const Save = preload("res://mission1/save.gd")
const Grid = preload("res://mission1/authoring_grid.gd")

func _initialize() -> void:
 var run := Sim.new(false)
 run.start_mission_two()
 var errors := Content.validate(run.authored_content)
 assert(errors.is_empty(),str(errors))
 assert(run.s.room == "passage" and Sim.Rooms.point(run.s.pos) == Vector2(205,275))
 assert(run.s.actors.size() == 14 and run.s.actors.has("captain"))
 for id in run.s.actors:
  assert(run.authored_content.schedules[id].commitments.size() == 6)
 assert(not run.authored_content.rooms.has("docks"))
 for point in [Vector2(245,390),Vector2(300,410),Vector2(230,350),Vector2(550,350),Vector2(990,350)]:
  assert(not Grid.contains(run.authored_content.rooms.passage,point),str(point))
 for x in [205,580,960]:
  assert(Grid.contains(run.authored_content.rooms.passage,Vector2(x,390)))
  assert(not Grid.contains(Content.seed({}).rooms.passage,Vector2(x,390)))
 assert(not preload("res://mission1/authoring_grid.gd").contains(run.authored_content.rooms.passage,Vector2(1120,480)))
 var corridor_door: Dictionary = run.authored_content.connections.filter(func(d): return d.a == "foyer" and d.b == "passage")[0]
 assert(corridor_door.ap == [860,195] and corridor_door.a_bounds[0]+corridor_door.a_bounds[2] < 1000)
 assert(run.options().is_empty())
 run.s.pos = [205,320]
 for i in 6: run.step(Vector2.DOWN)
 assert(float(run.s.pos[1]) < 330)
 assert(run.start("crew_cabin_left"))
 for i in 12: run.step()
 assert(run.flag("crew_cabin_left"))
 run.s.pos = [205,370]
 for i in 4: run.step(Vector2.RIGHT)
 assert(float(run.s.pos[0]) < 220)
 run.s.pos = [205,320]
 for i in 8: run.step(Vector2.DOWN)
 assert(float(run.s.pos[1]) > 410)
 assert(run.start("crew_cabin_left"))
 for i in 12: run.step()
 assert(not run.flag("crew_cabin_left"))
 for i in 8: run.step(Vector2.UP)
 assert(float(run.s.pos[1]) >= 410)
 run.s.room = "foyer"
 run.s.pos = [580,635]
 for i in 10: run.step(Vector2.DOWN)
 assert(run.s.room == "foyer")
 assert(run.s.dialogue.text == "We're at sea. I don't want to go overboard.")
 var first_leg := Sim.new(false)
 for room in ["foyer","salon","passage"]:
  var door: Dictionary = Sim.Rooms.locked_doors(room)[0]
  first_leg.s.room = room
  first_leg.s.pos = door.point.duplicate()
  first_leg.step(Vector2(0.11,0))
  assert(first_leg.s.room == room and first_leg.s.dialogue.text == "The door is locked.")
 # Exercise each authored doorway in both directions, with no crowd in the way.
 for door in run.authored_content.connections:
  for side in ["a","b"]:
   run.s.actors = {}
   run.s.room = door[side]
   run.s.pos = door[side+"p"].duplicate()
   run.s.door_cooldown = 0
   run.step(Vector2(0.01,0.11))
   assert(run.s.room == door["b" if side == "a" else "a"],str(door.id)+side)
 run.start_mission_two()
 # Full six-hour run: NPCs move, no first-leg hazards or objectives execute.
 var visited := {}
 for i in 7200:
  run.step()
  for id in run.s.actors:
   visited.get_or_add(id,{})[run.s.actors[id].room] = true
 assert(run.s.tick == 10800 and run.s.finished)
 assert(run.s.dead.is_empty() and run.s.safe.is_empty())
 assert(not run.flag("trapped") and not run.flag("chandelier_fallen") and not run.flag("spiked"))
 for id in visited: assert(not visited[id].has("docks"))
 for id in visited: assert(visited[id].size() >= 3,id+" did not travel: "+str(run.s.actors[id]))
 const PATH := "res://build/mission2-test.journal"
 Save.clear(PATH)
 assert(Save.new().save_run(run,PATH).ok)
 var loaded := Save.load_saved(PATH)
 assert(loaded.ok)
 var restored := Sim.new(false)
 restored.restore_record(loaded.data)
 assert(restored.exploration() and restored.history == JSON.parse_string(JSON.stringify(run.history)))
 Save.clear(PATH)
 # Upgrade the first exploration seed without changing earlier recorded frames.
 var old := Sim.new(false)
 old.start_mission_two()
 old.step()
 old.authored_content.version = "mission2-layout-1"
 var previous: Dictionary = old.history[0].duplicate(true)
 var upgraded := Sim.new(false)
 upgraded.restore_record({"current":old.s,"memory":old.memory,"history":old.history,"authored_content":old.authored_content,"content_versions":old.content_versions})
 assert(upgraded.authored_content.version == "mission2-layout-8")
 assert(upgraded.history[0] == previous)
 assert(upgraded.content_versions.has("mission2-layout-1"))
 for id in preload("res://mission2/content.gd").CREW_DOORS: assert(upgraded.flag(id))
 old.authored_content.version = "mission2-layout-2"
 old.s.pos = [245,390]
 old.s.prop_states.chandelier = "intact"
 upgraded.restore_record({"current":old.s,"memory":old.memory,"history":old.history,"authored_content":old.authored_content,"content_versions":old.content_versions})
 assert(upgraded.s.prop_states.chandelier == "fallen")
 assert(upgraded.authored_content.instances.has("janitor"))
 assert(Grid.contains(upgraded.authored_content.rooms.passage,Sim.Rooms.point(upgraded.s.pos)))
 assert(upgraded.history[0] == previous)
 for id in preload("res://mission2/content.gd").CREW_DOORS: assert(not upgraded.flag(id))
 # The new top doorway is blocked in both geometry systems until pressure stops.
 for authored in [false,true]:
  var steam := Sim.new(false)
  if authored: assert(steam.apply_authored(Content.seed(steam.s.actors)).ok)
  steam.s.flags.trapped = true
  steam.s.room = "controls"
  steam.s.pos = [1015,350]
  for i in 8: steam.step(Vector2.UP)
  assert(steam.s.room == "controls")
  steam.s.flags.steam_off = true
  for i in 12: steam.step(Vector2.UP)
  assert(steam.s.room == "passage")
 print("MISSION2 LAYOUT PASS: six-hour roster, both-way doors, history and relocated steam block")
 quit()
