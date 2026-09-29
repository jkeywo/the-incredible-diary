extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Rooms = preload("res://mission1/rooms.gd")
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
 if not ok and not failures.has(label): failures.append(label)
func _initialize() -> void:
 var run := Sim.new()
 # An NPC approaching a stationary player must walk around, never relocate them.
 var scene: Dictionary = run.s.actors.duplicate(true)
 scene.guest = {"room":"salon","pos":[525,500],"action":"walk"}
 var wanted: Dictionary = scene.duplicate(true)
 wanted.guest.pos = [515,500]
 var resolved := Sim.Crowd.separate(wanted,{},scene,{"player":{"room":"salon","pos":[500,500]}})
 check(Sim.Crowd.swept_clear("salon",Vector2(525,500),Rooms.point(resolved.guest.pos),{"player":{"room":"salon","pos":[500,500]}},{}),"NPC avoids stationary player along whole step")
 check(Sim.Crowd.move_player("salon",Vector2(470,500),Vector2(80,0),{}, {"guest":{"room":"salon","pos":[500,500]}}).x <= 475,"player cannot tunnel through character")
 for deadline in [710,1710]:
  var bag := Sim.new()
  bag.s.pos = [145,390]
  if deadline > 800:
   check(bag.start("hide_bag"),"hide for late recovery")
  while bag.s.tick < deadline: bag.step()
  var before := bag.boarding_time()
  check(bag.start("retrieve_bag"),"retrieve near recovery")
  for i in 10: bag.step()
  check(bag.boarding_time() <= before and bag.boarding_time() > bag.s.tick,"retrieval keeps valid earlier boarding deadline")
 var seen := {}
 var previous: Dictionary = run.s.actors
 for id in previous:
  check(previous[id].room == "docks", id+" starts on docks")
 for tick in Sim.END:
  run.step()
  var actors: Dictionary = run.s.actors
  check(Sim.Crowd.clear(run.s.room,Rooms.point(run.s.pos),actors),"player stays separate")
  for id in actors:
   var actor: Dictionary = actors[id]
   var p := Rooms.point(actor.pos)
   check(Rooms.can_stand(actor.room,p,run.s.flags),id+" stays on floor")
   seen[id+":"+actor.room] = true
   if actor.room == previous[id].room:
    check(p.distance_to(Rooms.point(previous[id].pos)) <= 10.01,id+" no same-room teleport at "+str(run.s.tick))
   else:
    var legal := false
    for door in Rooms.exits(previous[id].room,true):
     if door.room == actor.room and Rooms.point(previous[id].pos).distance_to(Rooms.point(door.point)) <= 35 and p.distance_to(Rooms.point(door.arrival)) <= 35: legal = true
    check(legal,id+" uses doorway at "+str(run.s.tick))
   for other in actors:
    if other != id and actors[other].room == actor.room:
     check(p.distance_to(Rooms.point(actors[other].pos)) >= 24.9,id+" collides with "+other)
  for id in actors:
   for other in actors:
    if id >= other or actors[id].room != actors[other].room or actors[id].room != previous[id].room or actors[other].room != previous[other].room: continue
    for alpha in [0.25,0.5,0.75]:
     var a := Rooms.point(previous[id].pos).lerp(Rooms.point(actors[id].pos),alpha)
     var b := Rooms.point(previous[other].pos).lerp(Rooms.point(actors[other].pos),alpha)
     check(a.distance_to(b) >= 24.0,"render overlap "+id+" "+other+" at "+str(run.s.tick))
  if run.s.tick == Sim.CREAK: check(Rooms.point(actors.chandelier_guest.pos).distance_to(Vector2(680,440)) < 1,"chandelier anchor")
  if run.s.tick == Sim.TRAP: check(Rooms.point(actors.chatterbox.pos).distance_to(Vector2(840,360)) < 1,"steam anchor")
  if run.s.tick == Sim.CREAK+20: check(Rooms.point(actors.guest.pos).distance_to(Vector2(800,330)) < 1,"drink anchor")
  previous = actors
 for id in ["guest","chandelier_guest","chatterbox"]:
  check(seen.has(id+":cabins") and seen.has(id+":foyer"),id+" boards and visits cabin")
 check(seen.has("chatterbox:passage") and seen.has("chatterbox:salon"),"steam incoming route")
 print("MISSION1 LIFE PASS: full voyage, physical routes, event anchors, continuous collision and luggage deadlines" if failures.is_empty() else "MISSION1 LIFE FAIL: "+JSON.stringify(failures))
 quit(0 if failures.is_empty() else 1)
