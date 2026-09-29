extends RefCounted
## Authored screen geometry. Coordinates are at characters' feet.
const CHANDELIER_FLOOR := Vector2(580,380)
const CHANDELIER_GUEST := Vector2(580,412)
const WRECKAGE := Rect2(520,325,120,65)
const CHANDELIER_SAFE := Vector2(730,430)
const BAR_GLASS := Vector2(930,132)
const BAR_GUEST := Vector2(950,215)
const STEAM_EXIT := Rect2(990,570,90,95)
const LUGGAGE := Vector2(145,390)
const ROOMS := {
 "docks": {"title": "The docks", "scene": "01_docks", "floor": [[170,235,820,440],[125,325,90,140],[525,90,110,160]]},
 "foyer": {"title": "Grand foyer", "scene": "02_foyer", "floor": [[155,230,850,445],[505,115,150,130]]},
 "cabins": {"title": "Cabin corridor", "scene": "03_cabin_corridor", "floor": [[-40,445,1145,165],[185,340,80,115],[90,240,250,125],[535,340,80,115],[440,240,250,125],[895,340,80,115],[800,240,265,125]]},
 "controls": {"title": "Steam room", "scene": "04_controls_and_steam", "floor": [[110,265,440,400],[640,265,440,400]]},
 "passage": {"title": "Service passage", "scene": "06_service_passage", "floor": [[40,405,1080,110]]},
 "salon": {"title": "Salon", "scene": "05_party_salon", "floor": [[190,195,805,350],[130,480,865,105],[525,530,110,155]]}
}
# Cabins end at the foyer. The salon stair is open from the start.
const CABIN_DOORS := {"cabin_left":225.0, "cabin_middle":580.0, "cabin_right":935.0}
const DOORS := [
 {"a":"docks", "ap":[580,105], "b":"foyer", "bp":[580,650]},
 {"a":"foyer", "ap":[175,460], "b":"cabins", "bp":[1080,530]},
 {"a":"foyer", "ap":[980,460], "b":"controls", "bp":[140,635]},
 {"a":"salon", "ap":[960,520], "b":"passage", "bp":[60,480]},
 {"a":"passage", "ap":[1100,480], "b":"controls", "bp":[1040,635]},
 {"a":"foyer", "ap":[580,140], "b":"salon", "bp":[580,650]}
]

static func point(value: Array) -> Vector2:
 return Vector2(float(value[0]), float(value[1]))

static func can_stand(room: String, p: Vector2, flags: Dictionary = {}) -> bool:
 if room == "foyer" and flags.get("chandelier_fallen",false) and WRECKAGE.has_point(p): return false
 if room == "controls" and steam_blocked(flags) and STEAM_EXIT.has_point(p): return false
 if room == "cabins":
  for id in CABIN_DOORS:
   if not flags.get(id, false) and door_bounds(id).has_point(p): return false
 for box in ROOMS[room].floor:
  if Rect2(box[0], box[1], box[2], box[3]).has_point(p): return true
 return false

static func door_bounds(id: String) -> Rect2:
 return Rect2(CABIN_DOORS[id]-48, 370, 96, 70)

static func move(room: String, origin: Vector2, step: Vector2, flags: Dictionary = {}) -> Vector2:
 var next := origin + step
 if can_stand(room, next, flags): return next
 next = origin + Vector2(step.x, 0)
 if can_stand(room, next, flags): origin = next
 next = origin + Vector2(0, step.y)
 if can_stand(room, next, flags): origin = next
 return origin

static func exits(room: String, shortcut: bool) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for door in DOORS:
  if door.get("shortcut", false) and not shortcut: continue
  if door.a == room: result.append({"room":door.b, "point":door.ap, "arrival":arrival_point(door.b,point(door.bp)),"bounds":exit_bounds(room,point(door.ap))})
  elif door.b == room: result.append({"room":door.a, "point":door.bp, "arrival":arrival_point(door.a,point(door.ap)),"bounds":exit_bounds(room,point(door.bp))})
 return result

static func steam_blocked(flags: Dictionary) -> bool:
 return flags.get("trapped",false) and not flags.get("steam_off",false)

static func exit_bounds(room: String, p: Vector2) -> Rect2:
 match room:
  "docks": return Rect2(525,90,110,35)
  "foyer":
   if p.y < 200: return Rect2(505,115,150,40)
   if p.y > 600: return Rect2(505,630,150,45)
   return Rect2(155 if p.x < 500 else 975,405,30,110)
  "cabins": return Rect2(1075,445,30,165)
  "controls": return Rect2(p.x-40,610,80,55)
  "passage": return Rect2(p.x-20,405,40,110)
  "salon":
   if p.y > 600: return Rect2(525,630,110,55)
   return Rect2(945,480,50,105)
 return Rect2()

static func arrival_point(room: String, p: Vector2) -> Array:
 var inward := Vector2.ZERO
 match room:
  "docks": inward = Vector2(0,70)
  "foyer": inward = Vector2(0,65) if p.y < 200 else Vector2(0,-65) if p.y > 600 else Vector2(60 if p.x < 500 else -60,0)
  "cabins": inward = Vector2(-70,0)
  "controls": inward = Vector2(0,-75)
  "passage": inward = Vector2(65 if p.x < 500 else -65,0)
  "salon": inward = Vector2(0,-65) if p.y > 600 else Vector2(-65,0)
 return [p.x+inward.x,p.y+inward.y]

static func can_step(room: String, origin: Vector2, target: Vector2, flags: Dictionary) -> bool:
 if can_stand(room,target,flags): return true
 # A new obstacle never imprisons someone who was already within its footprint.
 if room == "foyer" and flags.get("chandelier_fallen",false) and WRECKAGE.has_point(origin):
  return target.distance_to(WRECKAGE.get_center()) > origin.distance_to(WRECKAGE.get_center())
 return false

const GROUPS := {
 "docks":[[320,560],[790,560],[430,300]],
 "foyer":[[330,510],[790,515],[790,300]],
 "cabins":[[270,520],[610,520],[880,520]],
 "controls":[[245,475],[430,555],[330,380]],
 "salon":[[350,330],[700,390],[420,470]]
}
static func group_slot(room: String, group: int, slot: int) -> Dictionary:
 var center := point(GROUPS[room][group])
 var offsets := [Vector2(-35,-20),Vector2(35,-20),Vector2(0,35)]
 var p: Vector2 = center+offsets[slot]
 return {"room":room,"pos":[p.x,p.y],"action":"talk","facing":"right" if slot == 0 else "left" if slot == 1 else "up","group":group,"slot":slot}

static func arrival_open(room: String, p: Vector2, flags: Dictionary) -> bool:
 if not can_stand(room,p,flags): return false
 for exit in exits(room,true):
  if point(arrival_point(room,point(exit.point))).distance_to(p)<1 and not can_stand(room,point(exit.point),flags): return false
 return true
