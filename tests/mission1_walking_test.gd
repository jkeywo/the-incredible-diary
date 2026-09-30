extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Rooms = preload("res://mission1/rooms.gd")
var run := Sim.new(false)
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
 walk(Vector2(300,540))
 walk(Vector2(145,440))
 walk(Vector2(145,390))
 until(55)
 assert(run.start("hide_bag"))
 until(int(run.s.tick)+35)
 walk(Vector2(580,300))
 walk(Vector2(580,105),"foyer")
 walk(Vector2(980,460),"controls")
 walk(Vector2(350,300))
 until(Sim.HOUR+200)
 assert(run.memory.procedure)
 walk(Vector2(140,635),"foyer")
 walk(Vector2(580,420))
 until(Sim.CREAK)
 assert(run.start("shove"))
 until(Sim.CREAK+18)
 walk(Vector2(580,540))
 # The luggage owner now waits with the Foyer group; walk around it.
 walk(Vector2(820,580))
 walk(Vector2(980,460),"controls")
 walk(Vector2(350,300))
 until(Sim.TRAP+10)
 assert(run.start("panel"))
 run.s.entry = run.s.code
 assert(run.submit_code())
 walk(Vector2(140,635),"foyer")
 walk(Vector2(580,260))
 walk(Vector2(580,140),"salon")
 walk(Sim.Rooms.BAR_GUEST+Vector2(0,40))
 until(Sim.POISON+5)
 assert(run.flag("chat_delay"))
 assert(run.start("bump"))
 until(Sim.END)
 assert(run.s.dead.is_empty() and run.s.safe.size()==3)
 # The upper-right foyer exit crosses the service corridor to the northern steam door.
 run.reset()
 run.s.room = "foyer"
 run.s.pos = [900,300]
 walk(Vector2(1015,230),"passage")
 walk(Vector2(720,480))
 walk(Vector2(720,650),"controls")
 assert(float(run.s.pos[0]) > 600)
 walk(Vector2(1015,400))
 walk(Vector2(1015,270),"passage")
 walk(Vector2(720,480))
 walk(Vector2(60,480),"foyer")
 walk(Vector2(175,460),"cabins")
 walk(Vector2(80,530))
 assert(run.s.room == "cabins")
 print("MISSION1 WALKING PASS: rescue chain and revised connected room route")
 quit()
