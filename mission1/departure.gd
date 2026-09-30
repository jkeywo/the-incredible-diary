extends RefCounted
## The last five voyage minutes: arrivals use the same recorded actor movement.
const Rooms = preload("res://mission1/rooms.gd")
const Routes = preload("res://mission1/routines.gd")
const LEAD_TICKS := 150
const ENTRANCE := Vector2(970,785)
const PIER_ENTRANCE := Vector2(970,650)
const SPECTATOR_POSITIONS := [Vector2(300,270),Vector2(365,255),Vector2(430,265),Vector2(495,255),Vector2(650,255),Vector2(715,265),Vector2(780,255),Vector2(845,265),Vector2(900,290),Vector2(945,340)]
const GUEST_SKINS := ["guest_male_jacket","guest_female_dress","guest_female_coat","guest_male_waistcoat"]
const CAPTAIN_ENTRANCES := {"foyer":Vector2(580,650),"salon":Vector2(580,650),"controls":Vector2(1015,345)}

static func skin(id: String) -> String:
	if not id.begins_with("sendoff_guest_"): return ""
	return GUEST_SKINS[(int(id.trim_prefix("sendoff_guest_"))-1)%GUEST_SKINS.size()]

static func victim(dead: Array) -> String:
	for id in ["chandelier_guest","guest","chatterbox"]:
		if dead.has(id): return id
	return ""

static func room_for(id: String) -> String:
	return {"chandelier_guest":"foyer","guest":"salon","chatterbox":"controls"}.get(id,"docks")

static func captain_target(body: Dictionary) -> Vector2:
	return Rooms.point(body.pos)+Vector2(-65,25)

static func apply(run, planned: Dictionary) -> void:
	var elapsed: int = run.s.tick-(run.timing("end",run.END)-LEAD_TICKS)
	if elapsed < 0: return
	var body_id := victim(run.s.dead)
	if not body_id.is_empty():
		var room := room_for(body_id)
		var target := captain_target(planned[body_id])
		# Start at the room entrance, then let physical movement resolve the walk.
		var entrance: Vector2 = CAPTAIN_ENTRANCES[room]
		var position := target if run.s.get("actors",{}).has("captain") else entrance
		planned.captain = {"room":room,"pos":[position.x,position.y],"action":"idle","facing":"down","steam_access":true}
		return
	for i in SPECTATOR_POSITIONS.size():
		var age := elapsed-i*6
		if age < 0: continue
		var id := "sendoff_guest_%d" % (i+1)
		var approach := ENTRANCE.move_toward(PIER_ENTRANCE,float(age)*Routes.SPEED/Routes.CLOCK_RATE)
		if approach.y > PIER_ENTRANCE.y:
			# An off-screen approach through the entrance, outside playable floor.
			planned[id] = {"room":"docks","pos":[approach.x,approach.y],"action":"walk","facing":"up","fixed":true}
		else:
			var target: Vector2 = SPECTATOR_POSITIONS[i]
			planned[id] = {"room":"docks","pos":[target.x,target.y],"action":"idle","facing":"up"}
