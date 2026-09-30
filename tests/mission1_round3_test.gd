extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
func _initialize() -> void: call_deferred("checks")
func checks() -> void:
 var run := Sim.new(false)
 var start := Sim.Rooms.point(run.s.pos)
 run.step(Vector2.DOWN)
 run.step(Vector2.DOWN)
 assert(run.s.tick == 3 and run.s.frame == 2)
 assert(Sim.Rooms.point(run.s.pos).distance_to(start) == 28)
 var old: String = run.s.code
 for i in 12:
  run.reset()
  assert(run.s.code != old)
  old = run.s.code
 run.s.room = "foyer"
 run.s.pos = [580,420]
 run.s.tick = Sim.CREAK
 run.s.flags.chandelier_warning = true
 run.s.actors = run.actor_positions()
 assert(run.start("shove"))
 for i in 10: run.step()
 assert(run.s.safe.has("chandelier_guest"))
 assert(run.s.flags.has("chandelier_drop_tick") and not run.flag("chandelier_fallen"))
 for i in 8: run.step()
 assert(run.flag("chandelier_fallen") and run.s.tick < Sim.FALL)
 var game := preload("res://mission1/play.tscn").instantiate()
 game.configure({},false)
 root.add_child(game)
 game.set_physics_process(false)
 game.enable_controls()
 game.sim = Sim.new(false)
 game.sim.s.room = "controls"
 game._refresh()
 assert(game.props.code_panel.current_state == "accepted")
 game.sim.s.flags.steam_off = true
 game._refresh()
 assert(game.props.code_panel.current_state == "rejected")
 game.sim.s.room = "salon"
 game.sim.s.flags.party_arrived = true
 game.sim.s.flags.spiked = true
 game.sim.s.actors.guest = {"room":"salon","pos":[950,215],"action":"idle"}
 game.sim.s.flags.spike_tick = 0
 game.sim.s.flags.spike_frame = 0
 game.sim.s.frame = 3
 game._refresh()
 await capture("hand-flowers")
 game.sim._complete_rescue("bump")
 game._refresh()
 assert(game.props.drink.position == Vector2(978,223))
 assert(game.props.drink.current_state == "spilled" and game.props.drink.visible)
 assert(game.props.bar_pillar.z_index > game.props.drink.z_index)
 Sim.Conversations.say(game.sim,"guest","These flowers smell lovely.")
 game._refresh()
 await capture("speech-tail")
 var offset: Vector2 = game.bubble.position-game.actors.guest.position
 game.sim.s.pos = [950,260]
 game._refresh()
 assert(game.bubble.position-game.actors.guest.position == offset)
 game.sim.s.actors.guest.pos = [930,215]
 game._refresh()
 assert(game.bubble.position-game.actors.guest.position == offset)
 for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
  game.bubble.point_tail_at(game.bubble.size/2+direction*1000)
  assert(game.bubble.tail_geometry()[1] == direction)
 game.sim.s.tick = Sim.END-1
 game.sim.s.dead = ["chandelier_guest"]
 game.sim.step()
 game._refresh()
 assert(game.ending.active() and not game.diary.visible)
 if not game.cut_fade_phase.is_empty():
  game._advance_cut_fade(game.CUT_FADE_SECONDS)
  game._advance_cut_fade(game.CUT_FADE_SECONDS)
 game.ending.advance(8.0)
 game._refresh()
 game.diary_presentation.advance(0.3)
 assert(game.diary.visible and game.diary_reset.visible and not game.diary_next.visible)
 assert(game.diary_text.text.contains("5:30") and game.diary_menu.visible)
 await capture("defeat")
 game.sim.s.dead.clear()
 game.ending.clear()
 game.end_presented = false
 game._refresh()
 if not game.cut_fade_phase.is_empty():
  game._advance_cut_fade(game.CUT_FADE_SECONDS)
  game._advance_cut_fade(game.CUT_FADE_SECONDS)
 game.ending.advance(8.0)
 game._refresh()
 assert(game.diary_next.visible and not game.diary_reset.visible)
 assert(game.diary_next.text == "Turn the Page")
 await capture("victory")
 game.queue_free()
 await process_frame
 print("MISSION1 ROUND3 PASS: clock, movement, random codes, early fall, pressure colours, floor spill, bubble offset, tails and end screens")
 await preload("res://tests/shutdown.gd").finish(self)
func capture(label: String) -> void:
 if "--screenshots" not in OS.get_cmdline_user_args(): return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/round3-"+label+".png")
