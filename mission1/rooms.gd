extends RefCounted
## Authored screen geometry. Coordinates are at characters' feet.
const LUGGAGE := Vector2(145,390)
const ROOMS := {
 "docks": {"title": "The docks", "scene": "01_docks", "floor": [[170,235,820,440],[125,325,90,140],[525,90,110,160]]},
 "foyer": {"title": "Grand foyer", "scene": "02_foyer", "floor": [[155,230,850,445],[505,115,150,130]]},
 "cabins": {"title": "Cabin corridor", "scene": "03_cabin_corridor", "floor": [[55,445,1050,165],[185,340,80,115],[90,240,250,125],[535,340,80,115],[440,240,250,125],[895,340,80,115],[800,240,265,125]]},
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
  if door.a == room: result.append({"room":door.b, "point":door.ap, "arrival":door.bp})
  elif door.b == room: result.append({"room":door.a, "point":door.bp, "arrival":door.ap})
 return result
