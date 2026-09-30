extends RefCounted
const Text = preload("res://localisation/source_text.gd")
## Exploration-only second leg. Commitments are departure times, in voyage ticks.
const Content = preload("res://mission1/authoring_content.gd")
const Grid = preload("res://mission1/authoring_grid.gd")
const SAVE_PATH := "user://mission2.journal"
const END := 10800 # Six complete hours, 1:00 through 7:00.
const CREW_DOORS := {"crew_cabin_left":205.0,"crew_cabin_middle":580.0,"crew_cabin_right":960.0}

static func seed() -> Dictionary:
	var data := Content.seed({})
	data.version = "mission2-layout-8"
	data.settings.mission = 2
	data.rooms.erase("docks")
	data.connections = data.connections.filter(func(door): return door.a != "docks" and door.b != "docks")
	data.timings.end = END
	data.storylets = []
	data.scenes = {}
	data.texts = {}
	data.rooms.passage.title = Text.MISSION2_SERVICE_CORRIDOR_CREW_CABINS
	data.rooms.passage.scene = "07_crew_cabins"
	data.rooms.salon.scene = "09_salon_open"
	data.rooms.passage.floor_regions = [[40,415,1060,125],[0,375,45,100],[40,410,55,65],[130,235,220,65],[490,235,240,65],[870,235,220,65],[190,290,30,140],[565,290,30,140],[945,290,30,140],[675,530,90,150]]
	data.rooms.passage.blocked = Grid.migrate(data.rooms.passage.floor_regions)
	data.rooms.foredeck = {"title":Text.MISSION2_FOREDECK,"scene":"08_foredeck","background_asset":"","size":[1175,700],"blocked":Grid.migrate([[170,260,840,340],[330,210,570,100],[975,365,85,100]])}
	for door in data.connections:
		if door.a == "passage" and door.b == "controls":
			door.ap = [720,650]
			door.a_bounds = [675,630,90,50]
			door.a_arrival = [720,560]
	data.connections.append({"id":"foredeck","a":"salon","ap":[80,520],"a_bounds":[40,480,90,105],"a_arrival":[190,520],"b":"foredeck","bp":[1030,420],"b_bounds":[1010,365,50,100],"b_arrival":[940,420]})
	# Only scenery and cabin doors survive from the first leg's props.
	for id in data.instances.keys():
		if Content.resolve(data,id).kind != "character" and id not in ["chandelier","cabin_left","cabin_middle","cabin_right"]:
			data.instances.erase(id)
	for id in ["chandelier","cabin_left","cabin_middle","cabin_right"]:
		data.templates[id].transitions = []
		data.templates[id].initial_state = "fallen" if id == "chandelier" else "open"
	data.templates.janitor = {"kind":"prop","name":"Janitor","appearance":"janitor","initial_state":"sweeping","states":{"sweeping":{"appearance":"sweeping","visible":true,"solid":true,"bounds":[-10,-12,20,18]}},"transitions":[],"interactions":[]}
	data.instances.janitor = {"template":"janitor","room":"foyer","position":[675,385],"overrides":{},"builtin":true}
	for id in CREW_DOORS:
		data.templates[id] = {"kind":"door","name":Text.MISSION2_CREW_CABIN_DOOR,"appearance":"crew_door","initial_state":"closed","states":{"closed":{"appearance":"closed","visible":true,"solid":true,"bounds":[-35,-75,70,80]},"open":{"appearance":"open","visible":false,"solid":false}},"transitions":[{"state":"closed","conditions":[]},{"state":"open","conditions":[{"flag":id,"equals":true}]}],"interactions":[]}
		data.instances[id] = {"template":id,"room":"passage","position":[CREW_DOORS[id],405],"overrides":{},"builtin":true}
	data.instances.amelia.room = "passage"
	data.instances.amelia.position = [205,275]
	var places := {
		"cabin1":["cabins",[225,315]],"cabin2":["cabins",[580,315]],"cabin3":["cabins",[935,315]],
		"crew1":["passage",[205,275]],"crew2":["passage",[580,275]],"crew3":["passage",[955,275]],
		"foyer":["foyer",[740,490]],"salon":["salon",[700,390]],"foredeck":["foredeck",[600,390]],
		"engine":["controls",[310,340]],"steam":["controls",[840,400]]}
	var routes := {
		"guest":["cabin2","salon","foredeck","foyer","salon","cabin2"],
		"chandelier_guest":["cabin1","foredeck","salon","cabin1","foyer","salon"],
		"chatterbox":["cabin3","foyer","salon","foredeck","cabin3","salon"],
		"captain":["foredeck","foyer","engine","salon","foredeck","foyer"],
		"crew":["engine","steam","crew2","engine","steam","crew2"],
		"porter":["foyer","cabin2","salon","foyer","cabin1","crew3"],
		"dock_sailor":["crew3","salon","foredeck","steam","crew3","foyer"],
		"incidental_sailor_1":["crew2","steam","foredeck","crew2","engine","salon"],
		"incidental_sailor_2":["crew3","foredeck","engine","steam","crew3","foyer"],
		"incidental_sailor_3":["steam","crew2","foyer","foredeck","steam","crew2"],
		"incidental_guest_1":["salon","foredeck","foyer","salon","cabin1","foredeck"],
		"incidental_guest_2":["foredeck","salon","cabin3","foyer","foredeck","salon"],
		"incidental_guest_3":["foyer","cabin1","foredeck","salon","foyer","foredeck"],
		"incidental_guest_4":["cabin2","foyer","salon","foredeck","salon","cabin2"]}
	var index := 0
	for id in routes:
		var commitments := []
		for hour in 6:
			var place: Array = places[routes[id][hour]]
			var p: Array = place[1].duplicate()
			# Offset shared destinations so people have room to stand.
			p[0] += (index % 3 - 1) * 30
			p[1] += (index % 2) * (15 if str(routes[id][hour]).begins_with("crew") else 30)
			commitments.append({"tick":hour*1800+(index*13 if hour > 0 else 0),"room":place[0],"position":p,"action":"idle","facing":"down"})
		data.instances[id].room = commitments[0].room
		data.instances[id].position = commitments[0].position.duplicate()
		data.schedules[id] = {"mode":"custom","commitments":commitments}
		index += 1
	return data
