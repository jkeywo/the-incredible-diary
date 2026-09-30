extends SceneTree
const Play = preload("res://mission1/play.tscn")
const Sim = preload("res://mission1/simulation.gd")

func _initialize() -> void: call_deferred("checks")

func checks() -> void:
 var run := Sim.new(false)
 run.start_mission_two()
 var game = Play.instantiate()
 game.configure({"current":run.s,"memory":run.memory,"history":run.history,"authored_content":run.authored_content,"content_versions":run.content_versions},false)
 root.add_child(game)
 current_scene = game
 game.enable_controls()
 game.set_process(false)
 game.set_physics_process(false)
 assert(game.sim.exploration())
 assert(game.heading.text.begins_with("Mission 2"))
 for room in ["passage","foredeck","salon","foyer","controls","cabins"]:
  game.sim.s.room = room
  game.sim.s.pos = [205,275] if room == "passage" else [600,420]
  game._refresh()
  if room == "foyer":
   assert(game.props.chandelier.current_state == "fallen")
   assert(not game.props.chandelier.get_node("Dust").visible)
   assert(game.props.janitor.position == Vector2(675,385))
   game.props.janitor.show_at(0.0)
   assert(game.props.janitor.current_frame == 0)
   game.props.janitor.show_at(0.3)
   assert(game.props.janitor.current_frame == 1)
   game._refresh()
  await process_frame
  await process_frame
  if "--screenshots" in OS.get_cmdline_user_args():
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://build/mission2-%s.png" % room)
 game.sim.s.finished = true
 game.sim.s.tick = 10800
 game._refresh()
 assert(game.diary_title.text == "SCHEDULE COMPLETE")
 assert(not game.diary_reset.visible and game.diary_next.visible)
 assert(game.diary_menu.visible and not game.ending.active())
 game.queue_free()
 await process_frame
 var first = Play.instantiate()
 first.sim = Sim.new(false)
 first.configure({},false)
 root.add_child(first)
 current_scene = first
 first.enable_controls()
 first.set_process(false)
 first.set_physics_process(false)
 first.sim.s.room = "controls"
 first.sim.s.pos = [840,400]
 first.sim.s.flags.trapped = true
 first._refresh()
 assert(first.props.steam_vent.position == Vector2(940,290))
 assert(first.props.room_steam.active)
 if "--screenshots" in OS.get_cmdline_user_args():
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/mission1-relocated-steam.png")
 for room in ["passage","salon"]:
  first.sim.s.room = room
  first.sim.s.pos = [580,480]
  first._refresh()
  await process_frame
  if "--screenshots" in OS.get_cmdline_user_args():
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://build/mission1-revised-%s.png" % room)
 print("MISSION2 PRESENTATION PASS: rooms, HUD and neutral schedule ending")
 quit()
