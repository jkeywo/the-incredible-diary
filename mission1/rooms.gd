extends RefCounted
## Authored screen geometry. Coordinates are at characters' feet.
const ROOMS := {
 "docks": {"title": "The docks", "scene": "01_docks", "floor": [[170,235,820,440],[525,90,110,160]]},
 "foyer": {"title": "Grand foyer", "scene": "02_foyer", "floor": [[155,230,850,445],[505,115,150,130]]},
 "cabins": {"title": "Cabin corridor", "scene": "03_cabin_corridor", "floor": [[55,445,1050,165],[185,340,80,115],[90,240,250,125],[535,340,80,115],[440,240,250,125],[895,340,80,115],[800,240,265,125]]},
 "controls": {"title": "Engine controls / steam passage", "scene": "04_controls_and_steam", "floor": [[110,265,440,400]]},
 "salon": {"title": "Unmooring party", "scene": "05_party_salon", "floor": [[190,195,805,350],[130,480,865,105],[525,530,110,155]]}
}
# The foyer, cabins, salon and controls form a circular route.
const DOORS := [
 {"a":"docks", "ap":[580,105], "b":"foyer", "bp":[580,650]},
 {"a":"foyer", "ap":[175,460], "b":"cabins", "bp":[1080,530]},
 {"a":"foyer", "ap":[980,460], "b":"controls", "bp":[140,635]},
 {"a":"cabins", "ap":[80,530], "b":"salon", "bp":[155,535]},
 {"a":"salon", "ap":[960,520], "b":"controls", "bp":[510,635]},
 {"a":"foyer", "ap":[580,140], "b":"salon", "bp":[580,650], "shortcut":true}
]

static func point(value: Array) -> Vector2:
 return Vector2(float(value[0]), float(value[1]))

static func can_stand(room: String, p: Vector2) -> bool:
 for box in ROOMS[room].floor:
  if Rect2(box[0], box[1], box[2], box[3]).has_point(p): return true
 return false

static func move(room: String, origin: Vector2, step: Vector2) -> Vector2:
 var next := origin + step
 if can_stand(room, next): return next
 next = origin + Vector2(step.x, 0)
 if can_stand(room, next): origin = next
 next = origin + Vector2(0, step.y)
 if can_stand(room, next): origin = next
 return origin

static func exits(room: String, shortcut: bool) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for door in DOORS:
  if door.get("shortcut", false) and not shortcut: continue
  if door.a == room: result.append({"room":door.b, "point":door.ap, "arrival":door.bp})
  elif door.b == room: result.append({"room":door.a, "point":door.bp, "arrival":door.ap})
 return result
