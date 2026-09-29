extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Rooms = preload("res://mission1/rooms.gd")
const Play = preload("res://mission1/play.tscn")
func _initialize() -> void:
 call_deferred("checks")
func advance(run: RefCounted, target: int) -> void:
 while run.s.tick < target: run.step()
func checks() -> void:
 var run := Sim.new(false)
 assert(Rooms.exits("cabins",false).size() == 1)
 assert(Rooms.exits("salon",false).map(func(d): return d.room) == ["passage","foyer"])
 assert(Rooms.can_stand("controls",Vector2(840,360)))
 assert(not Rooms.can_stand("controls",Vector2(590,360)))
 # Found luggage is a prerequisite for boarding, and hiding ends at recovery.
 run.s.pos = [145,390]
 assert(run.start("hide_bag"))
 advance(run,21)
 assert(run.flag("bag_hidden"))
 advance(run,Sim.HOUR-81)
 assert(run.actor_positions().guest.room == "docks" and not run.flag("bag_found"))
 run.step()
 assert(run.flag("bag_found") and not run.flag("bag_hidden") and run.luggage_delayed())
 assert(run.party_arrival() == 3*Sim.HOUR+300)
 advance(run,Sim.HOUR)
 assert(run.actor_positions().guest.room == "foyer")
 run.reset()
 assert(run.memory.notes.is_empty())
 run.s.pos = [145,390]
 assert(run.start("retrieve_bag"))
 advance(run,10)
 assert(run.flag("bag_found") and run.boarding_time() < 800)
 advance(run,run.boarding_time())
 assert(run.actor_positions().guest.room == "foyer")
 # Each cabin is accessible only with its own door open, from either side.
 for id in Rooms.CABIN_DOORS:
  run.reset()
  run.s.room = "cabins"
  run.s.pos = [Rooms.CABIN_DOORS[id],450]
  for i in 5: run.step(Vector2.UP)
  assert(float(run.s.pos[1]) >= 440)
  assert(run.start(id))
  advance(run,int(run.s.tick)+10)
  for i in 7: run.step(Vector2.UP)
  assert(float(run.s.pos[1]) < 370)
  assert(run.start(id))
  advance(run,int(run.s.tick)+10)
  for i in 9: run.step(Vector2.DOWN)
  assert(float(run.s.pos[1]) < 370)
 # Unwitnessed death is absent; later inspection records present evidence only.
 run.reset()
 run.s.tick = Sim.FALL-1
 run.step()
 assert(not str(run.memory.notes).contains("death") and not str(run.memory.notes).contains("fell"))
 run.s.room = "foyer"
 run.s.pos = [580,380]
 run.step()
 assert(run.start("wreckage"))
 advance(run,int(run.s.tick)+10)
 assert(run.s.dialogue.kind == "thought" and run.s.dialogue.text == "Broken glass and a snapped suspension pin.")
 assert(str(run.memory.notes).contains("03:19") and not str(run.memory.notes).contains("Loop"))
 run.reset()
 assert(run.memory.notes.is_empty())
 run.s.tick = 30
 run.note("legacy", "I saw the suitcase.")
 run.history.append(run.s.duplicate(true))
 run.memory.notes = ["Loop %d · Hour 1 — I saw the suitcase." % (int(run.s.loop)+1), "Loop 1 · Hour 1 — An earlier voyage.", "Hour 3 — The diary records an unseen death."]
 run.restore_record({"current":run.s,"memory":run.memory,"history":run.history})
 assert(run.memory.notes == ["01:01 — I saw the suitcase."])
 var game := Play.instantiate()
 game.sim = preload("res://mission1/simulation.gd").new(false)
 game.configure({},false)
 root.add_child(game)
 game.set_physics_process(false)
 await process_frame
 assert(game.actors.crew.character_id == "sailor" and game.actors.dock_sailor.character_id == "sailor")
 assert(game.heading.text.begins_with("All Aboard"))
 assert(game.wheel.get_script() == load("res://assets/ui/mission_1/action_wheel.gd"))
 game.actors.guest.play_action("poison_collapse","down")
 await create_timer(0.9).timeout
 var actor: AnimatedSprite2D = game.actors.guest
 assert(not actor.is_playing() and actor.frame == 3)
 actor.play_action("poison_collapse","down")
 assert(not actor.is_playing() and actor.frame == 3)
 actor.play_action("walk","right")
 actor.set_frame_and_progress(2,0.5)
 actor.play_action("walk","right")
 assert(actor.frame == 2 and is_equal_approx(actor.frame_progress,0.5))
 assert(actor.sprite_frames.get_frame_count("idle_down") == 2)
 # Linear interpolation retains a constant displacement per render interval.
 game.enable_controls()
 game.sim.step(Vector2.RIGHT)
 game.accumulator = 0.025
 var first: Vector2 = game._display_position(game.sim.s,"amelia",Rooms.point(game.sim.s.pos))
 game.accumulator = 0.05
 var middle: Vector2 = game._display_position(game.sim.s,"amelia",Rooms.point(game.sim.s.pos))
 game.accumulator = 0.075
 var last: Vector2 = game._display_position(game.sim.s,"amelia",Rooms.point(game.sim.s.pos))
 assert((middle-first).is_equal_approx(last-middle) and is_equal_approx((middle-first).x,3.5))
 game.queue_free()
 await process_frame
 print("MISSION1 REVISION PASS: layout, luggage, cabin collisions, witness diary, sprites, animation and constant movement")
 quit()
