extends SceneTree
const Play = preload("res://mission1/play.tscn")
const Sim = preload("res://mission1/simulation.gd")
func _initialize(): call_deferred("checks")
func checks():
 var game = Play.instantiate()
 game.configure({},false)
 root.add_child(game)
 current_scene = game
 game.set_process(false)
 game.set_physics_process(false)
 game.sim.s.room = "controls"
 game.sim.s.pos = [250,400]
 game.sim.s.flags.trapped = true
 game.highlight = true
 game._refresh()
 var panel = game.props.code_panel
 for steam_off in [false,true,false]:
  game.sim.s.flags.steam_off = steam_off
  game._sync_props(game.sim.s)
  assert(panel.material.get_shader_parameter("frame_origin") == panel.region_rect.position)
 panel.material.set_shader_parameter("interaction_outline",true)
 if "--screenshots" in OS.get_cmdline_user_args():
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/controls-outline-fixed.png")
 assert(game.sim.apply_authored(preload("res://mission1/authoring_content.gd").seed(game.sim.s.actors)).ok)
 game.sim.s.room = "foyer"
 game.sim.s.pos = [580,330]
 for actor in game.sim.s.actors.values(): actor.room = "docks"
 game._refresh()
 for actor in game.actors.values(): actor.hide()
 game.actors.amelia.show()
 game._sync_prop_occlusion()
 assert(game.props.chandelier.self_modulate.a == 1.0)
 for point in [Vector2(580,330),Vector2(580,230),Vector2(580,330)]:
  game.sim.s.pos = [point.x,point.y]
  game._refresh()
  var fixture = game.props.chandelier
  assert(fixture.offset.y == -fixture.cell_size.y-fixture.HANG_HEIGHT)
  assert(fixture.self_modulate.a == (0.5 if point.y == 230 else 1.0))
  game._sync_props(game.sim.s)
  assert(fixture.self_modulate.a == (0.5 if point.y == 230 else 1.0))
  if "--screenshots" in OS.get_cmdline_user_args():
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://build/chandelier-depth-y%d.png" % int(point.y))
 if "--screenshots" in OS.get_cmdline_user_args():
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/chandelier-no-false-fade.png")
 # A large transparent animation cell must not fade unrelated scenery.
 var padded := AnimatedSprite2D.new()
 var pixels := Image.create(400,400,false,Image.FORMAT_RGBA8)
 pixels.fill(Color.TRANSPARENT)
 pixels.set_pixel(200,399,Color.WHITE)
 padded.sprite_frames = SpriteFrames.new()
 padded.sprite_frames.add_frame("default",ImageTexture.create_from_image(pixels))
 padded.offset = Vector2(0,-200)
 game.entity_layer.add_child(padded)
 padded.position = Vector2(580,330)
 game.Depth.assign(padded)
 game.Depth.sync_fade(game.props.chandelier,[padded])
 assert(game.props.chandelier.self_modulate.a == 1.0)
 padded.queue_free()
 game.sim.start_mission_two()
 game.sim.s.room = "passage"
 game._refresh()
 for actor in game.actors.values(): actor.hide()
 var player = game.actors.amelia
 player.show()
 var door = game.props.crew_cabin_middle
 assert(door.z_index == 0 and door.get_parent() == game.entity_layer)
 var jambs := 0
 for prop in game.props.values():
  if str(prop.name).begins_with("Jamb"):
   assert(prop.z_index == 0 and prop.position.y == 405)
   assert(prop.get_parent() == game.entity_layer)
   jambs += 1
 assert(jambs == 6)
 var arches := 0
 for child in game.props.values():
  if str(child.name).begins_with("Arch"):
   assert(child.z_index == game.Depth.OVERHEAD)
   arches += 1
 assert(arches == 3)
 if "--screenshots" in OS.get_cmdline_user_args():
  player.position = Vector2(580,425)
  for state in ["closed","open"]:
   door.set_state(state)
   game._sync_prop_occlusion()
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://build/crew-door-%s-depth.png" % state)
  door.set_state("closed")
 for point in [Vector2(580,425),Vector2(580,390),Vector2(450,390)]:
  player.position = point
  game._sync_prop_occlusion()
  assert(door.self_modulate.a == (0.5 if point == Vector2(580,390) else 1.0))
 # Moving art never changes its ground anchor; without overlap it does not fade.
 door.offset.y -= 2000
 player.position = Vector2(580,390)
 game._sync_prop_occlusion()
 assert(door.self_modulate.a == 1.0)
 # Depth follows the ground anchor even when the art is raised or offset.
 assert(game.Depth.behind(player,door))
 door.offset.y += 2000
 player.position = Vector2(550,390)
 var faded_jamb := false
 game._sync_prop_occlusion()
 for prop in game.props.values():
  if str(prop.name).begins_with("Jamb580") and prop.self_modulate.a == 0.5: faded_jamb = true
 assert(faded_jamb)
 player.position.y = 425
 game._sync_prop_occlusion()
 for prop in game.props.values():
  if str(prop.name).begins_with("Jamb"): assert(prop.self_modulate.a == 1.0)
 # Parent placement is included, and a higher layer alone never implies behind.
 game.entity_layer.position.y = 35
 assert(not game.Depth.behind(player,door))
 game.entity_layer.position.y = 0
 assert(game.room_slot.z_index == game.Depth.BACKGROUND)
 var wheel = game.wheel
 wheel.options = PackedStringArray(["Open door","Inspect"])
 var button = wheel.buttons[0]
 var area: Rect2 = button.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,button.size)
 var overlaps: Array[Rect2] = [Rect2(area.get_center(),Vector2(10,10))]
 wheel.set_character_bounds(overlaps)
 for state in ["normal","hover","pressed"]:
  assert(button.get_theme_stylebox(state).tint.a == 0.5)
 assert(button.self_modulate.a == 1.0)
 assert(wheel.buttons[1].get_theme_stylebox("normal").tint.a == 1.0)
 overlaps = []
 wheel.set_character_bounds(overlaps)
 assert(button.get_theme_stylebox("normal").tint.a == 1.0)
 print("PRESENTATION FIXES PASS: atlas outlines, sprite-bottom occlusion and interaction background fading")
 await preload("res://tests/shutdown.gd").finish(self)
