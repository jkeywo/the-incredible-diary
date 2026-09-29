extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Rooms = Sim.Rooms
func _initialize() -> void: call_deferred("checks")
func checks() -> void:
 assert(Sim.observation_time(Sim.POISON) == "05:15")
 assert(Sim.observation_time(Sim.END) == "05:30")
 for offset in [Vector2(0,55),Vector2(0,-55),Vector2(55,0),Vector2(-55,0)]:
  var run := Sim.new(false)
  run.s.room = "foyer"
  run.s.tick = Sim.CREAK
  run.s.flags.chandelier_warning = true
  run.s.actors = run.actor_positions()
  var guest := Rooms.point(run.s.actors.chandelier_guest.pos)
  var player: Vector2 = guest+offset
  run.s.pos = [player.x,player.y]
  assert(run.start("shove"))
  for i in 17: run.step()
  var displacement := Rooms.point(run.s.flags.shove_target)-guest
  assert(displacement.dot(-offset)>0)
  assert(Rooms.point(run.s.pos).distance_to(player+displacement)<0.01)
  assert(not Rooms.WRECKAGE.has_point(Rooms.point(run.s.pos)))
  var heard := false
  for i in 600:
   run.step()
   if run.s.dialogue.get("text","") == "Close shave": heard = true
  assert(heard)
 var tragedy := Sim.new(false)
 tragedy.s.room = "foyer"
 tragedy.s.pos = [400,480]
 while tragedy.s.tick < Sim.FALL+1100: tragedy.step()
 var mourners: Array = tragedy.s.reactions.chandelier.people
 assert(mourners.size() == 2)
 for id in mourners: assert(tragedy.s.actors[id].room == "foyer")
 while tragedy.s.tick < 7300: tragedy.step()
 assert(tragedy.s.steam_watch.phase == "body")
 tragedy.s.room = "controls"
 tragedy.s.pos = [900,450]
 tragedy.s.dialogue = {}
 tragedy.s.conversation = {}
 tragedy.step()
 assert(tragedy.s.steam_watch.commented)
 assert(tragedy.s.actors.incidental_sailor_3.room == "controls")
 tragedy.s.room = "salon"
 var heard_bore := false
 while tragedy.s.tick < Sim.END:
  tragedy.step()
  if tragedy.s.dialogue.get("text","").contains("bore"): heard_bore = true
 assert(heard_bore)
 assert(tragedy.s.reactions.poison.people.size() == 2)
 for id in mourners: assert(tragedy.s.actors[id].room == "foyer")
 var game := preload("res://mission1/play.tscn").instantiate()
 game.configure({},false)
 root.add_child(game)
 game.set_physics_process(false)
 game.enable_controls()
 game.sim = Sim.new(false)
 game.sim.s.room = "controls"
 game.sim.s.pos = [350,300]
 assert(game.sim.start("panel"))
 game.sim.s.entry = "123"
 game._refresh()
 assert(game.props.code_panel.get_node("Digits").text == "1 2 3")
 assert(game.message.text == "")
 var anchor: Vector2 = game.wheel.position
 game.sim.s.pos = [370,310]
 game._refresh()
 assert(game.wheel.position == anchor)
 await capture("machine")
 game.sim.s.code_open = false
 game.sim.s.room = "salon"
 game.sim.s.pos = [865,205]
 game.sim.s.actors.chandelier_guest = {"room":"salon","pos":[875,205],"action":"idle"}
 game.sim.s.actors.guest = {"room":"salon","pos":[930,215],"action":"idle"}
 var options: Array = game.sim.options()
 assert(options.all(func(o): return o.target == "bar"))
 game.sim.s.pos = [875,205]
 assert(game.sim.options().all(func(o): return o.target == "chandelier_guest"))
 game.sim.memory.interactions = 3
 game._refresh()
 assert(not game.help.visible)
 var saved := Sim.new(false)
 saved.restore_record({"current":tragedy.s,"history":tragedy.history,"memory":tragedy.memory})
 assert(saved.s.reactions == tragedy.s.reactions and saved.s.steam_watch == tragedy.s.steam_watch)
 game.sim.s.flags.spilled = true
 game.sim.s.room = "cabins"
 game.sim.s.pos = [580,315]
 game.sim.s.actors.guest = {"room":"cabins","pos":[580,315],"action":"idle"}
 assert(game.sim.start("apologise"))
 for i in 10: game.sim.step()
 assert(game.sim.flag("apologised") and game.sim.s.conversation.id == "spill_apology")
 assert(str(game.sim.s.conversation.lines).contains("no interest"))
 game.sim = Sim.new(false)
 game.sim.s.room = "foyer"
 game.sim.s.flags = {}
 game.sim.s.pos = [580,205]
 game._refresh()
 assert(game.props.chandelier.self_modulate.a == 0.5)
 await capture("chandelier-fade")

 game.sim.s.pos = [400,550]
 game._refresh()
 assert(game.props.chandelier.self_modulate.a == 1.0)
 await capture("player-clear")
 var button := Button.new()
 button.position = Vector2(-1000,-1000)
 root.add_child(button)
 await process_frame
 assert(button.has_meta("button_feedback"))
 button.mouse_entered.emit()
 await button.get_meta("feedback_tween").finished
 assert(button.modulate.b < 0.8)
 var feedback := root.get_node("ButtonFeedback")
 feedback.activate(button)
 assert(feedback.sound.volume_db <= -20 and feedback.sound.pitch_scale >= 0.94 and feedback.sound.pitch_scale <= 1.06)
 button.queue_free()
 game.queue_free()
 await process_frame
 print("MISSION1 ROUND4 PASS: directional shove, witnesses, body watch, schedule, panel digits, nearest targets, hint count and apology")
 quit()
func capture(label: String) -> void:
 if "--screenshots" not in OS.get_cmdline_user_args(): return
 await process_frame
 for i in 3: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/round4-"+label+".png")
