extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
func advance(run: RefCounted, target: int) -> void:
 while run.s.tick < target: run.step()
func _initialize() -> void:
 var run := Sim.new()
 run.s.pos = [145,390]
 advance(run, 60)
 assert(run.start("hide_bag"))
 advance(run, 90)
 run.s.room = "controls"
 run.s.pos = [350,300]
 advance(run, Sim.HOUR+150)
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
 advance(run, Sim.TRAP+240)
 assert(run.flag("chat_delay") and run.party_arrival() == 4*Sim.HOUR)
 run.s.room = "salon"
 run.s.pos = [800,330]
 advance(run, 4*Sim.HOUR+35)
 assert(run.start("bump"))
 advance(run, Sim.END-1)
 assert(not run.s.finished)
 run.step()
 assert(run.s.finished and run.s.dead.is_empty() and run.s.safe.size() == 3 and run.memory.completed)
 assert(run.summary().contains("EVERYONE SURVIVED"))
 var fail := Sim.new()
 fail.s.flags.bag_hidden = true
 assert(fail.party_arrival() == 3*Sim.HOUR+300)
 advance(fail, Sim.END)
 assert(fail.s.dead.size() == 3 and not fail.memory.completed)
 assert(not fail.summary().contains("poison"))
 var early := Sim.new()
 assert(early.party_arrival() == Sim.CREAK-30)
 assert(early.options().all(func(x): return x.id != "porter"))
 print("MISSION1 ROUTE PASS: authored rescue chain, missing chatter, full Hour 6, failure privacy")
 quit()
