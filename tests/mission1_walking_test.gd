extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Rooms = preload("res://mission1/rooms.gd")
var run := Sim.new()
func walk(p: Vector2, expect_room := "") -> void:
 var before: String = run.s.room
 for i in 500:
  if not expect_room.is_empty() and run.s.room == expect_room: return
  var delta := p-Rooms.point(run.s.pos)
  if expect_room.is_empty() and delta.length() < 15: return
  run.step(delta.normalized())
 push_error("Failed route %s -> %s at %s" % [before,expect_room,run.s.pos])
 quit(1)
func until(t: int) -> void:
 while run.s.tick < t: run.step()
func _initialize() -> void:
 walk(Vector2(350,430))
 until(55)
 assert(run.start("hide_bag"))
 until(80)
 walk(Vector2(580,300))
 walk(Vector2(580,105),"foyer")
 walk(Vector2(980,460),"controls")
 walk(Vector2(350,300))
 until(Sim.HOUR+150)
 assert(run.memory.procedure)
 walk(Vector2(140,635),"foyer")
 walk(Vector2(680,440))
 until(Sim.CREAK)
 assert(run.start("shove"))
 until(Sim.CREAK+12)
 walk(Vector2(980,460),"controls")
 walk(Vector2(350,300))
 until(Sim.TRAP+10)
 assert(run.start("panel"))
 run.s.entry = run.s.code
 assert(run.submit_code())
 walk(Vector2(510,635),"salon")
 walk(Vector2(800,330))
 until(4*Sim.HOUR+35)
 assert(run.flag("chat_delay"))
 assert(run.start("bump"))
 until(Sim.END)
 assert(run.s.dead.is_empty() and run.s.safe.size()==3)
 # The short stair cannot bypass the deliberately conflicting early rescues.
 run.reset()
 run.s.room = "foyer"
 run.s.pos = [680,440]
 until(Sim.CREAK)
 assert(run.start("shove"))
 until(Sim.CREAK+10)
 walk(Vector2(980,460),"controls")
 walk(Vector2(510,635),"salon")
 walk(Vector2(800,330))
 assert(run.s.dead.has("guest"))
 run.reset()
 run.s.room = "salon"
 run.s.pos = [850,380]
 until(Sim.CREAK+20)
 assert(run.start("bump"))
 until(Sim.CREAK+30)
 walk(Vector2(960,520),"controls")
 walk(Vector2(140,635),"foyer")
 walk(Vector2(745,445))
 if run.start("shove"):
  for i in 11: run.step()
 until(Sim.FALL)
 assert(run.s.dead.has("chandelier_guest"))
 print("MISSION1 WALKING PASS: real doorway route wins; early drink/foyer route conflicts")
 quit()
