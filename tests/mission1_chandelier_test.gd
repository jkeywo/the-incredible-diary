extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
func _initialize() -> void:
 call_deferred("checks")
func checks() -> void:
 var run := Sim.new()
 run.s.room = "foyer"
 run.s.pos = [580,380]
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
 run.reset()
 run.s.tick = Sim.FALL-Sim.DROP_TICKS-1
 run.step()
 assert(run.s.flags.chandelier_drop_tick == run.s.tick and not run.flag("chandelier_fallen"))
 var fixture = preload("res://assets/props/mission_1/chandelier.tscn").instantiate()
 root.add_child(fixture)
 await process_frame
 fixture.show_at(true,0.0,-1.0,0.0)
 var hanging: Vector2 = fixture.offset
 fixture.show_at(true,0.5,-1.0,0.4)
 var halfway: Vector2 = fixture.offset
 assert(halfway.y > hanging.y and is_equal_approx(halfway.y-hanging.y,37.5))
 assert(fixture.scale == Vector2.ONE and fixture.current_state != "fallen")
 fixture.show_at(false,1.0,0.0,0.8)
 assert(is_equal_approx(fixture.offset.y-hanging.y,150.0))
 assert(fixture.current_state == "fallen" and fixture.get_node("Dust").visible)
 fixture.show_at(false,1.0,5.0,5.8)
 assert(not fixture.get_node("Dust").visible)
 fixture.show_at(true,0.5,-1.0,0.4)
 assert(fixture.offset == halfway and fixture.current_state == "warning")
 assert(not fixture.get_node("Dust").visible)
 fixture.queue_free()
 await process_frame
 print("MISSION1 CHANDELIER PASS: centre anchor, accelerating drop, impact dust, rewind,  window rescue, off-screen death privacy, continued play")
 quit()
