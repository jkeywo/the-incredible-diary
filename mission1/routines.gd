extends RefCounted
## Timetabled journeys use the same exits and walkable floor as the player.
## Each route is sampled at constant speed and is recorded in the run history.
const Rooms = preload("res://mission1/rooms.gd")
const SPEED := 10.0 # pixels per 0.1-second simulation tick
static var paths: Dictionary = {}

static func region(room: String, p: Vector2) -> String:
 return "controls_left" if room == "controls" and p.x < 600 else "controls_right" if room == "controls" else room

static func waypoint(room: String, p: Vector2) -> Dictionary:
 return {"room":room,"pos":[p.x,p.y]}

static func path(room: String, origin: Vector2, destination: String, target: Vector2, cache := true) -> Array:
 var key := "%s:%s:%s:%s" % [room,origin,destination,target]
 if cache and paths.has(key): return paths[key]
 var start := region(room,origin)
 var finish := region(destination,target)
 var pending := [start]
 var visited := {start:[]}
 while not pending.is_empty() and not visited.has(finish):
  var current: String = pending.pop_front()
  for door in Rooms.DOORS:
   for reverse in [false,true]:
    var from_room: String = door.b if reverse else door.a
    var to_room: String = door.a if reverse else door.b
    var from_point := Rooms.point(door.bp if reverse else door.ap)
    var to_point := Rooms.point(door.ap if reverse else door.bp)
    var next := region(to_room,to_point)
    if region(from_room,from_point) == current and not visited.has(next):
     visited[next] = visited[current] + [{"from":waypoint(from_room,from_point),"to":waypoint(to_room,to_point)}]
     pending.append(next)
 assert(visited.has(finish), "No route between passenger destinations")
 var result := [waypoint(room,origin)]
 var here := origin
 var here_room := room
 for crossing in visited[finish]:
  result.append_array(_inside(here_room,here,Rooms.point(crossing.from.pos)))
  result.append(crossing.to)
  here_room = crossing.to.room
  here = Rooms.point(crossing.to.pos)
 result.append_array(_inside(here_room,here,target))
 if cache: paths[key] = result
 return result

static func _inside(room: String, origin: Vector2, target: Vector2) -> Array:
 var result: Array = []
 if origin.is_equal_approx(target): return result
 var straight := true
 var samples := maxi(1,ceili(origin.distance_to(target)/8.0))
 for i in range(1,samples+1):
  if not Rooms.can_stand(room,origin.lerp(target,float(i)/samples),{"cabin_left":true,"cabin_middle":true,"cabin_right":true}):
   straight = false
   break
 if straight: return [waypoint(room,target)]
 if room == "cabins":
  if absf(origin.x-target.x) < 40 and origin.y < 445 and target.y < 445: return [waypoint(room,target)]
  if origin.y < 445: result.append(waypoint(room,Vector2(origin.x,530)))
  result.append(waypoint(room,Vector2(target.x,530)))
 elif room == "docks":
  # The luggage aisle joins the dock through its opening on the right.
  if origin.x < 170: result.append(waypoint(room,Vector2(190,390)))
  if origin.y < 235 or target.y < 235: result.append(waypoint(room,Vector2(580,280)))
  if target.x < 170: result.append(waypoint(room,Vector2(190,390)))
 elif room == "foyer":
  if origin.y < 230 or target.y < 230: result.append(waypoint(room,Vector2(580,260)))
 elif room == "salon":
  if origin.y > 585 or target.y > 585: result.append(waypoint(room,Vector2(580,550)))
 result.append(waypoint(room,target))
 return result

static func duration(points: Array) -> int:
 var total := 0
 for i in range(1,points.size()):
  if points[i-1].room == points[i].room:
   total += ceili(Rooms.point(points[i-1].pos).distance_to(Rooms.point(points[i].pos))/SPEED)
 return total

static func travel(points: Array, elapsed: int, action := "idle", facing := "down") -> Dictionary:
 var left := maxi(0,elapsed)
 for i in range(1,points.size()):
  var a: Dictionary = points[i-1]
  var b: Dictionary = points[i]
  if a.room != b.room: continue
  var origin := Rooms.point(a.pos)
  var target := Rooms.point(b.pos)
  var ticks := ceili(origin.distance_to(target)/SPEED)
  if left < ticks:
   var p := origin.move_toward(target,left*SPEED)
   var delta := target-origin
   var direction := ("right" if delta.x > 0 else "left") if absf(delta.x)>absf(delta.y) else ("down" if delta.y>0 else "up")
   return {"room":a.room,"pos":[p.x,p.y],"action":"walk","facing":direction}
  left -= ticks
 var end: Dictionary = points[-1]
 return {"room":end.room,"pos":end.pos.duplicate(),"action":action,"facing":facing}

static func track(tick: int, room: String, origin: Vector2, stages: Array, action := "idle", facing := "down") -> Dictionary:
 var pose := {"room":room,"pos":[origin.x,origin.y],"action":action,"facing":facing}
 var from := origin
 var from_room := room
 for stage in stages:
  if tick < int(stage[0]): break
  var journey := path(from_room,from,stage[1],Rooms.point(stage[2]))
  pose = travel(journey,tick-int(stage[0]),stage[3],stage[4] if stage.size()>4 else "down")
  from = Rooms.point(stage[2])
  from_room = stage[1]
 return pose

static func passenger(id: String, tick: int, boarding: int, arrival: int, flags: Dictionary) -> Dictionary:
 var plan := _passenger_plan(id, tick, boarding, arrival, flags)
 return track(tick, "docks", plan.origin, plan.stages, plan.action, plan.facing)

static func next_commitment(id: String, tick: int, boarding: int, arrival: int, flags: Dictionary) -> int:
 var plan := _passenger_plan(id, tick, boarding, arrival, flags)
 for stage in plan.stages:
  if int(stage[0]) > tick: return int(stage[0])
 return tick

static func _plan(origin: Vector2, stages: Array, action := "idle", facing := "down") -> Dictionary:
 return {"origin":origin, "stages":stages, "action":action, "facing":facing}

static func _passenger_plan(id: String, tick: int, boarding: int, arrival: int, flags: Dictionary) -> Dictionary:
 if id == "chandelier_guest":
  return _plan(Vector2(720,440),[
   [160,"cabins",[225,315],"idle"],
   [850,"foyer",[495,365],"talk","left"],
   [1450,"salon",[735,345],"talk","right"],
   [2600,"cabins",[225,315],"idle"],
   [3500,"foyer",[Rooms.CHANDELIER_FLOOR.x,Rooms.CHANDELIER_FLOOR.y],"idle"]],"talk","right")
 if id == "chatterbox":
  var to_steam := path("cabins",Vector2(935,315),"controls",Vector2(840,360))
  return _plan(Vector2(765,440),[
   [320,"cabins",[935,315],"idle"],
   [980,"cabins",[700,530],"talk","right"],
   [1500,"salon",[780,345],"talk","left"],
   [2600,"cabins",[935,315],"idle"],
   [5400-duration(to_steam)-60,"controls",[840,360],"idle"]],"talk","left")
 if id == "crew":
  return _plan(Vector2(640,430),[[60,"controls",[310,305],"idle"]])
 if id == "porter":
  return _plan(Vector2(670,475),[[460,"foyer",[450,365],"idle"]])
 # The luggage owner waits for recovery, then boards and visits their cabin.
 var dock_leg := path("docks",Vector2(390,430),"docks",Vector2(580,105))
 var start := maxi(int(flags.get("bag_found_tick",boarding-80)),boarding-duration(dock_leg))
 var cabin_leg := path("docks",Vector2(390,430),"cabins",Vector2(580,315))
 var stages := [[start,"cabins",[580,315],"idle"]]
 var cabin_arrival := start+duration(cabin_leg)
 if cabin_arrival < 1080:
  stages.append([maxi(cabin_arrival+50,1000),"cabins",[745,530],"talk","left"])
  stages.append([1380,"cabins",[580,315],"idle"])
 var salon_leg := path("cabins",Vector2(580,315),"salon",Vector2(800,330))
 stages.append([arrival-duration(salon_leg)-60,"salon",[800,330],"hold_drink" if tick >= arrival else "idle"])
 return _plan(Vector2(390,430),stages,"talk" if not flags.get("bag_found",false) else "idle","right")
