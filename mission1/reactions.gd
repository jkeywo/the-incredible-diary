extends RefCounted
const Rooms = preload("res://mission1/rooms.gd")
const Routes = preload("res://mission1/routines.gd")
const Speech = preload("res://mission1/conversations.gd")
const WATCHER := "incidental_sailor_3"

static func update(run) -> void:
 if not run.s.has("reactions"): run.s.reactions = {}
 if run.flag("chandelier_fallen"):
  var survived: bool = run.s.safe.has("chandelier_guest")
  gather(run,"chandelier","foyer",Rooms.point(run.s.flags.get("shove_target",[580,412])) if survived else Rooms.CHANDELIER_GUEST,1 if survived else 2,survived)
 if run.s.dead.has("guest"):
  gather(run,"poison","salon",Rooms.point(run.s.actors.guest.pos),2,false)
 for key in run.s.reactions:
  var reaction: Dictionary = run.s.reactions[key]
  if reaction.get("done",false): continue
  var ready := true
  for id in reaction.people:
   var actor: Dictionary = run.s.actors.get(id,{})
   if actor.is_empty() or actor.room != reaction.room or Rooms.point(actor.pos).distance_to(Rooms.point(reaction.targets[id]))>20: ready = false
  var conversation_id := "reaction_"+str(key)
  if ready and run.s.room == reaction.room and run.s.dialogue.is_empty() and run.s.get("conversation",{}).is_empty():
   var lines := []
   if reaction.success:
    lines = [[reaction.people[0],"Close shave"]]
   elif key == "chandelier":
    lines = [[reaction.people[0],"Oh, how dreadful. That poor woman."],[reaction.people[1],"She was standing here a moment ago. Someone must fetch the captain."]]
   else:
    lines = [[reaction.people[0],"He's dead! What a terrible end to the party."],[reaction.people[1],"He was rather a bore. Still, nobody deserves this."]]
   Speech.start(run,conversation_id,lines,reaction.people)
  if reaction.success and run.s.get("conversations_seen",[]).has(conversation_id) and run.s.get("conversation",{}).get("id","") != conversation_id and run.s.dialogue.is_empty(): reaction.done = true
 update_watch(run)

static func gather(run, key: String, room: String, point: Vector2, count: int, success: bool) -> void:
 if run.s.reactions.has(key): return
 var candidates := []
 for id in Routes.INCIDENTAL_SKINS:
  if not id.begins_with("incidental_guest"): continue
  var reserved := false
  for reaction in run.s.reactions.values():
   if not reaction.get("done",false) and reaction.people.has(id): reserved = true
  if not reserved: candidates.append(id)
 candidates.sort_custom(func(a,b): return distance(run,a,room,point)<distance(run,b,room,point))
 var people := candidates.slice(0,count)
 var targets := {}
 for i in people.size():
  var target := point+Vector2(-85 if i == 0 else 85,40)
  target = run.Crowd.free_near(room,target,run.s.flags,run.s.actors)
  targets[people[i]] = [target.x,target.y]
 run.s.reactions[key] = {"room":room,"people":people,"targets":targets,"success":success,"done":false}

static func distance(run, id: String, room: String, point: Vector2) -> float:
 var actor: Dictionary = run.s.actors.get(id,{})
 if actor.is_empty(): return 100000
 return Rooms.point(actor.pos).distance_to(point)+(0 if actor.room == room else 10000)

static func update_watch(run) -> void:
 if not run.s.has("steam_watch"): run.s.steam_watch = {"next":run.HOUR,"phase":"away","until":0,"commented":false}
 var watch: Dictionary = run.s.steam_watch
 var passenger: Dictionary = run.s.actors.get("chatterbox",{})
 var occupied: bool = not run.s.dead.has("chatterbox") and passenger.get("room","") == "controls" and Rooms.point(passenger.pos).x>600
 if occupied and watch.phase != "body":
  watch.phase = "away"
  watch.next = (int(run.s.tick/run.HOUR)+1)*run.HOUR
  return
 var actor: Dictionary = run.s.actors.get(WATCHER,{})
 if watch.phase == "away":
  var travel := Routes.duration(Routes.path(actor.get("room","cabins"),Rooms.point(actor.get("pos",[-25,530])),"controls",Vector2(890,400)))
  if run.s.tick >= watch.next-travel: watch.phase = "visit"
 if actor.get("room","") == "controls" and Rooms.point(actor.pos).distance_to(Vector2(890,400))<24:
  if run.s.dead.has("chatterbox"): watch.phase = "body"
  elif watch.phase == "visit" and run.s.tick >= watch.next:
   watch.phase = "linger"
   watch.until = run.s.frame+40
 if watch.phase == "linger" and run.s.frame >= watch.until:
  watch.phase = "away"
  watch.next = (int(run.s.tick/run.HOUR)+1)*run.HOUR
 if watch.phase == "body" and not watch.commented and run.s.room == "controls" and run.s.dialogue.is_empty() and run.s.get("conversation",{}).is_empty():
  Speech.say(run,WATCHER,"She's dead. I'll stay with her until help arrives.","speech","steam_body_found")
  watch.commented = true

static func apply_routes(run, planned: Dictionary) -> void:
 for reaction in run.s.get("reactions",{}).values():
  if reaction.get("done",false): continue
  for id in reaction.people:
   planned[id] = pose(run,id,reaction.room,reaction.targets[id])
 var watch: Dictionary = run.s.get("steam_watch",{})
 if not watch.is_empty() and watch.phase != "away":
  planned[WATCHER] = pose(run,WATCHER,"controls",[890,400])
  # Trained crew can cross the steam obstruction to inspect the compartment.
  planned[WATCHER].steam_access = true

static func pose(run, id: String, room: String, point: Array) -> Dictionary:
 if not run.s.actors.has(id): return {"room":"cabins","pos":[-25,530],"action":"walk","facing":"right"}
 return {"room":room,"pos":point,"action":"idle","facing":"left" if point[0]>580 else "right"}
