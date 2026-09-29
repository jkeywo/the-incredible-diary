extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Rooms = Sim.Rooms
func _initialize() -> void: call_deferred("checks")

func checks() -> void:
 for room in Rooms.ROOMS:
  for door in Rooms.exits(room,true):
   var arrival := Rooms.point(door.arrival)
   assert(Rooms.can_stand(door.room,arrival))
   for reverse in Rooms.exits(door.room,true):
    if reverse.room == room: assert(not reverse.bounds.has_point(arrival))
 for room in Rooms.GROUPS:
  for group in 3:
   var points := []
   for slot in 3:
    var p := Rooms.point(Rooms.group_slot(room,group,slot).pos)
    assert(Rooms.can_stand(room,p))
    for other in points: assert(p.distance_to(other)>25)
    points.append(p)
   assert(absf((points[1]-points[0]).cross(points[2]-points[0]))>100)

 var run := Sim.new(false)
 run.s.room = "controls"
 run.s.pos = [350,470]
 while run.s.tick < Sim.DEMO_END+200: run.step()
 assert(run.s.operator.phase == "away" and run.s.actors.crew.room != "controls")
 run.s.flags.steam_off = true
 run.s.room = "controls"
 run.s.pos = [350,460]
 var heard := false
 while run.s.tick < 2900:
  run.step()
  if run.s.dialogue.get("text","").contains("switched off"):
   heard = true
   assert(run.flag("steam_off"))
 assert(heard and not run.flag("steam_off"))
 check_record(run)
 while run.s.tick < Sim.TRAP-1: run.step()
 run.s.flags.steam_off = true
 run.step()
 assert(run.s.safe.has("chatterbox") and run.flag("steam_off"))
 while run.s.tick < 6500: run.step()
 assert(not run.flag("steam_off") and run.s.safe.has("chatterbox") and not run.s.dead.has("chatterbox"))

 var arrival := Sim.new(false)
 var foyer_ticks := 0
 while arrival.s.tick < 850:
  arrival.step()
  var guest: Dictionary = arrival.s.actors.chandelier_guest
  if guest.room == "foyer" and guest.action in ["idle","talk"]: foyer_ticks += 1
 assert(foyer_ticks >= 190)

 var pace := Sim.new(false)
 pace.s.room = "foyer"
 pace.s.pos = [580,412]
 while pace.s.tick < Sim.FALL:
  pace.step()
  if pace.s.tick >= 3500: assert(not pace.s.actors.chandelier_guest.get("solid",true))
 assert(Rooms.point(pace.s.actors.chandelier_guest.pos) == Rooms.CHANDELIER_GUEST)
 assert(pace.s.dead.has("chandelier_guest"))
 assert(not Rooms.can_stand("foyer",Rooms.WRECKAGE.get_center(),pace.s.flags))
 assert(Rooms.can_step("foyer",Rooms.WRECKAGE.get_center(),Rooms.WRECKAGE.get_center()+Vector2(0,10),pace.s.flags))
 var route := Sim.Routines.path("foyer",Vector2(480,355),"foyer",Vector2(690,355),false,pace.s.flags)
 for point in route: assert(not Rooms.WRECKAGE.has_point(Rooms.point(point.pos)))

 var hints := Sim.new(false)
 hints.s.room = "foyer"
 hints.s.pos = [580,550]
 hints.step()
 assert(hints.s.dialogue.get("hint","") == "highlight")
 hints.reset()
 assert(hints.memory.hints.highlight)
 hints.s.dialogue = {}
 hints.s.conversation = {}
 hints.memory.reset = true
 Sim.Hints.see_body(hints,"chandelier_guest")
 Sim.Hints.queue(hints,"wait")
 Sim.Hints.update(hints)
 assert(hints.s.dialogue.hint == "diary" and hints.s.hint_queue.has("wait"))
 hints.record_current_frame()
 check_record(hints)
 assert(Sim.Hints.prompt("wait",false,false).contains("Hold F"))
 assert(Sim.Hints.prompt("highlight",true,false).contains("A"))
 assert(Sim.Hints.prompt("diary",false,true) == "Tap Diary")

 var game := preload("res://mission1/play.tscn").instantiate()
 game.configure({},false)
 root.add_child(game)
 game.set_physics_process(false)
 game.enable_controls()
 game.sim = Sim.new(false)
 game._update_idle_hint(9.9)
 assert(game.sim.s.get("hint_queue",[]).is_empty())
 game._update_idle_hint(0.11)
 assert(game.sim.s.hint_queue.has("wait"))
 game.idle_seconds = 9.0
 game.diary_open = true
 game._update_idle_hint(1.1)
 assert(game.idle_seconds == 0.0)
 game.diary_open = false
 # Every idle exclusion resets real time without advancing a hint.
 for field in ["dialogue","conversation","action","code_open","tutorial"]:
  var original = game.sim.s.get(field)
  game.sim.s[field] = {"active":true} if field in ["dialogue","conversation","action"] else true if field == "code_open" else "approach"
  game.idle_seconds = 9.9
  game._update_idle_hint(1.0)
  assert(game.idle_seconds == 0.0)
  if original == null: game.sim.s.erase(field)
  else: game.sim.s[field] = original
 game.application_focused = false
 game.idle_seconds = 9.9
 game._update_idle_hint(1.0)
 assert(game.idle_seconds == 0.0)
 game.application_focused = true
 game.rewind_index = 0
 game.idle_seconds = 9.9
 game._update_idle_hint(1.0)
 assert(game.idle_seconds == 0.0)
 game.rewind_index = -1
 game.idle_seconds = 5.0
 game._input(InputEventMouseMotion.new())
 assert(game.idle_seconds == 5.0)
 var key := InputEventKey.new()
 key.pressed = true
 key.physical_keycode = KEY_W
 game._input(key)
 assert(game.idle_seconds == 0.0)
 for device in [[false,false],[true,false],[false,true]]:
  for hint in ["highlight","wait","diary"]:
   assert(not Sim.Hints.prompt(hint,device[0],device[1]).is_empty())
 game.sim.s.room = "cabins"
 game.sim.s.pos = [580,465]
 game.highlight = true
 game._refresh()
 assert(game.props.cabin_middle.material.get_shader_parameter("interaction_outline"))
 assert(game.sim.options().filter(func(o): return o.target == "cabin_middle").size() == 2)
 var existing_shader = game.actors.guest.material.shader
 game.sim.s.room = "foyer"
 game._refresh()
 assert(game.actors.guest.material.shader == existing_shader)
 assert(not game.props.has("cabin_middle"))
 game.sim.s.room = "cabins"
 game._refresh()
 await capture("outline-doors")
 game.highlight = false
 game._refresh()
 assert(not game.props.cabin_middle.material.get_shader_parameter("interaction_outline"))
 game.sim = pace
 game._refresh()
 await create_timer(1.0).timeout
 await capture("wreckage-body")
 check_record(pace)
 game.sim = Sim.new(false)
 game.sim.s.room = "salon"
 game.sim.s.pos = [900,280]
 game.sim.s.tick = Sim.POISON+39
 game.sim.s.flags.party_arrived = true
 game.sim.s.flags.spiked = true
 game.sim.s.actors = game.sim.actor_positions()
 game.sim.step()
 assert(game.sim.s.dead.has("guest") and game.sim.s.flags.has("glass_drop"))
 game._refresh()
 assert(game.props.drink.position == Rooms.point(game.sim.s.flags.glass_drop))
 assert(game.props.drink.position != Rooms.BAR_GLASS)
 assert(game.props.drink.current_state == "empty")
 check_record(game.sim)
 await capture("glass-body")
 game.sim.s.dialogue = {"speaker":"amelia","name":"Thought","text":"I wonder what I should do?","kind":"thought","room":"salon","started":0,"until":99999,"hint":"highlight"}
 game._refresh()
 assert(game.hint_prompt.visible and game.hint_prompt.text.contains("Highlight"))
 assert(game.bubble.message_label.modulate.a == 1.0)
 await capture("tutorial-hint")
 game.bubble.bubble_size = Vector2(1100,650)
 game._place_bubble(game.actors.amelia.position)
 assert(game.bubble.background_opacity == 0.5)
 assert(game.bubble.message_label.modulate.a == 1.0)
 game.queue_free()
 await process_frame
 print("MISSION1 IMPROVEMENTS PASS: arrivals, groups, operator, prevention, foyer pause, pacing, wreckage, hints, outlines and dropped glass")
 quit()

func capture(label: String) -> void:
 if "--screenshots" not in OS.get_cmdline_user_args(): return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/improvements-"+label+".png")

func check_record(run) -> void:
 var restored := Sim.new(false)
 var record: Dictionary = JSON.parse_string(JSON.stringify({"current":run.s,"history":run.history,"memory":run.memory}))
 restored.restore_record(record)
 assert(restored.s == record.current and restored.history == record.history)
 assert(restored.memory.get("hints",{}) == record.memory.get("hints",{}))
 var history_before: Array = restored.history.duplicate(true)
 restored.step()
 assert(restored.history.slice(0,history_before.size()) == history_before)

