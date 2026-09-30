extends Control
## One coordinate transform for rendering, placement, selection and grid strokes.
const Grid = preload("res://mission1/authoring_grid.gd")
const Content = preload("res://mission1/authoring_content.gd")
const Assets = preload("res://foundation/project_assets.gd")
var editor
var zoom := 0.47
var pan := Vector2(290, 60)
var painting := false
var previous := Vector2.ZERO
var stroke_content: Dictionary = {}
var texture_cache := {}

func world_point(screen: Vector2) -> Vector2:
	return (screen - pan) / zoom

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			finish_stroke()
			editor.select_tool()
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var point := world_point(event.position)
			zoom = clampf(zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.2, 3.0)
			pan = event.position - point * zoom
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if editor.history_mode:
				if event.pressed: editor.history_click(world_point(event.position))
				return
			var point := world_point(event.position)
			if event.pressed:
				if editor.tool in ["Block", "Erase"]:
					painting = true
					stroke_content = editor.document.content.duplicate(true)
					previous = point
					_paint(point)
				else: editor.map_click(point)
			elif painting: finish_stroke()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			pan += event.relative
			queue_redraw()
		elif painting: _paint(world_point(event.position))

func _input(event: InputEvent) -> void:
	if painting and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: finish_stroke()

func _paint(point: Vector2) -> void:
	Grid.stroke(stroke_content.rooms[editor.room_id], previous, point, editor.tool == "Block")
	previous = point
	queue_redraw()

func finish_stroke() -> void:
	if not painting: return
	painting = false
	editor.document.replace_content(stroke_content, "Paint collision cells")
	stroke_content = {}
	queue_redraw()

func _draw() -> void:
	if editor == null or editor.document == null: return
	if editor.game.stream_resources and editor.prepared_room != editor.room_id:
		draw_string(ThemeDB.fallback_font,Vector2(320,70),"Loading room artwork…",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
		return
	var data: Dictionary = stroke_content if painting else editor.shown_content()
	if not data.rooms.has(editor.room_id): return
	var room: Dictionary = data.rooms[editor.room_id]
	draw_set_transform(pan, 0, Vector2.ONE * zoom)
	var bounds := Rect2(Vector2.ZERO, Vector2(room.size[0], room.size[1]))
	draw_rect(bounds, Color("26343b"))
	var asset := str(room.get("background_asset", ""))
	var image_key := asset if not asset.is_empty() else str(room.get("scene", ""))
	if not texture_cache.has(image_key) and not image_key.is_empty():
		if not asset.is_empty() and data.assets.has(asset): texture_cache[image_key] = Assets.texture(data.assets[asset])
		else:
			var path := ("res://assets/rooms/mission_1/%s.png" % image_key).simplify_path()
			if ResourceLoader.exists(path): texture_cache[image_key] = load(path)
	var texture: Texture2D = texture_cache.get(image_key)
	if texture != null: draw_texture_rect(texture, bounds, false)
	if image_key == "01_docks":
		for layer in [["water",Vector2(-20,-13)],["ship",Vector2(-20,-90)],["pier",Vector2.ZERO]]:
			var path := "res://assets/rooms/mission_1/01_docks_%s.png" % layer[0]
			if not texture_cache.has(path): texture_cache[path] = load(path)
			var layer_texture: Texture2D = texture_cache[path]
			draw_texture(layer_texture,layer[1])
	if image_key == "../mission_3/greek_docks":
		for layer in [["res://assets/rooms/mission_1/01_docks_water.png",Vector2(-20,-13)],["res://assets/rooms/mission_1/01_docks_ship.png",Vector2(-20,-90)],["res://assets/rooms/mission_3/greek_pier.png",Vector2.ZERO]]:
			var path: String = layer[0]
			if not texture_cache.has(path): texture_cache[path] = load(path)
			var layer_texture: Texture2D = texture_cache[path]
			if path.ends_with("greek_pier.png"): draw_texture_rect(layer_texture,bounds,false)
			else: draw_texture(layer_texture,layer[1])
	if not editor.history_mode:
		for key in room.blocked:
			var coordinates: PackedStringArray = str(key).split(",")
			if coordinates.size() != 2: continue
			draw_rect(Rect2(float(coordinates[0])*25, float(coordinates[1])*25,25,25),Color(0.85,0.2,0.15,0.28))
		for x in range(0,int(room.size[0])+1,25): draw_line(Vector2(x,0),Vector2(x,room.size[1]),Color(1,1,1,0.12))
		for y in range(0,int(room.size[1])+1,25): draw_line(Vector2(0,y),Vector2(room.size[0],y),Color(1,1,1,0.12))
		for connection in data.connections:
			for side in ["a","b"]:
				if connection[side] != editor.room_id: continue
				var point: Array = connection[side+"p"]
				draw_rect(Rect2(point[0]-20,point[1]-20,40,40),Color("e8c782"),false,3)
	var entities := {}
	if editor.history_mode:
		var state: Dictionary = editor.inspected_state()
		entities = state.get("actors", {}).duplicate(true)
		entities.amelia = {"room":state.room,"pos":state.pos}
		for id in data.instances:
			var entity := Content.resolve(data,id)
			if entity.kind != "character":
				if not state.get("prop_states",{}).has(id): continue
				var prop_state: Dictionary = entity.get("states",{}).get(state.prop_states[id],{})
				if prop_state.get("visible",true): entities[id] = {"room":entity.room,"pos":entity.position}
	else:
		for id in data.instances: entities[id] = {"room":data.instances[id].room,"pos":data.instances[id].position}
	for id in entities:
		if entities[id].room != editor.room_id: continue
		var point := Vector2(entities[id].pos[0],entities[id].pos[1])
		var selected: bool = editor.selected_kind == "instances" and editor.selected_id == id
		draw_circle(point,12,Color("ffe5a2") if selected else Color("8cd6da"))
		var entity := Content.resolve(data,id)
		if entity.get("kind") == "character":
			var path: String = editor.game.ContentPlan.character_paths(str(id),str(entity.appearance))[0]
			if not texture_cache.has(path) and ResourceLoader.exists(path): texture_cache[path] = load(path)
			var art: Texture2D = texture_cache.get(path)
			if art != null:
				var frame_size := Vector2(art.get_width()/4.0,art.get_height()/4.0) if entity.appearance == "captain" else Vector2(32,48)
				draw_texture_rect_region(art,Rect2(point-Vector2(16,46),Vector2(32,48)),Rect2(Vector2.ZERO,frame_size))
		elif entity.get("kind") != "character":
			var prop_path := "res://assets/props/mission_1/%s_states.png" % entity.get("appearance","")
			if not texture_cache.has(prop_path) and ResourceLoader.exists(prop_path): texture_cache[prop_path] = load(prop_path)
			var prop_texture: Texture2D = texture_cache.get(prop_path)
			if prop_texture != null: draw_texture_rect_region(prop_texture,Rect2(point-Vector2(20,35),Vector2(40,35)),Rect2(0,0,mini(prop_texture.get_width(),56),mini(prop_texture.get_height(),48)))
		if selected:
			draw_line(point-Vector2(22,0),point+Vector2(22,0),Color("ffcf60"),2)
			draw_line(point-Vector2(0,8),point+Vector2(0,8),Color("ffcf60"),2)
			draw_string(ThemeDB.fallback_font,point+Vector2(15,18),"Ground anchor",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ffcf60"))
		if selected or zoom >= 0.65: draw_string(ThemeDB.fallback_font,point+Vector2(15,-3),str(id),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
	draw_set_transform(Vector2.ZERO)
