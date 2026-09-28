extends RefCounted
class_name FoundationRoomGeometry

static func rectangles(room: Dictionary) -> Array:
	return room.get("walkable", [room.get("bounds", [0, 0, 0, 0])])

static func contains(room: Dictionary, point: Vector2) -> bool:
	for values in rectangles(room):
		if values is Array and values.size() == 4:
			if _contains_rect(_rect(values), point):
				return true
	return false

static func move(room: Dictionary, from: Vector2, delta: Vector2) -> Vector2:
	var target := from + delta
	if _clear_line(room, from, target):
		return target
	var horizontal := from + Vector2(delta.x, 0.0)
	if _clear_line(room, from, horizontal):
		return horizontal
	var vertical := from + Vector2(0.0, delta.y)
	if _clear_line(room, from, vertical):
		return vertical
	return from

static func path(room: Dictionary, from: Vector2, target: Vector2) -> PackedVector2Array:
	var regions: Array = rectangles(room)
	var start := -1
	var goal := -1
	for index in regions.size():
		var rect := _rect(regions[index])
		if start < 0 and _contains_rect(rect, from): start = index
		if goal < 0 and _contains_rect(rect, target): goal = index
	if start < 0 or goal < 0:
		return PackedVector2Array()
	if start == goal:
		return PackedVector2Array([target])
	var queue: Array[int] = [start]
	var previous := {start: -1}
	while not queue.is_empty() and not previous.has(goal):
		var current: int = queue.pop_front()
		for neighbor in regions.size():
			if previous.has(neighbor) or not _rect(regions[current]).intersects(_rect(regions[neighbor]), true):
				continue
			previous[neighbor] = current
			queue.append(neighbor)
	if not previous.has(goal):
		return PackedVector2Array()
	var chain: Array[int] = [goal]
	while chain[0] != start:
		chain.push_front(previous[chain[0]])
	var result := PackedVector2Array()
	for index in range(1, chain.size()):
		var left := _rect(regions[chain[index - 1]])
		var right := _rect(regions[chain[index]])
		var overlap_start := Vector2(maxf(left.position.x, right.position.x), maxf(left.position.y, right.position.y))
		var overlap_end := Vector2(minf(left.end.x, right.end.x), minf(left.end.y, right.end.y))
		result.append((overlap_start + overlap_end) * 0.5)
	result.append(target)
	return result

static func step_toward(room: Dictionary, from: Vector2, target: Vector2, speed: float) -> Vector2:
	var waypoints := path(room, from, target)
	if waypoints.is_empty() or speed <= 0.0:
		return from
	for waypoint in waypoints:
		if from.distance_to(waypoint) > 0.01:
			var delta := from.direction_to(waypoint) * minf(speed, from.distance_to(waypoint))
			return move(room, from, delta)
	return from

static func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))

static func _contains_rect(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.y >= rect.position.y and point.x <= rect.end.x and point.y <= rect.end.y

static func _clear_line(room: Dictionary, from: Vector2, target: Vector2) -> bool:
	var intervals: Array[Vector2] = []
	var delta := target - from
	for values in rectangles(room):
		var rect := _rect(values)
		var enter := 0.0
		var leave := 1.0
		var intersects := true
		for axis in range(2):
			var start: float = from.x if axis == 0 else from.y
			var displacement: float = delta.x if axis == 0 else delta.y
			var minimum: float = rect.position.x if axis == 0 else rect.position.y
			var maximum: float = rect.end.x if axis == 0 else rect.end.y
			if is_zero_approx(displacement):
				if start < minimum or start > maximum:
					intersects = false
					break
			else:
				var first := (minimum - start) / displacement
				var last := (maximum - start) / displacement
				enter = maxf(enter, minf(first, last))
				leave = minf(leave, maxf(first, last))
		if intersects and enter <= leave:
			intervals.append(Vector2(enter, leave))
	intervals.sort_custom(func(left: Vector2, right: Vector2): return left.x < right.x)
	var covered := 0.0
	for interval in intervals:
		if interval.x > covered + 0.000001:
			return false
		covered = maxf(covered, interval.y)
		if covered >= 1.0 - 0.000001:
			return true
	return false

static func validate(room: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var id := str(room.get("id", "?"))
	var bounds: Variant = room.get("bounds")
	if not bounds is Array or bounds.size() != 4:
		return ["Room %s needs four bounds values" % id]
	for value in bounds:
		if not value is int and not value is float:
			return ["Room %s has nonnumeric bounds" % id]
	var outer := Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
	if outer.size.x <= 0.0 or outer.size.y <= 0.0:
		errors.append("Room %s bounds must have positive width and height" % id)
	var regions: Variant = room.get("walkable", [bounds])
	if not regions is Array or regions.is_empty():
		errors.append("Room %s needs at least one walkable region" % id)
		return errors
	for index in regions.size():
		var values: Variant = regions[index]
		if not values is Array or values.size() != 4:
			errors.append("Room %s walkable region %d needs x, y, width and height" % [id, index + 1])
			continue
		var numeric := true
		for value in values:
			if not value is int and not value is float: numeric = false
		if not numeric:
			errors.append("Room %s walkable region %d has nonnumeric coordinates" % [id, index + 1])
			continue
		var region := _rect(values)
		if region.size.x <= 0.0 or region.size.y <= 0.0 or not outer.encloses(region):
			errors.append("Room %s walkable region %d must fit inside the room with positive size" % [id, index + 1])
	return errors
