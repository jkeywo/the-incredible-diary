extends SceneTree
const Play = preload("res://mission1/play.tscn")
const Sim = preload("res://mission1/simulation.gd")
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
 if not ok: failures.append(label)
func _initialize() -> void:
 call_deferred("run_checks")
func run_checks() -> void:
 var game := Play.instantiate()
 game.sim = preload("res://mission1/simulation.gd").new(false)
 game.configure({},false)
 root.add_child(game)
 current_scene = game
 game.enable_controls()
 game.set_physics_process(false)
 await process_frame
 game._toggle_diary()
 var tick: int = game.sim.s.tick
 game._physics_process(1)
 check(game.sim.s.tick == tick, "diary pauses game clock")
 game._toggle_diary()
 var wait_key := InputEventKey.new()
 wait_key.physical_keycode = KEY_F
 wait_key.pressed = true
 Input.parse_input_event(wait_key)
 Input.flush_buffered_events()
 game.sim.s.tick = Sim.HOUR-5
 game._physics_process(1)
 check(game.sim.s.tick == Sim.HOUR and game.wait_latched, "accelerated wait stops at Hour boundary")
 game._physics_process(0.1)
 check(game.sim.s.tick in [Sim.HOUR+1,Sim.HOUR+2], "holding wait does not accelerate through next Hour")
 wait_key = wait_key.duplicate()
 wait_key.pressed = false
 Input.parse_input_event(wait_key)
 Input.flush_buffered_events()
 game._physics_process(0.1)
 check(not game.wait_latched, "release rearms waiting")
 paused = true
 tick = game.sim.s.tick
 game._physics_process(1)
 check(game.sim.s.tick == tick, "editor pause freezes simulation")
 paused = false
 var scenarios := [
  ["docks",[350,430],60],
  ["foyer",[580,380],Sim.CREAK],
  ["controls",[350,300],Sim.TRAP+10],
  ["cabins",[580,480],Sim.TRAP+110],
  ["passage",[580,480],Sim.TRAP+110],
  ["salon",[Sim.Rooms.BAR_GUEST.x,Sim.Rooms.BAR_GUEST.y],Sim.POISON+5]
 ]
 for item in scenarios:
  game.sim.s.room = item[0]
  game.sim.s.pos = item[1]
  game.sim.s.tick = item[2]
  game.sim.s.flags.bag_lead = true
  game.sim.s.flags.chandelier_warning = item[0] == "foyer"
  game.sim.s.flags.trapped = item[0] == "controls"
  game.sim.s.flags.party_arrived = item[0] == "salon"
  game.sim.s.flags.spiked = item[0] == "salon"
  game.sim.memory.procedure = true
  game.sim.s.actors = game.sim.actor_positions()
  game._refresh()
  if item[0] == "controls":
   game.sim.start("panel")
   for i in 3: game._choose(int(game.sim.s.code[i])-1)
   check(game.sim.s.code_open and not game.sim.flag("steam_off"), "third digit does not submit automatically")
   game._choose(7)
   check(game.sim.s.entry.is_empty(), "Clear removes entire entry")
   game._refresh()
  check(game.shown_room == item[0], "loads room "+item[0])
  check(is_equal_approx(game.watch.elapsed_seconds,float(item[2])/10), "watch follows simulation")
  await process_frame
  if "--screenshots" in OS.get_cmdline_user_args():
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://build/mission1-"+item[0]+".png")
  game.sim.s.code_open = false
 if "--screenshots" in OS.get_cmdline_user_args():
  game._toggle_diary()
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/mission1-diary.png")
  game._toggle_diary()
  var editor := root.get_node("PauseEditor")
  editor.pause(game)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/mission1-editor.png")
  editor.resume()
 game.sim.memory.reset = true
 game._begin_reset()
 check(game.rewind_index >= 0, "reset starts recorded rewind")
 game._begin_reset()
 check(game.sim.s.tick == 0 and game.sim.history.size()==1, "second reset press skips and clears leg history")
 game.queue_free()
 await process_frame
 print("MISSION1 PLAY ", JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
 quit(0 if failures.is_empty() else 1)

