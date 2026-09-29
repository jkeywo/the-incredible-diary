extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
func _initialize() -> void:
 var run := Sim.new()
 run.s.room = "foyer"
 run.s.pos = [680,440]
 run.s.tick = Sim.CREAK-1
 run.step()
 assert(run.start("shove"))
 for i in 80: run.step()
 assert(run.s.safe.has("chandelier_guest") and not run.s.dead.has("chandelier_guest"))
 run.reset()
 run.s.tick = Sim.FALL-1
 run.step()
 assert(run.s.dead.has("chandelier_guest") and run.memory.reset)
 assert(not str(run.memory.notes).contains("fell on"))
 assert(not run.s.finished)
 print("MISSION1 CHANDELIER PASS: window rescue, off-screen death privacy, continued play")
 quit()
