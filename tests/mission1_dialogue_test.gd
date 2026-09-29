extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
func _initialize() -> void: call_deferred("checks")
func checks() -> void:
 var run := Sim.new(false)
 run.step()
 assert(run.s.dialogue.speaker == "guest" and run.s.dialogue.kind == "speech")
 assert(not str(run.memory.notes).contains("Where are my bags"))
 var original: Dictionary = run.s.dialogue.duplicate(true)
 var boundary: int = run.s.dialogue.until
 while run.s.tick < boundary: run.step()
 assert(run.s.dialogue.speaker == "dock_sailor")
 assert(run.s.dialogue.text.contains("search"))
 assert(str(run.memory.notes).contains("Where are my bags"))
 assert(run.history[1].dialogue == original)
 var restored := Sim.new(false)
 restored.restore_record({"current":run.s,"memory":run.memory,"history":run.history})
 for i in 30:
  run.step()
  restored.step()
 assert(restored.s == run.s)
 run.s.room = "foyer"
 run.step()
 assert(run.s.dialogue.is_empty())
 run.reset()
 assert(run.s.dialogue.is_empty())
 run.s.pos = [145,390]
 assert(run.start("inspect_bag"))
 for i in 10: run.step()
 assert(run.s.dialogue.kind == "thought" and run.s.dialogue.speaker == "amelia")
 assert(run.s.dialogue.name == "Thought")
 # Only witnessed lines are recorded; an off-room conversation stays silent.
 var unseen := Sim.new(false)
 unseen.s.room = "foyer"
 for i in 160: unseen.step()
 assert(not str(unseen.memory.notes).contains("Where are my bags"))
 var game := preload("res://mission1/play.tscn").instantiate()
 game.sim = preload("res://mission1/simulation.gd").new(false)
 game.configure({},false)
 root.add_child(game)
 game.set_physics_process(false)
 await process_frame
 game.sim.step()
 game._refresh()
 assert(game.bubble.visible and game.bubble.message_label.visible_characters == 0)
 for i in 5: game.sim.step()
 game._refresh()
 assert(game.bubble.message_label.visible_characters == 18)
 var count: int = game.bubble.message_label.visible_characters
 game._refresh()
 assert(game.bubble.message_label.visible_characters == count)
 game.rewind_index = 1
 game._refresh()
 assert(game.bubble.message_label.visible_characters == 0)
 game.diary_open = true
 game._refresh()
 assert(not game.bubble.visible)
 game.queue_free()
 await process_frame
 print("MISSION1 DIALOGUE PASS: speakers, turn-taking, thoughts, witness privacy, save continuity, typewriter, rewind and diary")
 quit()
