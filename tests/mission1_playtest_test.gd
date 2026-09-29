extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Rooms = Sim.Rooms

func _initialize() -> void: call_deferred("checks")

func checks() -> void:
 var run := Sim.new(false)
 run.s.pos = [145,390]
 assert(run.start("retrieve_bag"))
 for i in 10: run.step()
 assert(run.flag("bag_retrieved_by_boy") and not run.flag("sailor_thanked"))
 run.s.pos = [470,470]
 for i in 220: run.step()
 assert(run.flag("sailor_thanked"))
 assert(run.s.observed.has("sailor_thanks"))
 var Save = preload("res://mission1/save.gd")
 const SAVE_PATH := "res://build/playtest-thanks.journal"
 Save.clear(SAVE_PATH)
 assert(Save.new().save_run(run,SAVE_PATH).ok)
 var loaded := Save.load_saved(SAVE_PATH)
 assert(loaded.ok)
 var history_before: Array = loaded.data.history.duplicate(true)
 Save.new().restore_run(run,loaded.data)
 assert(run.history == history_before and run.events.is_empty())
 Save.clear(SAVE_PATH)
 run.s.dialogue = {}
 run.s.conversation = {}
 run.step()
 assert(run.s.dialogue.is_empty())
 run.reset()
 assert(not run.flag("sailor_thanked") and not run.flag("bag_retrieved_by_boy"))
 for i in 800: run.step()
 run.s.pos = [470,470]
 for i in 100: run.step()
 assert(not run.flag("sailor_thanked"))

 for hour in range(1,5):
  var clock_run := Sim.new(false)
  clock_run.s.tick = hour*Sim.HOUR-1
  clock_run.step()
  assert(clock_run.events.filter(func(e): return e.kind == "sound" and e.text == "hour_chime").size() == 1)
  if not clock_run.s.finished:
   clock_run.step()
   assert(clock_run.events.filter(func(e): return e.kind == "sound" and e.text == "hour_chime").is_empty())

 var panel := Sim.new(false)
 panel.s.room = "controls"
 panel.s.pos = [350,300]
 assert(not panel.memory.procedure and panel.start("panel"))
 panel.s.entry = "111" if panel.s.code != "111" else "222"
 assert(not panel.submit_code())
 panel.s.entry = panel.s.code
 assert(panel.submit_code())
 var blocked := {"trapped":true,"steam_off":false}
 assert(not Rooms.can_stand("controls",Vector2(1040,635),blocked))
 assert(Rooms.can_stand("controls",Vector2(350,300),blocked))
 assert(Rooms.can_stand("controls",Vector2(1040,635),{"trapped":true,"steam_off":true}))
 panel.s.room = "passage"
 panel.s.pos = [1090,480]
 panel.s.flags = blocked
 panel.step(Vector2.RIGHT)
 assert(panel.s.room == "passage")

 # Both ends of the gangway work outside the former 24-pixel circular trigger.
 for x in [532,625]:
  var crossing := Sim.new(false)
  crossing.s.pos = [x,140]
  for i in 3: crossing.step(Vector2.UP)
  assert(crossing.s.room == "foyer")
 var wall := Sim.new(false)
 wall.s.pos = [500,245]
 for i in 15: wall.step(Vector2.UP)
 assert(wall.s.room == "docks")

 var game := preload("res://mission1/play.tscn").instantiate()
 game.configure({},false)
 root.add_child(game)
 game.set_physics_process(false)
 game.enable_controls()
 game.sim = Sim.new(false)
 game.sim.s.room = "salon"
 game.sim.s.pos = [865,235]
 game.sim.s.tick = 4102
 game.sim.s.flags.party_arrived = true
 game.sim.s.flags.spiked = true
 game.sim.s.flags.spike_tick = 4100
 game.sim.s.actors = game.sim.actor_positions()
 game._refresh()
 assert(game.props.drink.position == Rooms.BAR_GLASS)
 assert(game.props.drink.get_node("SpikingHand").visible)
 var hand_frame: int = game.props.drink.get_node("SpikingHand").frame
 game.sim.s.tick = 4110
 game._refresh()
 assert(not game.props.drink.get_node("SpikingHand").visible)
 game.sim.s.tick = 4102
 game._refresh()
 assert(game.props.drink.get_node("SpikingHand").frame == hand_frame)
 await capture("salon-spiking")
 game.sim.s.room = "controls"
 game.sim.s.pos = [350,350]
 game.sim.s.flags.trapped = true
 game.sim.s.tick = Sim.TRAP+10
 game.sim.s.actors = game.sim.actor_positions()
 game._refresh()
 assert(game.props.room_steam.visible)
 await capture("steam-blocked")
 game.sim.s.flags.steam_off = true
 game._refresh()
 assert(not game.props.room_steam.visible)
 var audience := Sim.new(false)
 audience.s.room = "controls"
 audience.s.pos = [350,470]
 while audience.s.tick < Sim.DEMO_START: audience.step()
 for id in ["incidental_sailor_1","incidental_sailor_2"]:
  assert(audience.s.actors.has(id) and audience.s.actors[id].room == "controls")
  assert(Rooms.point(audience.s.actors[id].pos).distance_to(Vector2(310,305)) < 150)
 game.sim = audience
 game._refresh()
 await capture("demo-audience")
 game.sim.s.room = "cabins"
 game.sim.s.pos = [580,480]
 game.highlight = true
 game._refresh()
 await capture("cabins-exits")
 game.queue_free()
 await process_frame
 print("MISSION1 PLAYTEST PASS: automatic thanks, chime boundaries, free code entry, steam blocking, wide exits and recorded effects")
 quit()

func capture(label: String) -> void:
 if "--screenshots" not in OS.get_cmdline_user_args(): return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/playtest-"+label+".png")

