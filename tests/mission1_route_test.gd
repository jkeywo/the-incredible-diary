extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
func advance(run: RefCounted, target: int) -> void:
 while run.s.tick < target: run.step()
func _initialize() -> void:
 # Departure queries share the actual conditional journey stages.
 var routes = Sim.Routines
 assert(routes.next_commitment("chandelier_guest",159,800,9000,{}) == 160)
 assert(routes.next_commitment("chandelier_guest",160,800,9000,{}) == 850)
 assert(routes.next_commitment("chandelier_guest",3500,800,9000,{}) == 3500)
 var cabin_duration: int = routes.duration(routes.path("docks",Vector2(390,430),"cabins",Vector2(580,315)))
 for found in [100,720,950,1720]:
  var boarding: int = found+80
  var flags := {"bag_found":true,"bag_found_tick":found}
  var start: int = maxi(found,boarding-routes.duration(routes.path("docks",Vector2(390,430),"docks",Vector2(580,105))))
  var arrival: int = start+cabin_duration
  var final_departure: int = 9000-routes.duration(routes.path("cabins",Vector2(580,315),"salon",Sim.Rooms.BAR_GUEST))-60
  var expected: int = maxi(arrival+50,1000) if arrival < 1080 else final_departure
  assert(routes.next_commitment("guest",start,boarding,9000,flags) == expected)
  if arrival < 1080:
   assert(routes.next_commitment("guest",expected,boarding,9000,flags) == 1380)
  assert(routes.next_commitment("guest",final_departure,boarding,9000,flags) == final_departure)
 var run := Sim.new(false)
 run.s.pos = [145,390]
 advance(run, 60)
 assert(run.start("hide_bag"))
 advance(run, 90)
 run.s.room = "controls"
 run.s.pos = [350,300]
 advance(run, Sim.HOUR+200)
 assert(run.memory.procedure)
 run.s.room = "foyer"
 run.s.pos = [580,380]
 advance(run, Sim.CREAK)
 assert(run.start("shove"))
 advance(run, Sim.FALL+1)
 run.s.room = "controls"
 run.s.pos = [350,300]
 advance(run, Sim.TRAP+10)
 assert(run.start("panel"))
 run.s.entry = run.s.code
 assert(run.submit_code())
 advance(run, Sim.TRAP+330)
 assert(run.flag("chat_delay") and run.party_arrival() == 4*Sim.HOUR)
 run.s.room = "salon"
 run.s.pos = [Sim.Rooms.BAR_GUEST.x,Sim.Rooms.BAR_GUEST.y]
 advance(run, Sim.POISON+5)
 assert(run.start("bump"))
 advance(run, Sim.END-2)
 assert(not run.s.finished)
 advance(run, Sim.END)
 assert(run.s.finished and run.s.dead.is_empty() and run.s.safe.size() == 3 and run.memory.completed)
 assert(run.summary().contains("EVERYONE SURVIVED"))
 var fail := Sim.new(false)
 fail.s.flags.bag_hidden = true
 assert(fail.party_arrival() == 3*Sim.HOUR+450)
 advance(fail, Sim.END)
 assert(fail.s.dead.size() == 3 and not fail.memory.completed)
 assert(not fail.summary().contains("poison"))
 var early := Sim.new(false)
 assert(early.party_arrival() == Sim.CREAK-30)
 assert(early.options().all(func(x): return x.id != "porter"))
 print("MISSION1 ROUTE PASS: authored rescue chain, missing chatter, full Hour 6, failure privacy")
 quit()
