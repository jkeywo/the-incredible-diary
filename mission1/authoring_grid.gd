extends RefCounted
## Collision cells are world coordinates, independent of viewport scale.
const CELL := 25

static func cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))

static func key(value: Vector2i) -> String:
	return "%d,%d" % [value.x, value.y]

static func contains(room: Dictionary, point: Vector2) -> bool:
	var dimensions: Array = room.get("size", [1175, 700])
	var origin: Array = room.get("origin", [0,0])
	if point.x < origin[0] or point.y < origin[1] or point.x >= dimensions[0] or point.y >= dimensions[1]: return false
	if room.has("floor_regions"):
		var on_floor := false
		for box in room.floor_regions:
			if Rect2(box[0],box[1],box[2],box[3]).has_point(point): on_floor = true; break
		if not on_floor: return false
	return not room.get("blocked", {}).has(key(cell(point)))

static func migrate(floors: Array, dimensions := Vector2i(1175, 700)) -> Dictionary:
	var blocked := {}
	for y in ceili(float(dimensions.y) / CELL):
		for x in ceili(float(dimensions.x) / CELL):
			var square := Rect2(x * CELL, y * CELL, CELL, CELL)
			var open := false
			for box in floors:
				if square.intersects(Rect2(box[0], box[1], box[2], box[3])): open = true
			if not open: blocked[key(Vector2i(x, y))] = true
	return blocked

static func stroke(room: Dictionary, start: Vector2, finish: Vector2, blocked: bool) -> void:
	room.erase("floor_regions") # Painting explicitly replaces the stock precise floor.
	var count := maxi(1, ceili(start.distance_to(finish) / (CELL * 0.2)))
	for i in range(count + 1):
		var point := start.lerp(finish, float(i) / count)
		if point.x < 0 or point.y < 0 or point.x >= room.size[0] or point.y >= room.size[1]: continue
		var id := key(cell(point))
		if blocked: room.blocked[id] = true
		else: room.blocked.erase(id)

static func path(room: Dictionary, origin: Vector2, target: Vector2) -> Array:
	if not contains(room, origin) or not contains(room, target): return []
	if clear_line(room, origin, target): return [target]
	var start := cell(origin)
	var goal := cell(target)
	var queue: Array[Vector2i] = [start]
	var previous := {start: start}
	var index := 0
	while index < queue.size() and not previous.has(goal):
		var current := queue[index]
		index += 1
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next: Vector2i = current + direction
			if previous.has(next) or not contains(room, Vector2(next * CELL) + Vector2.ONE * CELL / 2): continue
			previous[next] = current
			queue.append(next)
	if not previous.has(goal): return []
	var result: Array = [target]
	var cursor := goal
	while cursor != start:
		result.push_front(Vector2(cursor * CELL) + Vector2.ONE * CELL / 2)
		cursor = previous[cursor]
	# Remove unnecessary bends without cutting across blocked cells.
	var simplified := []
	var here := origin
	var start_index := 0
	while start_index < result.size():
		var furthest := start_index
		for candidate in range(start_index + 1,result.size()):
			if clear_line(room,here,result[candidate]): furthest = candidate
		simplified.append(result[furthest])
		here = result[furthest]
		start_index = furthest + 1
	return simplified

static func clear_line(room: Dictionary, origin: Vector2, target: Vector2) -> bool:
	var steps := maxi(1, ceili(origin.distance_to(target) / 4.0))
	for i in range(steps + 1):
		if not contains(room,origin.lerp(target,float(i)/steps)): return false
	return true
