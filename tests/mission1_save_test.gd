extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Save = preload("res://mission1/save.gd")
const PATH := "res://build/mission1-test.journal"
func _initialize() -> void:
 Save.clear(PATH)
 var run := Sim.new()
 var writer := Save.new()
 for i in 70: run.step(Vector2.LEFT)
 assert(writer.save_run(run,PATH).ok)
 for i in 5: run.step(Vector2.DOWN)
 run.s.entry = "123"
 assert(writer.save_run(run,PATH).ok)
 var loaded := Save.load_saved(PATH)
 assert(loaded.ok and loaded.data.history.size()==76)
 assert(loaded.data.current == JSON.parse_string(JSON.stringify(run.s)))
 assert(loaded.data.history[20] == JSON.parse_string(JSON.stringify(run.history[20])))
 var file := FileAccess.open(PATH,FileAccess.READ_WRITE)
 file.seek_end()
 file.store_string("interrupted transaction")
 file.close()
 loaded = Save.load_saved(PATH)
 assert(loaded.ok and loaded.data.current.tick==75)
 var resumed := Sim.new()
 resumed.s = loaded.data.current
 resumed.history = loaded.data.history
 resumed.memory = loaded.data.memory
 for i in 15:
  run.step(Vector2.RIGHT)
  resumed.step(Vector2.RIGHT)
 assert(JSON.parse_string(JSON.stringify(run.s)) == JSON.parse_string(JSON.stringify(resumed.s)))
 var repair := Save.new()
 repair.sequence = int(loaded.data.sequence)
 resumed.step()
 assert(repair.save_run(resumed,PATH).ok)
 assert(Save.load_saved(PATH).data.current.tick == 91)
 resumed.memory.reset = true
 resumed.reset()
 assert(repair.save_run(resumed,PATH).ok)
 loaded = Save.load_saved(PATH)
 assert(loaded.data.current.loop == 1 and loaded.data.current.tick==0 and loaded.data.history.size()==1)
 assert(loaded.data.memory.reset)
 Save.clear(PATH)
 print("MISSION1 SAVE PASS: exact current/history, corrupt-tail recovery, new-loop ordering")
 quit()
