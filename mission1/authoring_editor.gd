extends CanvasLayer
## Mission authoring edits a persistent document, never the live scene tree.
const Document = preload("res://foundation/authoring_document.gd")
const Store = preload("res://foundation/authoring_store.gd")
const Content = preload("res://mission1/authoring_content.gd")
const Assets = preload("res://foundation/project_assets.gd")
const FloatingPanel = preload("res://foundation/floating_panel.gd")
const Canvas = preload("res://mission1/authoring_canvas.gd")
const PATH := "user://mission1-authoring.json"
var game
var document: FoundationAuthoringDocument
var store
var overlay: Control
var workspace: Control
var dock: HBoxContainer
var canvas: Control
var tree: Tree
var inspector: VBoxContainer
var panels := {}
var palette: ItemList
var search: LineEdit
var source: CodeEdit
var status: Label
var time_label: Label
var scrubber: HSlider
var rooms: OptionButton
var tabs: TabBar
var history_mode := false
var viewed_frame := -1
var room_id := "docks"
var selected_kind := "rooms"
var selected_id := "docks"
var tool := "Select"
var placement_template := ""
var suppress := false
var save_pending := false
var autosave: Timer
var asset_dialog: FileDialog
var web_callback: JavaScriptObject
var storage_path := PATH
var room_ticket: Dictionary = {}
var prepared_room := ""
var room_request_key := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 91
	var initial: Dictionary = game.sim.authored_content
	if initial.is_empty(): initial = Content.seed(game.Simulation.new(false).s.actors)
	document = Document.new(initial)
	store = Store.new(storage_path)
	if game.save_enabled:
		var saved := Store.load(storage_path)
		if saved.ok: document.restore(saved.data)
	_build()
	autosave = Timer.new()
	autosave.one_shot = true
	autosave.wait_time = 0.5
	add_child(autosave)
	autosave.timeout.connect(_save_draft)
	document.changed.connect(_changed)
	overlay.hide()
	_refresh()

func toggle() -> void:
	if overlay.visible: resume()
	else:
		get_tree().paused = true
		history_mode = false
		viewed_frame = -1
		tabs.current_tab = 0
		overlay.show()
		_refresh()

func _process(_delta: float) -> void:
	if overlay == null or not overlay.visible or not game.stream_resources: return
	var key := room_id + ":" + str(document.revision) + ":" + str(shown_content().version)
	if room_request_key != key:
		if not room_ticket.is_empty(): room_ticket.cancelled = true
		room_request_key = key
		prepared_room = ""
		var content := shown_content()
		var resources: Array = game.ContentPlan.room_paths(room_id,content)
		for id in content.instances:
			var entity := Content.resolve(content,id)
			if entity.room == room_id and entity.kind == "character": resources.append_array(game.ContentPlan.character_paths(id,str(entity.appearance)))
		room_ticket = get_node("/root/ResourceStream").request_resources(resources,true)
	if room_ticket.get("done",false) and str(room_ticket.get("error","")).is_empty() and prepared_room != room_id:
		prepared_room = room_id
		canvas.queue_redraw()
	elif room_ticket.get("done",false) and not str(room_ticket.get("error","")).is_empty():
		status.text = "Room artwork: " + str(room_ticket.error) + " · choose the room again to retry"

func _build() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var background := ColorRect.new()
	background.color = Color("101b24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)
	canvas = Canvas.new()
	canvas.editor = self
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.offset_top = 40
	canvas.offset_bottom = -100
	overlay.add_child(canvas)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 58
	overlay.add_child(top)
	_menu(top,"Run",["Resume","Resume from here","Step tick","Next event","Restart leg"],[resume,func(): resume(true),func(): step(false),func(): step(true),restart])
	_menu(top,"Edit",["Undo","Redo","Duplicate entity","Delete selected","Save as template"],[func(): document.undo(),func(): document.redo(),duplicate_entity,delete_selected,save_as_template])
	_menu(top,"Create",["New room","New template","New storylet","New scene","Connect rooms"],[new_room,new_template,new_storylet,new_scene,new_connection])
	_menu(top,"View",["Setup tree","Inspector","Palette","Source"],[func(): panels.Setup.open_panel(),func(): panels.Inspector.open_panel(),func(): panels.Palette.open_panel(),func(): panels.Source.open_panel()])
	_menu(top,"Map",["Select / move","Paint blocked cells","Erase blocked cells","Import background"],[select_tool,func(): tool = "Block",func(): tool = "Erase",import_background])
	tabs = TabBar.new()
	tabs.custom_minimum_size = Vector2(170,32)
	tabs.add_tab("Setup")
	tabs.add_tab("History")
	tabs.tab_changed.connect(func(index): history_mode = index == 1; _refresh())
	top.add_child(tabs)
	rooms = OptionButton.new()
	rooms.item_selected.connect(func(index): room_id = rooms.get_item_text(index); room_request_key = ""; canvas.queue_redraw())
	top.add_child(rooms)
	workspace = Control.new()
	workspace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workspace.offset_top = 42
	workspace.offset_bottom = -110
	overlay.add_child(workspace)
	dock = HBoxContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -108
	dock.offset_bottom = -73
	overlay.add_child(dock)
	tree = Tree.new()
	tree.item_selected.connect(_select)
	tree.gui_input.connect(_tree_input)
	var setup_box := VBoxContainer.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button(setup_box,"Delete selected",delete_selected)
	setup_box.add_child(tree)
	_panel("Setup", Vector2(0,0),Vector2(280,400),setup_box)
	var scroll := ScrollContainer.new()
	inspector = VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inspector)
	_panel("Inspector",Vector2(865,0),Vector2(300,465),scroll)
	var palette_box := VBoxContainer.new()
	_button(palette_box,"Select existing / cancel placement",select_tool)
	search = LineEdit.new()
	search.placeholder_text = "Search templates"
	search.text_changed.connect(func(_text): _palette())
	palette_box.add_child(search)
	palette = ItemList.new()
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette.item_selected.connect(func(index): placement_template = palette.get_item_metadata(index); tool = "Place"; status.text = "Click the setup map to place " + placement_template)
	palette_box.add_child(palette)
	_panel("Palette",Vector2(0,300),Vector2(280,220),palette_box)
	source = CodeEdit.new()
	source.text_changed.connect(func():
		if not suppress and not history_mode: document.set_scenario_source(source.text))
	_panel("Source",Vector2(290,35),Vector2(570,425),source)
	panels.Source.hide()
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -74
	overlay.add_child(bottom)
	var stack := VBoxContainer.new()
	bottom.add_child(stack)
	var row := HBoxContainer.new()
	stack.add_child(row)
	_button(row,"Latest",func(): viewed_frame = -1; _refresh())
	_button(row,"Tick",func(): step(false))
	_button(row,"Next event",func(): step(true))
	scrubber = HSlider.new()
	scrubber.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrubber.custom_minimum_size = Vector2(240,24)
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("496572")
	rail.content_margin_top = 4
	rail.content_margin_bottom = 4
	scrubber.add_theme_stylebox_override("slider",rail)
	scrubber.step = 1
	scrubber.value_changed.connect(func(value): viewed_frame = int(value); history_mode = true; tabs.current_tab = 1; _refresh())
	row.add_child(scrubber)
	time_label = Label.new()
	row.add_child(time_label)
	_button(row,"Resume",resume)
	_button(row,"Resume from here",func(): resume(true))
	status = Label.new()
	status.text = "Setup definitions · scroll to zoom · middle-drag to pan"
	stack.add_child(status)

func _menu(parent: Control, caption: String, labels: Array, actions: Array) -> void:
	var menu := MenuButton.new()
	menu.text = caption
	parent.add_child(menu)
	for label in labels: menu.get_popup().add_item(label)
	menu.get_popup().id_pressed.connect(func(index): actions[index].call())

func _button(parent: Control, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)

func _panel(caption: String, point: Vector2, dimensions: Vector2, child: Control) -> void:
	var panel := FloatingPanel.new()
	workspace.add_child(panel)
	panel.configure(caption,dimensions)
	panel.position = point
	panel.attach_dock(dock)
	child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.body.add_child(child)
	panels[caption] = panel

func _changed() -> void:
	save_pending = true
	if game.save_enabled: autosave.start()
	_refresh()

func _save_draft() -> void:
	if not game.save_enabled or not save_pending: return
	var result: Dictionary = store.save(document)
	save_pending = not result.ok
	if not result.ok: status.text = result.reason

func _refresh(force_inspector := false) -> void:
	if tree == null: return
	suppress = true
	tree.clear()
	var root := tree.create_item()
	root.set_text(0,"Authored setup")
	root.set_selectable(0,false)
	for kind in ["rooms", "connections", "instances", "templates", "schedules", "storylets", "scenes", "timings", "texts"]:
		var branch := tree.create_item(root)
		branch.set_text(0,kind.capitalize())
		branch.set_selectable(0,false)
		var collection: Variant = document.content[kind]
		for entry in collection:
			var id: String = str(entry.id) if entry is Dictionary else str(entry)
			var item := tree.create_item(branch)
			item.set_text(0,id)
			item.set_metadata(0,[kind,id])
			if kind == selected_kind and id == selected_id: item.select(0)
	rooms.clear()
	var available_rooms: Dictionary = shown_content().rooms if history_mode else document.content.rooms
	for id in available_rooms:
		rooms.add_item(id)
		if id == room_id: rooms.select(rooms.item_count-1)
	if not available_rooms.has(room_id): room_id = str(available_rooms.keys()[0])
	_palette()
	if not source.has_focus(): source.text = document.scenario_draft
	source.editable = not history_mode
	scrubber.max_value = maxi(0,game.sim.history.size()-1)
	scrubber.set_value_no_signal(viewed_frame if viewed_frame >= 0 else game.sim.history.size()-1)
	var state := inspected_state()
	time_label.text = "%d / %d · tick %d" % [viewed_frame if viewed_frame >= 0 else game.sim.history.size()-1, game.sim.history.size()-1, state.tick]
	suppress = false
	var focused := get_viewport().gui_get_focus_owner()
	if force_inspector or focused == null or not inspector.is_ancestor_of(focused): _inspect()
	canvas.queue_redraw()

func _palette() -> void:
	palette.clear()
	for id in document.content.templates:
		if not search.text.is_empty() and not str(id).to_lower().contains(search.text.to_lower()): continue
		palette.add_item(str(id))
		palette.set_item_metadata(palette.item_count-1,id)
		if tool == "Place" and id == placement_template: palette.select(palette.item_count-1)

func select_tool() -> void:
	tool = "Select"
	placement_template = ""
	palette.deselect_all()
	status.text = "Select an entity on the map or in the setup tree"

func _unhandled_key_input(event: InputEvent) -> void:
	if overlay.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		select_tool()
		get_viewport().set_input_as_handled()

func _tree_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_DELETE:
		delete_selected()
		tree.accept_event()

func navigate(kind: String, id: String) -> void:
	select_tool()
	selected_kind = kind
	selected_id = id
	panels.Inspector.open_panel()
	_refresh(true)

func _select() -> void:
	if suppress: return
	var item := tree.get_selected()
	var metadata: Variant = item.get_metadata(0)
	if not metadata is Array: return
	select_tool()
	selected_kind = metadata[0]
	selected_id = metadata[1]
	if selected_kind == "rooms": room_id = selected_id
	if selected_kind == "instances": room_id = document.content.instances[selected_id].room
	_inspect()
	canvas.queue_redraw()

func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(label)

func _inspect() -> void:
	for child in inspector.get_children(): inspector.remove_child(child); child.queue_free()
	_label(selected_kind.capitalize() + " / " + selected_id)
	if history_mode:
		var state := inspected_state()
		_label("Recorded state · read only")
		if selected_kind == "instances":
			_label(JSON.stringify(state.get("actors",{}).get(selected_id,state.get("prop_states",{}).get(selected_id,{})),"  "))
			_label(JSON.stringify(state.get("actor_diagnostics",{}).get(selected_id,{}),"  "))
		_label(JSON.stringify(state.get("authoring_diagnostics",{"status":"Historical diagnostics unavailable for this recording"}),"  "))
		return
	var collection: Variant = document.content.get(selected_kind,{})
	var value: Variant = null
	if collection is Dictionary: value = collection.get(selected_id)
	else:
		for entry in collection:
			if entry.id == selected_id: value = entry
	if value == null: return
	if value is Dictionary:
		for field in value:
			if value[field] is Dictionary or value[field] is Array: continue
			_label(str(field).capitalize())
			if value[field] is bool:
				var check := CheckBox.new()
				check.button_pressed = value[field]
				check.toggled.connect(func(enabled): _set_field(field,enabled))
				inspector.add_child(check)
			elif value[field] is int or value[field] is float:
				var spin := SpinBox.new()
				spin.min_value = -10000
				spin.max_value = 100000
				spin.value = value[field]
				spin.value_changed.connect(func(number): _set_field(field,number))
				inspector.add_child(spin)
			else:
				var input := LineEdit.new()
				input.text = str(value[field])
				input.text_submitted.connect(func(text): _set_field(field,text))
				inspector.add_child(input)
	if selected_kind == "schedules":
		_button(inspector,"Add destination in this room",add_commitment)
		_label("Custom mode uses commitments. Mission mode retains mission reactions and uses its authored route stages.")
		for index in value.get("commitments",[]).size():
			_label("Destination %d time" % (index+1))
			var timeline := HSlider.new()
			timeline.max_value = 10800
			timeline.step = 1
			timeline.value = value.commitments[index].tick
			inspector.add_child(timeline)
			timeline.drag_started.connect(func(): document.finish_edit_group())
			timeline.drag_ended.connect(func(changed):
				if changed:
					var next := document.content.duplicate(true)
					next.schedules[selected_id].commitments[index].tick = int(timeline.value)
					document.replace_content(next,"Move scheduled commitment"))
	if selected_kind == "connections":
		_button(inspector,"Place endpoint A in this room",func(): tool = "Endpoint A")
		_button(inspector,"Place endpoint B in this room",func(): tool = "Endpoint B")
	if selected_kind == "instances":
		var resolved := Content.resolve(document.content,selected_id)
		_label("Template: " + str(value.template))
		if resolved.kind == "character" and document.content.schedules.has(selected_id):
			_button(inspector,"Open character schedule",navigate.bind("schedules",selected_id))
		for story in document.content.storylets:
			if story.get("participants",[]).has(selected_id):
				_button(inspector,"Storylet: " + str(story.id),navigate.bind("storylets",str(story.id)))
		_button(inspector,"Move: click map",func(): tool = "Move")
		for field in resolved:
			if field in ["id","room","position"]: continue
			_label(str(field) + (" (override)" if value.overrides.has(field) else " (inherited)"))
			var input := LineEdit.new()
			input.text = JSON.stringify(resolved[field])
			inspector.add_child(input)
			input.text_submitted.connect(func(text): _override(field,text))
			_button(inspector,"Reset " + str(field),func():
				var next := document.content.duplicate(true)
				next.instances[selected_id].overrides.erase(field)
				document.replace_content(next,"Reset " + str(field)))
	_label("Definition (JSON). Save keeps invalid source as a recoverable draft.")
	var edit := CodeEdit.new()
	edit.custom_minimum_size = Vector2(260,210)
	edit.text = str(document.scene_drafts.get(selected_id,value)) if selected_kind == "scenes" else JSON.stringify(value,"  ")
	inspector.add_child(edit)
	if selected_kind == "scenes":
		var scene_id := selected_id
		edit.text_changed.connect(func(): document.set_scene_source(scene_id,edit.text))
	_button(inspector,"Save definition",func():
		if selected_kind == "scenes": document.set_scene_source(selected_id,edit.text)
		else: _save_definition(edit.text))

func _set_field(field: String, value: Variant) -> void:
	if history_mode: return
	var next := document.content.duplicate(true)
	if next[selected_kind] is Dictionary: next[selected_kind][selected_id][field] = value
	else:
		for item in next[selected_kind]:
			if item.id == selected_id: item[field] = value
	document.replace_content(next,"Edit " + field)

func add_commitment() -> void:
	if history_mode or selected_kind != "schedules": return
	var next := document.content.duplicate(true)
	next.schedules[selected_id].mode = "custom"
	next.schedules[selected_id].commitments.append({"tick":int(game.sim.s.tick)+100,"room":room_id,"position":[580,350],"speed":10})
	document.replace_content(next,"Add scheduled destination")

func _override(field: String, text: String) -> void:
	var parser := JSON.new()
	if parser.parse(text) != OK: status.text = parser.get_error_message(); return
	var next := document.content.duplicate(true)
	next.instances[selected_id].overrides[field] = parser.data
	document.replace_content(next,"Override " + field)

func _save_definition(text: String) -> void:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		# Preserve the unfinished edit in the shared, persisted source draft.
		document.set_scenario_source(document.scenario_draft + "\n/* Unfinished " + selected_kind + "/" + selected_id + " */\n" + text)
		status.text = "Unfinished definition saved in Source; correct it before resuming"
		return
	var next := document.content.duplicate(true)
	if next[selected_kind] is Dictionary: next[selected_kind][selected_id] = parser.data
	else:
		for index in next[selected_kind].size():
			if next[selected_kind][index].id == selected_id: next[selected_kind][index] = parser.data
	document.set_scenario_source(JSON.stringify(next,"\t"))
	document.finish_edit_group()
	status.text = document.scenario_error if not document.scenario_error.is_empty() else "Definition saved"

func _unique(collection: Dictionary, base: String) -> String:
	var id := base
	var number := 2
	while collection.has(id): id = base + "_" + str(number); number += 1
	return id

func map_click(point: Vector2) -> void:
	if history_mode: return
	var next := document.content.duplicate(true)
	if tool in ["Endpoint A","Endpoint B"]:
		var side := "a" if tool == "Endpoint A" else "b"
		for connection in next.connections:
			if connection.id == selected_id:
				connection[side] = room_id
				connection[side+"p"] = [point.x,point.y]
				connection[side+"_bounds"] = [point.x-20,point.y-20,40,40]
				connection[side+"_arrival"] = [point.x,point.y+40]
		document.replace_content(next,"Place room connection endpoint")
		tool = "Select"
	elif tool == "Place" and next.templates.has(placement_template):
		var id := _unique(next.instances,placement_template)
		next.instances[id] = {"template":placement_template,"room":room_id,"position":[point.x,point.y],"overrides":{}}
		if next.templates[placement_template].kind == "character":
			next.actors.append({"id":id})
			next.schedules[id] = {"mode":"custom","commitments":[]}
		selected_kind = "instances"
		selected_id = id
		select_tool()
		document.replace_content(next,"Place " + id)
	elif tool == "Move" and next.instances.has(selected_id):
		next.instances[selected_id].position = [point.x,point.y]
		next.instances[selected_id].room = room_id
		document.replace_content(next,"Move " + selected_id)
		tool = "Select"
	else:
		var distance := 30.0
		for id in next.instances:
			var item: Dictionary = next.instances[id]
			var candidate := point.distance_to(Vector2(item.position[0],item.position[1]))
			if item.room == room_id and candidate < distance:
				distance = candidate
				selected_kind = "instances"
				selected_id = id
		_refresh(true)

func new_room() -> void:
	if history_mode: return
	var next := document.content.duplicate(true)
	room_id = _unique(next.rooms,"room")
	next.rooms[room_id] = {"title":"New room","size":[1175,700],"scene":"","background_asset":"","blocked":{}}
	selected_kind = "rooms"
	selected_id = room_id
	document.replace_content(next,"Create room")

func new_template() -> void:
	if history_mode: return
	var next := document.content.duplicate(true)
	selected_id = _unique(next.templates,"template")
	selected_kind = "templates"
	next.templates[selected_id] = next.templates.prop.duplicate(true)
	document.replace_content(next,"Create template")

func save_as_template() -> void:
	if history_mode or selected_kind != "instances": return
	var next := document.content.duplicate(true)
	var entity := Content.resolve(next,selected_id)
	for key in ["id","room","position"]: entity.erase(key)
	var id := _unique(next.templates,selected_id + "_template")
	next.templates[id] = entity
	next.instances[selected_id].template = id
	next.instances[selected_id].overrides = {}
	document.replace_content(next,"Save entity as template")

func duplicate_entity() -> void:
	if history_mode or selected_kind != "instances": return
	var next := document.content.duplicate(true)
	var id := _unique(next.instances,selected_id)
	next.instances[id] = next.instances[selected_id].duplicate(true)
	next.instances[id].erase("builtin")
	next.instances[id].position[0] += 25
	if next.schedules.has(selected_id):
		next.schedules[id] = {"mode":"custom","commitments":[]}
		next.actors.append({"id":id})
	selected_id = id
	document.replace_content(next,"Duplicate entity")

func delete_selected() -> void:
	if history_mode: return
	var next := document.content.duplicate(true)
	if selected_kind == "templates":
		for entity in next.instances.values():
			if entity.template == selected_id: status.text = "Reassign instances before deleting their template"; return
	if selected_kind == "rooms" and next.rooms.size() == 1: status.text = "Keep at least one room"; return
	if selected_kind == "instances" and selected_id == "amelia": status.text = "The player entity is required"; return
	if next[selected_kind] is Dictionary: next[selected_kind].erase(selected_id)
	else: next[selected_kind] = next[selected_kind].filter(func(item): return item.id != selected_id)
	var deleted_id := selected_id
	if selected_kind == "instances":
		next.schedules.erase(selected_id)
		next.actors = next.actors.filter(func(actor): return actor.id != selected_id)
	select_tool()
	selected_kind = "rooms"
	selected_id = room_id if next.rooms.has(room_id) else str(next.rooms.keys()[0])
	document.replace_content(next,"Delete " + deleted_id)
	_refresh(true)

func new_storylet() -> void:
	if history_mode: return
	var next := document.content.duplicate(true)
	var ids := {}
	for story in next.storylets: ids[story.id] = true
	selected_id = _unique(ids,"storylet")
	selected_kind = "storylets"
	next.storylets.append({"id":selected_id,"room":room_id,"participants":[],"start_tick":0,"end_tick":10800,"priority":0,"repeat":false,"conditions":[],"effects":[],"scene":""})
	document.replace_content(next,"Create storylet")

func new_scene() -> void:
	if history_mode: return
	var next := document.content.duplicate(true)
	selected_id = _unique(next.scenes,"scene")
	selected_kind = "scenes"
	next.scenes[selected_id] = "~ start\namelia: A new scene.\n=> END"
	document.replace_content(next,"Create scene")

func new_connection() -> void:
	if history_mode: return
	var next := document.content.duplicate(true)
	var ids: Array = next.rooms.keys().filter(func(id): return id != room_id)
	if ids.is_empty(): status.text = "Create a second room first"; return
	var existing := {}
	for connection in next.connections: existing[connection.id] = true
	selected_id = _unique(existing,"connection")
	selected_kind = "connections"
	next.connections.append({"id":selected_id,"a":room_id,"ap":[580,350],"b":ids[0],"bp":[580,350]})
	document.replace_content(next,"Connect rooms")
	status.text = "Choose a room and place each endpoint using the Inspector"

func inspected_state() -> Dictionary:
	return game.sim.history[viewed_frame] if viewed_frame >= 0 and viewed_frame < game.sim.history.size() else game.sim.s

func history_click(point: Vector2) -> void:
	var state := inspected_state()
	var actors: Dictionary = state.get("actors",{}).duplicate()
	actors.amelia = {"room":state.room,"pos":state.pos}
	for id in actors:
		var actor: Dictionary = actors[id]
		if actor.room == room_id and point.distance_to(Vector2(actor.pos[0],actor.pos[1])) <= 25:
			selected_kind = "instances"
			selected_id = id
			_inspect()
			canvas.queue_redraw()
			return

func shown_content() -> Dictionary:
	if not history_mode: return document.content
	var version := str(inspected_state().get("content_version", ""))
	return game.sim.content_versions.get(version,game.sim.content_versions.get("legacy",document.applied_content))

func _apply(from_history: bool) -> bool:
	canvas.finish_stroke()
	var errors := document.validate()
	if not errors.is_empty(): status.text = "; ".join(errors); return false
	var candidate := document.candidate()
	var result: Dictionary = game.sim.apply_authored(candidate,viewed_frame if from_history else -1)
	if not result.ok: status.text = result.reason; return false
	document.applied_content = candidate.duplicate(true)
	document.content = candidate.duplicate(true)
	save_pending = true
	_save_draft()
	if from_history: game.journal.saved_count = 0
	return true

func resume(from_history := false) -> void:
	if not _apply(from_history): return
	overlay.hide()
	get_viewport().gui_release_focus()
	get_tree().paused = false
	game.accumulator = 0
	game.shown_room = ""
	game._content_key = ""
	for actor in game.actors.values():
		game.entity_layer.remove_child(actor)
		actor.queue_free()
	game.actors.clear()
	game._refresh()
	game._persist()

func step(next_event: bool) -> void:
	if not _apply(false): return
	for i in (10000 if next_event else 1):
		game.sim.step()
		if not next_event or not game.sim.events.is_empty() or game.sim.s.finished: break
	viewed_frame = -1
	history_mode = true
	tabs.current_tab = 1
	_refresh()

func restart() -> void:
	var errors := document.validate()
	if not errors.is_empty(): status.text = "; ".join(errors); return
	canvas.finish_stroke()
	game.pending_authoring_restart = document.candidate()
	game.rewind_start = game.sim.history.size()-1
	game.rewind_index = game.rewind_start
	game.rewind_accumulator = 0.0
	game.diary_open = false
	overlay.hide()
	get_tree().paused = false
	game._refresh()

func import_background() -> void:
	if history_mode: return
	if OS.has_feature("web"):
		web_callback = JavaScriptBridge.create_callback(_web_image)
		JavaScriptBridge.get_interface("window").set("__missionImage",web_callback)
		JavaScriptBridge.eval("(()=>{const i=document.createElement('input');i.type='file';i.accept='image/png,image/jpeg,image/webp';i.onchange=async()=>{const f=i.files[0];if(!f)return;const r=new FileReader();r.onload=()=>window.__missionImage(f.name,r.result.split(',')[1]);r.readAsDataURL(f)};i.click()})()")
	else:
		if asset_dialog == null:
			asset_dialog = FileDialog.new()
			asset_dialog.access = FileDialog.ACCESS_FILESYSTEM
			asset_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			asset_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Images"])
			add_child(asset_dialog)
			asset_dialog.file_selected.connect(func(path): _import_image(path,FileAccess.get_file_as_bytes(path)))
		asset_dialog.popup_centered_ratio(0.7)

func _web_image(arguments: Array) -> void:
	if arguments.size() == 2: _import_image(str(arguments[0]),Marshalls.base64_to_raw(str(arguments[1])))

func _import_image(name: String, bytes: PackedByteArray) -> void:
	var result := Assets.import_image(name,bytes)
	if not result.ok: status.text = result.reason; return
	var next := document.content.duplicate(true)
	next.assets[result.id] = result.asset
	next.rooms[room_id].background_asset = result.id
	document.replace_content(next,"Import room background")

func _exit_tree() -> void:
	_save_draft()
	if is_instance_valid(overlay) and overlay.visible: get_tree().paused = false
