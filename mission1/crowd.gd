extends RefCounted
## Deterministic foot-level collision; all resolved positions enter history.
const Rooms = preload("res://mission1/rooms.gd")
const Routines = preload("res://mission1/routines.gd")
const DISTANCE := 25.0

static func clear(room: String, p: Vector2, actors: Dictionary, except := "") -> bool:
 for id in actors:
  if actors[id].get("solid",true) and id != except and actors[id].room == room and p.distance_to(Rooms.point(actors[id].pos)) < DISTANCE-0.01: return false
 return true

static func move_player(room: String, origin: Vector2, step: Vector2, flags: Dictionary, actors: Dictionary) -> Vector2:
 var count := maxi(1,ceili(step.length()/4.0))
 var piece := step/count
 for i in count:
  for delta in [piece,Vector2(piece.x,0),Vector2(0,piece.y)]:
   var candidate: Vector2 = origin+delta
   if Rooms.can_step(room,origin,candidate,flags) and clear(room,candidate,actors):
    origin = candidate
    break
 return origin

static func free_near(room: String, p: Vector2, flags: Dictionary, actors: Dictionary, except := "") -> Vector2:
 if Rooms.can_stand(room,p,flags) and clear(room,p,actors,except): return p
 # Fixed order preserves determinism. Search near the blocked foot position.
 for distance in [8,16,25,34,45,60,80]:
  for index in 16:
   var candidate: Vector2 = p+Vector2.from_angle(TAU*index/16.0)*distance
   if Rooms.can_stand(room,candidate,flags) and clear(room,candidate,actors,except): return candidate
 return p

static func swept_clear(room: String, origin: Vector2, target: Vector2, others: Dictionary, previous: Dictionary, except := "") -> bool:
 for id in others:
  if not others[id].get("solid",true) or id == except or others[id].room != room: continue
  var other_end := Rooms.point(others[id].pos)
  var other_start := other_end
  if previous.has(id) and previous[id].room == room: other_start = Rooms.point(previous[id].pos)
  var relative := origin-other_start
  var velocity := (target-origin)-(other_end-other_start)
  var fraction := clampf(-relative.dot(velocity)/velocity.length_squared(),0,1) if velocity.length_squared()>0.0001 else 0.0
  if (relative+velocity*fraction).length() < DISTANCE-0.01: return false
 return true

static func separate(planned: Dictionary, flags: Dictionary, previous: Dictionary = {}, blockers: Dictionary = {}, blocker_previous: Dictionary = {}) -> Dictionary:
 var result := {}
 var occupied := {}
 for id in previous:
  if planned.has(id): occupied[id] = previous[id].duplicate(true)
 occupied.merge(blockers,true)
 var sweep_previous := previous.duplicate(true)
 sweep_previous.merge(blockers,true)
 sweep_previous.merge(blocker_previous,true)
 # Keep previous positions and test the whole step, including interpolation.
 var ordered := ["chandelier_guest","chatterbox","guest","crew","porter","dock_sailor","captain"]
 for id in planned:
  if not ordered.has(id): ordered.append(id)
 for id in ordered:
  if not planned.has(id): continue
  var actor: Dictionary = planned[id].duplicate(true)
  var p := Rooms.point(actor.pos)
  if actor.get("fixed",false):
   result[id] = actor
   occupied[id] = actor
   continue
  if previous.has(id):
   var before: Dictionary = previous[id]
   var origin := Rooms.point(before.pos)
   var destination: String = actor.room
   var route := Routines.path(before.room,origin,destination,p,false,flags)
   # The first waypoint after the current position is the next local goal.
   var goal := p
   var room: String = before.room
   for point in route:
    if point.room != room:
     room = point.room
     origin = Rooms.point(point.pos)
     goal = origin
     break
    if origin.distance_to(Rooms.point(point.pos)) > 0.01:
     goal = Rooms.point(point.pos)
     break
   if room != before.room and (not Rooms.arrival_open(room,origin,flags) or (actor.get("solid",true) and not clear(room,origin,occupied,id))):
    room = before.room
    origin = Rooms.point(before.pos)
    goal = origin
   actor.room = room
   p = origin
   var step := (goal-origin).limit_length(Routines.SPEED)
   var best := INF
   if step.length_squared() > 0.001:
    for angle in [0,30,-30,60,-60,90,-90,120,-120]:
     var candidate := origin+step.rotated(deg_to_rad(float(angle)))
     if not Rooms.can_step(room,origin,candidate,flags): continue
     if actor.get("solid",true) and not swept_clear(room,origin,candidate,occupied,sweep_previous,id): continue
     var score := candidate.distance_to(goal)
     if score < best:
      p = candidate
      best = score
   if origin.distance_to(p) > 0.01:
    actor.action = "walk"
    var delta := p-origin
    actor.facing = ("right" if delta.x>0 else "left") if absf(delta.x)>absf(delta.y) else ("down" if delta.y>0 else "up")
   elif step.length_squared()>0.001: actor.action = "idle"
  else:
   p = free_near(actor.room,p,flags,occupied,id)
   if not clear(actor.room,p,occupied,id): continue
  actor.pos = [p.x,p.y]
  result[id] = actor
  occupied[id] = actor
 return result
