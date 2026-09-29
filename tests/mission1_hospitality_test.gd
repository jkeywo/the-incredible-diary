extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Duties = preload("res://mission1/hospitality.gd")
const Save = preload("res://mission1/save.gd")
const PATH := "res://build/hospitality-test.journal"
func _initialize() -> void: call_deferred("checks")

func act(run, id: String) -> void:
 assert(run.start(id), "Unavailable action: "+id)
 for i in 10: run.step()

func near_guest(run, id: String) -> void:
 var actor: Dictionary = run.s.actors[id]
 run.s.room = actor.room
 run.s.pos = [actor.pos[0]+40,actor.pos[1]]
 run.s.conversation = {}
 run.s.dialogue = {}

func round_trip(run) -> void:
 Save.clear(PATH)
 assert(Save.new().save_run(run,PATH).ok)
 var loaded := Save.load_saved(PATH)
 assert(loaded.ok)
 assert(loaded.data.current == JSON.parse_string(JSON.stringify(run.s)))
 var restored := Sim.new()
 restored.s = loaded.data.current
 restored.memory = loaded.data.memory
 restored.history = loaded.data.history
 for i in 5:
  run.step()
  restored.step()
 assert(JSON.parse_string(JSON.stringify(run.s)) == JSON.parse_string(JSON.stringify(restored.s)))
 Save.clear(PATH)

func checks() -> void:
 var run := Sim.new()
 for i in 30: run.step(Vector2.LEFT)
 assert(run.s.tick == 0 and run.s.frame == 30 and run.history.size() == 31)
 assert(run.s.actors.keys() == ["captain"] and run.s.flags.size() == 1)
 assert(run.s.pos != [580.0,490.0])
 round_trip(run)
 run.s.pos = [610,310]
 assert(run.start("report"))
 assert(run.s.dialogue.speaker == "captain")
 round_trip(run)
 for i in 800:
  if not run.tutorial_active(): break
  run.step()
 assert(not run.tutorial_active() and run.s.tick == 0)
 assert(str(run.memory.notes).contains("Boy:") and not str(run.memory.notes).contains("Amelia"))
 var frozen_frames: int = run.s.frame
 round_trip(run)
 for i in 100: run.step()
 assert(run.s.tick == 105 and run.s.frame == frozen_frames+105)
 assert(not run.s.actors.has("captain") and run.s.actors.has("chatterbox"))
 assert(run.s.actors.guest.pos[0] < 500)
 run.reset()
 assert(not run.tutorial_active() and run.s.tick == 0 and run.s.frame == 0)

 # Cabins are learned by inspecting real doors, open or closed.
 run = Sim.new(false)
 run.s.room = "cabins"
 for door in Sim.Rooms.CABIN_DOORS:
  run.s.pos = [Sim.Rooms.CABIN_DOORS[door],465]
  act(run,"plate:"+door)
 assert(run.memory.cabins.size() == 3)
 assert(run.s.dialogue.kind == "thought")
 run.s.flags.cabin_middle = true
 run.s.pos = [580,465]
 act(run,"plate:cabin_middle")
 assert(run.memory.cabins.size() == 3)

 # One rejected drink, then a successful correction for every guest.
 for id in Duties.GUESTS:
  near_guest(run,id)
  act(run,"request:"+id)
  assert(run.memory.preferences.has(id))
  run.s.room = "foyer"
  run.s.pos = [860,585]
  var wrong := "tea" if Duties.GUESTS[id].drink != "tea" else "water"
  act(run,"collect:"+wrong)
  round_trip(run)
  near_guest(run,id)
  act(run,"serve:"+id)
  assert(run.s.hospitality.carried == wrong)
  assert(run.s.hospitality.outcomes[id].wrong_drink)
  assert(run.s.dialogue.text == Duties.GUESTS[id].wrong)
  assert(not run.start("serve:"+id))
  round_trip(run)
  run.s.room = "foyer"
  run.s.pos = [860,585]
  act(run,"return_drink")
  act(run,"collect:"+Duties.GUESTS[id].drink)
  near_guest(run,id)
  act(run,"serve:"+id)
  assert(run.s.hospitality.carried == "" and run.s.hospitality.outcomes[id].served)
 assert(not run.flag("spilled") and not run.flag("spiked"))
 run.reset()
 assert(run.memory.preferences.size() == 3 and run.memory.cabins.size() == 3)
 assert(run.s.hospitality.outcomes.is_empty() and run.s.hospitality.carried == "")

 # A visible wrong-door visit fits before the next anchored departure.
 run = Sim.new(false)
 run.s.room = "cabins"
 run.s.pos = [400,550]
 for i in 420: run.step()
 run.memory.cabins = ["cabin_left","cabin_middle","cabin_right"]
 near_guest(run,"chandelier_guest")
 assert(run.start("directions:chandelier_guest"))
 act(run,"direct:chandelier_guest:cabin_middle")
 assert(run.s.hospitality.detours.has("chandelier_guest"))
 round_trip(run)
 var reacted := false
 var reached := false
 run.s.pos = [400,530]
 for i in 300:
  var before: Dictionary = run.s.actors.chandelier_guest.duplicate(true)
  run.step()
  var actor: Dictionary = run.s.actors.chandelier_guest
  if before.room == actor.room:
   assert(Sim.Rooms.point(before.pos).distance_to(Sim.Rooms.point(actor.pos)) <= 10.01)
  if actor.room == "cabins" and Sim.Rooms.point(actor.pos).distance_to(Vector2(580,465)) < 12: reached = true
  if run.s.dialogue.get("text","").contains("Harcourt"): reacted = true
  if run.s.hospitality.detours.is_empty(): break
 assert(reached and reacted and run.s.hospitality.detours.is_empty())
 assert(run.s.tick < 850)
 near_guest(run,"chandelier_guest")
 assert(run.start("directions:chandelier_guest"))
 assert(not run.start("direct:chandelier_guest:cabin_right"))
 act(run,"direct:chandelier_guest:cabin_left")
 assert(run.s.hospitality.outcomes.chandelier_guest.directed)
 run.s.tick = 840
 assert(Duties.detour_plan(run,"chatterbox","cabin_left").is_empty())

 # All guests recover their authored appointments after a wrong direction.
 for item in [["chandelier_guest",420,"cabin_middle"],["chatterbox",550,"cabin_middle"],["guest",1500,"cabin_left"]]:
  var diverted := Sim.new(false)
  diverted.s.room = "passage"
  diverted.s.pos = [400,480]
  while diverted.s.tick < item[1]: diverted.step()
  diverted.memory.cabins = ["cabin_left","cabin_middle","cabin_right"]
  near_guest(diverted,item[0])
  var baseline := Sim.new(false)
  baseline.s = diverted.s.duplicate(true)
  baseline.memory = diverted.memory.duplicate(true)
  baseline.history = diverted.history.duplicate(true)
  var deadline := Sim.Routines.next_commitment(item[0], int(diverted.s.tick), diverted.boarding_time(), diverted.party_arrival(), diverted.s.flags)
  assert(diverted.start("directions:"+item[0]))
  assert(diverted.start("direct:%s:%s" % [item[0],item[2]]))
  diverted.s.room = "passage"
  diverted.s.pos = [400,480]
  baseline.s.room = "passage"
  baseline.s.pos = [400,480]
  while diverted.s.tick < deadline+100:
   diverted.step()
   baseline.step()
  assert(diverted.s.hospitality.detours.is_empty())
  assert(diverted.s.actors == baseline.s.actors)
  assert(diverted.party_arrival() == baseline.party_arrival() and diverted.s.dead == baseline.s.dead)

 # A guest unable to make progress abandons the detour early, without warping.
 var blocked := Sim.new(false)
 blocked.s.room = "passage"
 blocked.s.pos = [400,480]
 for i in 420: blocked.step()
 blocked.memory.cabins = ["cabin_middle"]
 near_guest(blocked,"chandelier_guest")
 assert(blocked.start("directions:chandelier_guest"))
 assert(blocked.start("direct:chandelier_guest:cabin_middle"))
 var trip: Dictionary = blocked.s.hospitality.detours.chandelier_guest
 # Hold the resolved pose as if the corridor were obstructed.
 var initial_pose: Dictionary = blocked.s.actors.chandelier_guest.duplicate(true)
 trip.home.pos = [300,315]
 for i in 20:
  blocked.s.tick += 1
  Duties.update(blocked)
 assert(trip.phase == "return" and blocked.s.actors.chandelier_guest == initial_pose)

 # At a rescue commitment no hospitality option can interrupt the guest.
 blocked.s.flags.chandelier_warning = true
 blocked.s.tick = Sim.CREAK
 blocked.s.hospitality.menu = ""
 for choice in blocked.options(false):
  assert(not str(choice.id).ends_with(":chandelier_guest"))

 # Legacy journals are migrated without inventing historical actor positions.
 var old := Sim.new(false)
 for i in 8: old.step()
 var legacy_history := old.history.duplicate(true)
 for frame in legacy_history:
  for key in ["frame","tutorial","arrivals","hospitality"]: frame.erase(key)
 var batch := {"schema":2,"sequence":1,"loop":0,"start":0,"history":legacy_history,"current":legacy_history[-1],"memory":old.memory}
 var body := JSON.stringify(batch)
 var file := FileAccess.open(PATH,FileAccess.WRITE)
 file.store_line(JSON.stringify({"body":body,"sha256":body.sha256_text()}))
 file.close()
 var legacy := Save.load_saved(PATH)
 assert(legacy.ok and legacy.data.current.frame == 8 and legacy.data.current.tutorial == "done")
 assert(legacy.data.history[3].actors == JSON.parse_string(JSON.stringify(old.history[3].actors)))
 Save.clear(PATH)

 var game := preload("res://mission1/play.tscn").instantiate()
 game.configure({},false)
 root.add_child(game)
 game.set_physics_process(false)
 game.enable_controls()
 await process_frame
 assert(game.movement_prompt.visible and game.help.text.contains("Report"))
 assert(game.actors.captain.visible and not game.actors.guest.visible)
 for facing in ["down","left","up","right"]:
  for action in ["idle","walk","talk"]:
   assert(game.actors.captain.sprite_frames.has_animation(action+"_"+facing))
 if "--screenshots" in OS.get_cmdline_user_args():
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/tutorial-docks.png")
 game.sim.s.pos = [610,310]
 game._refresh()
 assert(not game.movement_prompt.visible and game.help.text.contains("Press 1"))
 game.using_controller = true
 game._refresh()
 assert(game.help.text.contains("RB"))
 game.sim.start("report")
 for i in 18: game.sim.step()
 game._refresh()
 assert(game.bubble.visible and game.sim.s.tick == 0)
 if "--screenshots" in OS.get_cmdline_user_args():
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/tutorial-captain.png")
 for i in 200:
  if game.sim.s.dialogue.get("text","").begins_with("Explore"): break
  game.sim.step()
 for i in 40: game.sim.step()
 game._refresh()
 assert(game.bubble.bubble_size.y > 154)
 if "--screenshots" in OS.get_cmdline_user_args():
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/tutorial-briefing.png")
 game.sim.reset()
 game.sim.s.room = "cabins"
 game.sim.s.pos = [580,470]
 game._refresh()
 if "--screenshots" in OS.get_cmdline_user_args():
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/tutorial-nameplates.png")
 game.sim.s.room = "foyer"
 game.sim.s.pos = [860,590]
 game._refresh()
 if "--screenshots" in OS.get_cmdline_user_args():
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/tutorial-refreshments.png")
 game.queue_free()
 await process_frame
 print("MISSION1 HOSPITALITY PASS: frozen tutorial, arrivals, saved frames, drinks, mischief, detours, names, legacy journals and contextual UI")
 quit()
