extends RefCounted
const Text = preload("res://localisation/source_text.gd")
## Greek arrival retains the second leg's entire ship and shared characters.
const Previous = preload("res://mission2/content.gd")
const Grid = preload("res://mission1/authoring_grid.gd")
const SAVE_PATH := "user://mission3.journal"

static func seed() -> Dictionary:
	var data := Previous.seed()
	data.version = "mission3-layout-6"
	data.settings.mission = 3
	for id in ["chandelier","janitor"]:
		data.instances.erase(id)
		data.templates.erase(id)
	# The ship was at sea in Mission 2. Restore the gangway for this port call.
	data.connections.append({"id":"greek_gangway","a":"docks","ap":[580,105],"a_bounds":[525,75,110,55],"a_arrival":[580,205],"b":"foyer","bp":[580,650],"b_bounds":[525,630,110,55],"b_arrival":[580,575]})
	data.rooms.docks = room(Text.MISSION3_GREEK_DOCK, "greek_docks", [[200,225,975,450],[525,75,110,180],[100,400,200,275],[25,400,175,50]], [[1100,225,75,50]])
	data.rooms.restaurant = room(Text.MISSION3_RESTAURANT_DINING_ROOM_AND_KITCHEN, "restaurant", [[150,225,875,450],[1000,425,125,50],[275,175,650,100]], [[375,175,125,50],[700,175,125,50],[350,275,100,100],[725,275,100,100],[350,450,100,100],[725,450,100,100]])
	data.rooms.market = room("Market", "market", [[125,200,925,475],[0,325,200,350]], [[200,175,125,75],[375,125,125,75],[550,100,125,100],[725,125,125,75],[900,175,125,75],[450,300,125,100],[700,300,125,100]])
	data.connections.append({"id":"greek_restaurant","a":"docks","ap":[40,425],"a_bounds":[25,400,50,50],"a_arrival":[110,425],"b":"restaurant","bp":[1090,450],"b_bounds":[1075,425,50,50],"b_arrival":[1010,450]})
	data.connections.append({"id":"greek_market","a":"docks","ap":[1140,500],"a_bounds":[1125,275,50,400],"a_arrival":[1060,500],"b":"market","bp":[25,500],"b_bounds":[0,325,50,350],"b_arrival":[90,500]})
	# Keep the player's own crew cabin as the start of each new leg.
	# Guests make shore visits while the remaining crew keep their ship routines.
	for id in ["guest","chandelier_guest","chatterbox","incidental_guest_1","incidental_guest_2"]:
		var visits: Array = data.schedules[id].commitments
		visits[1].room = "docks"
		visits[1].position = [700,450]
		visits[2].room = "restaurant"
		visits[2].position = [600,450]
		visits[3].room = "market"
		visits[3].position = [600,550]
	return data

static func room(title: String, scene: String, floors: Array, obstacles: Array) -> Dictionary:
	var blocked := Grid.migrate(floors)
	for box in obstacles:
		for y in range(int(box[1]/25),ceili(float(box[1]+box[3])/25)):
			for x in range(int(box[0]/25),ceili(float(box[0]+box[2])/25)):
				blocked[Grid.key(Vector2i(x,y))] = true
	return {"title":title,"scene":"../mission_3/"+scene,"background_asset":"","size":[1175,700],"blocked":blocked}
