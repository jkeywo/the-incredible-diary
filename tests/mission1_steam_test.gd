extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
func _initialize() -> void:
 var run := Sim.new()
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
 run.s.tick = Sim.TRAP-1
 run.step()
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
 var late := Sim.new()
 late.s.tick = Sim.DEMO_END-95
 for i in 66: late.step()
 late.s.room = "controls"
 late.s.pos = [350,300]
 for i in 30: late.step()
 assert(not late.memory.procedure and late.s.flags.has("known_code"))
 print("MISSION1 STEAM PASS: procedure, late lines, code retry, early restoration, rescue, reset")
 quit()
