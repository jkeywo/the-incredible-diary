extends RefCounted
const Text = preload("res://localisation/source_text.gd")
## Deterministic 10 Hz Mission 1 simulation. No rendering or wall clock dependencies.
const Messages = preload("res://foundation/message_text.gd")
const Rooms = preload("res://mission1/rooms.gd")
const Routines = preload("res://mission1/routines.gd")
const Conversations = preload("res://mission1/conversations.gd")
const Crowd = preload("res://mission1/crowd.gd")
const Hospitality = preload("res://mission1/hospitality.gd")
const Reactions = preload("res://mission1/reactions.gd")
const Operator = preload("res://mission1/operator.gd")
const Hints = preload("res://mission1/tutorial_hints.gd")
const Departure = preload("res://mission1/departure.gd")
const CAPTAIN := Vector2(650,280)
const BRIEFING := [["captain",Text.MISSION1_BOY_REPORT_FOR_DUTY],["amelia",Text.MISSION1_YES_CAPTAIN],["captain",Text.MISSION1_EXPLORE_THE_SHIP_AND_MAKE_SURE_OUR_GUESTS_ARE_COMFORTABLE_HELP_WI],["amelia",Text.MISSION1_VERY_GOOD_CAPTAIN],["captain",Text.MISSION1_PASSENGERS_ARE_COMING_ABOARD_GET_TO_IT]]
const Authored = preload("res://mission1/authoring_runtime.gd")
var authored_content: Dictionary = {}
var content_versions: Dictionary = {}
var opening_enabled := true
const HOUR := 1800
const CLOCK_RATE := 1.5
const POISON := 4 * HOUR + HOUR / 4
const END := 4 * HOUR + HOUR / 2
const CREAK := 2 * HOUR + 480
const FALL := CREAK + 80
const DROP_TICKS := 12
const DROP_FRAMES := 8
const TRAP := 3 * HOUR + 100
const STEAM_FATAL := 3 * HOUR + 600
const DEMO_START := HOUR + 50
const DEMO_END := HOUR + 500
var s: Dictionary
var memory: Dictionary = {"notes":[], "bag":false, "procedure":false, "shortcut":false, "reset":false, "completed":false}
var history: Array = []
var events: Array[Dictionary] = []

func _init(with_opening := true) -> void:
 opening_enabled = with_opening
 reset()

func reset() -> void:
 if exploration():
  var content := authored_content
  authored_content = {}
  reset()
  authored_content = content
  _reset_exploration_content()
  return
 memory.notes = []
 memory.note_records = []
 var loop := int(s.get("loop", -1)) + 1
 var previous_code: String = s.get("code","")
 var value := randi_range(0,215)
 if not previous_code.is_empty():
  var previous_value := 0
  for digit in range(3): previous_value += (int(previous_code[digit])-1)*int(pow(6,digit))
  value = (previous_value+randi_range(1,215))%216
 var code := ""
 for i in 3:
  code += str(value % 6 + 1)
  value = int(value / 6)
 s = {"tick":0, "loop":loop, "room":"docks", "pos":[580.0,490.0], "facing":"down", "code":code,
  "flags":{"shortcut":true}, "dead":[], "safe":[], "action":{}, "entry":"", "code_open":false,
  "dialogue":{}, "observed":[], "message":Text.MISSION1_A_NEW_POSTING_AN_UNMOORING_PARTY_WHAT_COULD_POSSIBLY_GO_WRONG,
 "finished":false, "door_cooldown":0}
 s.frame = 0
 s.tutorial = "approach" if opening_enabled and loop == 0 else "done"
 s.arrivals = opening_enabled
 Hospitality.defaults(self)
 _open_passenger_doors(_planned_actors())
 s.actors = actor_positions()
 if not authored_content.is_empty():
  var player := preload("res://mission1/authoring_content.gd").resolve(authored_content,"amelia")
  s.room = player.room
  s.pos = player.position.duplicate()
  s.content_version = authored_content.version
  s.prop_states = {}
  for id in authored_content.instances:
   var entity := preload("res://mission1/authoring_content.gd").resolve(authored_content,id)
   if entity.kind != "character": s.prop_states[id] = entity.get("initial_state","idle")
 _record_text_fields(true)
 history = [s.duplicate(true)]
 events.clear()

func tutorial_active() -> bool:
 return s.get("tutorial","done") != "done"

func display_name(id: String) -> String:
 var entity := preload("res://mission1/authoring_content.gd").resolve(authored_content,id)
 if not entity.is_empty(): return str(entity.get("name",id))
 if id.begins_with("sendoff_guest_"): return Text.MISSION1_GUEST
 if id.begins_with("incidental_"): return Text.MISSION1_SAILOR if id.contains("sailor") else Text.MISSION1_GUEST
 if Hospitality.GUESTS.has(id): return Hospitality.GUESTS[id].name
 return {"amelia":Text.MISSION1_BOY,"captain":Text.MISSION1_CAPTAIN,"crew":Text.MISSION1_SAILOR,"dock_sailor":Text.MISSION1_SAILOR,"porter":Text.MISSION1_PORTER}.get(id,id.capitalize())

func flag(key: String) -> bool:
 return bool(s.flags.get(key, false))

func note(key: String, text: String, permanent := true, show_message := true, message_ref: Dictionary = {}) -> void:
 var original := text
 text = str(authored_content.get("texts",{}).get(text,text))
 if message_ref.is_empty(): message_ref = Messages.capture(text) if text == original else Messages.literal(text)
 if s.observed.has(key): return
 s.observed.append(key)
 var line := "%s — %s" % [observation_time(int(s.tick)), text]
 if permanent:
  while memory.get_or_add("note_records",[]).size() < memory.notes.size(): memory.note_records.append({})
  memory.notes.append(line)
  memory.note_records.append({"tick":int(s.tick),"text_ref":message_ref.duplicate(true),"fallback":line})
 if show_message:
  s.message = text
  s.message_ref = message_ref.duplicate(true)
 if key in ["bag_inspect","bag_reminder","poison_evidence","stair_reminder"]:
  s.message = ""
  Conversations.say(self,"amelia",text,"thought")
 events.append({"kind":"observation", "text":text})

func nearby(room: String, p: Vector2, radius := 80.0) -> bool:
 return s.room == room and Rooms.point(s.pos).distance_to(p) <= radius

func options(local := true) -> Array[Dictionary]:
 var prior := Rooms.authored
 var prior_connections := Rooms.authored_connections
 var prior_states := Rooms.prop_states
 Rooms.prop_states = s.get("prop_states",{})
 var prior_behaviour := Rooms.behaviour
 Rooms.behaviour = authored_content
 Rooms.authored = authored_content.get("rooms", {})
 Rooms.authored_connections = authored_content.get("connections", [])
 var result := Authored.options(self, _authored_options(local), local) if s.action.is_empty() and not s.finished else _authored_options(local)
 Rooms.authored = prior
 Rooms.authored_connections = prior_connections
 Rooms.behaviour = prior_behaviour
 Rooms.prop_states = prior_states
 return result

func _authored_options(local := true) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 if not s.action.is_empty() or s.finished: return result
 if exploration():
  for id in preload("res://mission2/content.gd").CREW_DOORS:
   var x: float = preload("res://mission2/content.gd").CREW_DOORS[id]
   var bounds := Rect2(x-35,330,70,80)
   var occupied: bool = s.room == "passage" and bounds.has_point(Rooms.point(s.pos))
   for actor in s.actors.values():
    if actor.room == "passage" and bounds.grow(8).has_point(Rooms.point(actor.pos)): occupied = true
   _option(result,id,Text.MISSION1_CLOSE_DOOR if flag(id) else Text.MISSION1_OPEN_DOOR,"passage",Vector2(x,385),local,not (flag(id) and occupied))
  return nearest_options(result) if local else result
 if not s.action.is_empty() or s.finished: return result
 if tutorial_active():
  _option(result,"report",Text.MISSION1_REPORT_FOR_DUTY,"docks",CAPTAIN,local,s.tutorial == "approach")
  return result
 Hospitality.defaults(self)
 if s.hospitality.menu != "":
  Hospitality.options(self,result,local)
  return result
 _option(result, "inspect_bag", Text.MISSION1_INSPECT_LUGGAGE, "docks", Rooms.LUGGAGE, local, not flag("bag_found"))
 _option(result, "retrieve_bag", Text.MISSION1_RETRIEVE_BAG, "docks", Rooms.LUGGAGE, local, not flag("bag_found"))
 _option(result, "hide_bag", Text.MISSION1_HIDE_BAG, "docks", Rooms.LUGGAGE, local, not flag("bag_found") and not flag("bag_hidden") and s.tick < 700)
 for id in Rooms.CABIN_DOORS:
  var occupied: bool = s.room == "cabins" and Rooms.door_bounds(id).has_point(Rooms.point(s.pos))
  for actor in s.actors.values():
   if actor.room == "cabins" and Rooms.door_bounds(id).grow(8).has_point(Rooms.point(actor.pos)): occupied = true
  _option(result, id, Text.MISSION1_CLOSE_DOOR if flag(id) else Text.MISSION1_OPEN_DOOR, "cabins", Vector2(Rooms.CABIN_DOORS[id],405), local, not (flag(id) and occupied))
 _rescue_options(result, local)
 Hospitality.options(self,result,local)
 return nearest_options(result) if local else result

func _option(result: Array[Dictionary], id: String, label: String, room: String, p: Vector2, local: bool, eligible: bool) -> void:
 if eligible and s.room == room and (not local or nearby(room, p)):
  result.append({"id":id, "label":label, "pos":[p.x,p.y], "room":room,"target":interaction_target(id)})

func interaction_target(id: String) -> String:
 if preload("res://mission2/content.gd").CREW_DOORS.has(id): return id
 if id.begins_with("collect:") or id == "return_drink": return "bar"
 if id == "duties_back": return str(s.hospitality.menu)
 var parts := id.split(":")
 if parts[0] in ["request","serve","directions","direct"]: return parts[1]
 if parts[0] == "plate": return parts[1]
 if Rooms.CABIN_DOORS.has(id): return id
 return {"report":"captain","inspect_bag":"suitcase","retrieve_bag":"suitcase","hide_bag":"suitcase","panel":"code_panel","bump":"guest","glass":"drink","shove":"chandelier_guest","apologise":"guest","wreckage":"chandelier"}.get(id,"")

func start(id: String) -> bool:
 for item in options():
  if item.id == id:
   if id.begins_with("authored:"):
    var definition := Authored.interaction(self,id)
    s.action = {"id":id,"progress":0,"duration":int(definition.get("duration",10)),"pos":item.pos,"room":item.room}
    return true
   memory.interactions = int(memory.get("interactions",0))+1
   if id == "report":
    s.tutorial = "briefing"
    Conversations.start(self,"captain_briefing",BRIEFING,["captain","amelia"])
    return true
   if id.begins_with("directions:") or id.begins_with("request:") or id.begins_with("serve:") or id.begins_with("direct:") or id == "duties_back":
    Hospitality.complete(self,id)
    return true
   if id == "panel":
    s.code_open = true
    s.entry = ""
   else:
    s.action = {"id":id, "progress":0, "duration":20 if id == "hide_bag" else 10, "pos":item.pos, "room":item.room}
   return true
 return false

func step(direction := Vector2.ZERO, cancel := false) -> void:
 var prior := Rooms.authored
 var prior_connections := Rooms.authored_connections
 var prior_states := Rooms.prop_states
 Rooms.prop_states = s.get("prop_states",{})
 var prior_behaviour := Rooms.behaviour
 Rooms.behaviour = authored_content
 Rooms.authored = authored_content.get("rooms", {})
 Rooms.authored_connections = authored_content.get("connections", [])
 _authored_step(direction, cancel)
 Rooms.authored = prior
 Rooms.authored_connections = prior_connections
 Rooms.behaviour = prior_behaviour
 Rooms.prop_states = prior_states

func _authored_step(direction := Vector2.ZERO, cancel := false) -> void:
 if exploration():
  _exploration_step(direction,cancel)
  return
 if s.finished: return
 events.clear()
 s.frame = int(s.get("frame",s.tick))+1
 if tutorial_active():
  _tutorial_step(direction)
  Authored.update(self)
  _record_text_fields()
  history.append(s.duplicate(true))
  return
 var player_before := {"room":s.room,"pos":s.pos.duplicate()}
 var previous_tick := int(s.tick)
 s.door_cooldown = maxi(0, int(s.door_cooldown)-1)
 if direction.length_squared() > 0.01:
  var p := Crowd.move_player(s.room, Rooms.point(s.pos), direction.limit_length() * 14.0, s.flags, s.actors)
  s.pos = [p.x,p.y]
  _locked_door_feedback(p)
  s.facing = ("right" if direction.x > 0 else "left") if absf(direction.x)>absf(direction.y) else ("down" if direction.y>0 else "up")
  if s.door_cooldown == 0:
   for door in Rooms.exits(s.room, flag("shortcut")):
    if door.bounds.has_point(p) and Rooms.arrival_open(door.room,Rooms.point(door.arrival),s.flags) and Crowd.clear(door.room,Rooms.point(door.arrival),s.actors):
     s.room = door.room
     s.pos = door.arrival.duplicate()
     s.door_cooldown = 12
     s.code_open = false
     events.append({"kind":"room", "text":s.room})
     break
 if not s.action.is_empty():
  var action: Dictionary = s.action
  if cancel or not nearby(action.room, Rooms.point(action.pos)) or not _still_valid(action.id):
   s.action = {}
   s.message = Text.MISSION1_ACTION_INTERRUPTED_UNFINISHED_PROGRESS_LOST
  else:
   action.progress += 1
   if action.progress >= action.duration:
    s.action = {}
    _complete(action.id)
 if s.code_open and not nearby("controls", Vector2(350,300)): s.code_open = false
 var clock_progress := float(s.get("clock_fraction",0.0))+CLOCK_RATE
 var ticks := int(clock_progress)
 s.clock_fraction = clock_progress-ticks
 for elapsed in ticks:
  s.tick = mini(previous_tick+elapsed+1,timing("end", END))
  if s.tick % HOUR == 0: events.append({"kind":"sound","text":"hour_chime"})
  _schedule()
  if s.tick % HOUR == 0:
   s.clock_fraction += ticks-elapsed-1
   break
 _demonstration()
 Operator.update(self)
 Reactions.update(self)
 _advance_shove()
 Hospitality.update(self)
 _open_passenger_doors(_planned_actors())
 _open_passenger_doors(s.actors)
 var previous: Dictionary = s.actors
 s.actors = Crowd.separate(Authored.actors(self, _planned_actors()),s.flags,previous,{"player":{"room":s.room,"pos":s.pos}}, {"player":player_before})
 if s.actors.has("captain") and Rooms.point(s.actors.captain.pos).distance_to(Vector2(580,105)) < 10:
  s.flags.captain_departing = false
  s.actors.erase("captain")
 _witness_departures(previous)
 _observe()
 Hints.update(self)
 Conversations.update(self)
 if s.tick >= timing("end", END):
  s.finished = true
  s.flags.missed_boat = s.dead.is_empty() and s.room == "docks"
  memory.completed = bool(memory.completed) or succeeded()
  if succeeded(): memory.location_rewriting = true
  events.append({"kind":"end", "text":Text.MISSION1_THE_UNMOORING_PARTY_HAS_ENDED})
 Authored.update(self)
 _record_text_fields()
 history.append(s.duplicate(true))

func exploration() -> bool:
 return mission_number() >= 2

func mission_number() -> int:
 return int(authored_content.get("settings",{}).get("mission",1))

func start_mission_two() -> void:
 authored_content = {}
 opening_enabled = false
 reset()
 authored_content = preload("res://mission2/content.gd").seed()
 content_versions = {authored_content.version:authored_content.duplicate(true)}
 _reset_exploration_content()

func start_mission_three() -> void:
 authored_content = {}
 opening_enabled = false
 reset()
 authored_content = preload("res://mission3/content.gd").seed()
 content_versions = {authored_content.version:authored_content.duplicate(true)}
 _reset_exploration_content()

func _reset_exploration_content() -> void:
 var player := preload("res://mission1/authoring_content.gd").resolve(authored_content,"amelia")
 s.room = player.room
 s.pos = player.position.duplicate()
 s.tutorial = "done"
 s.arrivals = false
 s.message = Text.MISSION1_WELCOME_TO_GREECE_EXPLORE_THE_DOCK_RESTAURANT_MARKET_AND_SHIP if mission_number() == 3 else Text.MISSION1_A_NEW_DAY_ABOARD_EXPLORE_THE_SHIP
 s.flags = {"shortcut":true,"cabin_left":true,"cabin_middle":true,"cabin_right":true}
 s.actors = {}
 for id in authored_content.instances:
  var entity := preload("res://mission1/authoring_content.gd").resolve(authored_content,id)
  if entity.kind == "character" and id != "amelia":
   s.actors[id] = {"room":entity.room,"pos":entity.position.duplicate(),"action":"idle","facing":"down"}
 Authored.update(self)
 _record_text_fields(true)
 history = [s.duplicate(true)]

func _locked_door_feedback(p: Vector2) -> void:
 for door in Rooms.locked_doors(s.room,exploration(),mission_number() == 2):
  if door.bounds.has_point(p):
   var text: String = door.get("message",Text.MISSION1_THE_DOOR_IS_LOCKED)
   s.message = text
   var key: String = s.room+str(door.point)
   if s.get("locked_door","") != key or int(s.get("locked_notice_until",0)) <= int(s.frame):
    Conversations.say(self,"amelia",text,"thought")
    s.locked_door = key
    s.locked_notice_until = int(s.frame)+35

func _exploration_step(direction: Vector2, cancel := false) -> void:
 if s.finished: return
 events.clear()
 s.frame = int(s.frame)+1
 s.door_cooldown = maxi(0,int(s.door_cooldown)-1)
 var before := {"room":s.room,"pos":s.pos.duplicate()}
 if direction.length_squared() > 0.01:
  var p := Crowd.move_player(s.room,Rooms.point(s.pos),direction.limit_length()*14.0,s.flags,s.actors)
  s.pos = [p.x,p.y]
  s.facing = ("right" if direction.x > 0 else "left") if absf(direction.x)>absf(direction.y) else ("down" if direction.y>0 else "up")
  _locked_door_feedback(p)
  if s.door_cooldown == 0:
   for door in Rooms.exits(s.room,true):
    if door.bounds.has_point(p) and Rooms.can_stand(door.room,Rooms.point(door.arrival),s.flags) and Crowd.clear(door.room,Rooms.point(door.arrival),s.actors):
     s.room = door.room
     s.pos = door.arrival.duplicate()
     s.door_cooldown = 12
     events.append({"kind":"room","text":s.room})
     break
 if not s.action.is_empty():
  var action: Dictionary = s.action
  if cancel or not nearby(action.room,Rooms.point(action.pos)) or not _still_valid(action.id):
   s.action = {}
  else:
   action.progress += 1
   if action.progress >= action.duration:
    s.action = {}
    _complete(action.id)
 var previous_tick := int(s.tick)
 var progress := float(s.get("clock_fraction",0.0))+CLOCK_RATE
 s.tick = mini(previous_tick+int(progress),timing("end",10800))
 s.clock_fraction = progress-int(progress)
 if int(s.tick/HOUR) > int(previous_tick/HOUR): events.append({"kind":"sound","text":"hour_chime"})
 var previous: Dictionary = s.actors
 var planned := Authored.actors(self,{})
 for actor in planned.values():
  if actor.room != "passage" or actor.action != "walk": continue
  for id in preload("res://mission2/content.gd").CREW_DOORS:
   var x: float = preload("res://mission2/content.gd").CREW_DOORS[id]
   if absf(float(actor.pos[0])-x) < 65 and absf(float(actor.pos[1])-385) < 100: s.flags[id] = true
 s.actors = Crowd.separate(planned,s.flags,previous,{"player":{"room":s.room,"pos":s.pos}},{"player":before})
 Authored.update(self)
 if s.tick >= timing("end",10800):
  s.finished = true
  s.message = Text.MISSION1_SIX_HOURS_IN_GREECE_END_OF_THE_EXPLORATION_SCHEDULE if mission_number() == 3 else Text.MISSION1_SIX_HOURS_ABOARD_END_OF_THE_EXPLORATION_SCHEDULE
 _record_text_fields()
 history.append(s.duplicate(true))

func _tutorial_step(direction: Vector2) -> void:
 if s.tutorial == "approach" and direction.length_squared()>0.01:
  var p := Crowd.move_player(s.room,Rooms.point(s.pos),direction.limit_length()*14.0,s.flags,s.actors)
  s.pos = [p.x,p.y]
  s.facing = ("right" if direction.x>0 else "left") if absf(direction.x)>absf(direction.y) else ("down" if direction.y>0 else "up")
 Conversations.update(self)
 if s.tutorial == "briefing" and s.get("conversation",{}).is_empty() and s.dialogue.is_empty():
  s.tutorial = "done"
  s.flags.captain_departing = true
  s.actors = actor_positions()


func _still_valid(id: String) -> bool:
 if id.begins_with("authored:"): return not Authored.interaction(self,id).is_empty()
 var active: Dictionary = s.action
 s.action = {}
 var valid := false
 for item in options():
  if item.id == id: valid = true
 s.action = active
 return valid

func _complete(id: String) -> void:
 if exploration() and preload("res://mission2/content.gd").CREW_DOORS.has(id):
  s.flags[id] = not flag(id)
  return
 if id.begins_with("authored:"):
  Authored.complete_interaction(self,id)
  return
 if Hospitality.complete(self,id): return
 if Rooms.CABIN_DOORS.has(id):
  s.flags[id] = not flag(id)
  s.message = Text.MISSION1_I_OPENED_THE_CABIN_DOOR if flag(id) else Text.MISSION1_I_CLOSED_THE_CABIN_DOOR
  return
 match id:
  "inspect_bag":
   if memory.bag:
    s.flags.bag_lead = true
    note("bag_reminder", Text.MISSION1_THE_SAME_MONOGRAM_HE_STILL_REFUSES_TO_BOARD_WITHOUT_THIS_BAG)
   else:
    note("bag_inspect", Text.MISSION1_A_MONOGRAMMED_SUITCASE_TUCKED_AMONG_THE_TRUNKS)
  "hide_bag":
   s.flags.bag_hidden = true
   s.flags.bag_delayed = true
   note("bag_hidden", Text.MISSION1_I_TUCKED_THE_SUITCASE_BEHIND_THE_BAGGAGE_SCREEN)
   events.append({"kind":"sound", "text":"baggage_move"})
  "retrieve_bag":
   var deadline := boarding_time()
   s.flags.sailor_return_pos = s.actors.dock_sailor.pos.duplicate()
   s.flags.bag_found = true
   s.flags.bag_retrieved_by_boy = true
   s.flags.bag_hidden = false
   s.flags.bag_delayed = false
   s.flags.bag_found_tick = s.tick
   s.flags.boarding_tick = mini(s.tick + 80, deadline)
   note("bag_retrieved", Text.MISSION1_I_BROUGHT_THE_SUITCASE_BACK_TO_ITS_OWNER)
   Conversations.start(self,"bag_thanks",[["guest",Text.MISSION1_MY_SUITCASE_AT_LAST_THANK_YOU]],["guest"])
   events.append({"kind":"sound", "text":"baggage_move"})
  "porter":
   s.flags.shortcut_lead = true
   memory.shortcut = true
   note("stair_lead", Text.MISSION1_PORTER_THE_CENTRE_STAIR_IS_ONLY_LATCHED_RELEASE_THE_BRASS_CATCH_A)
  "latch":
   s.flags.shortcut = true
   note("stair_open", Text.MISSION1_I_RELEASED_THE_LATCH_THE_CENTRE_STAIR_LEADS_STRAIGHT_TO_THE_SALON)
  _: _complete_rescue(id)

func _legacy_schedule() -> void:
 _luggage_schedule()
 _party_schedule()
 if s.tick == timing("trap", TRAP):
  s.flags.trapped = true
  if flag("steam_off"):
   _steam_rescue()
  else: s.flags.trapped = true
  if not flag("steam_off") and s.room == "controls":
   note("trapped", Text.MISSION1_STEAM_BLOCKS_THE_FAR_ROOM_S_NORMAL_EXIT_THE_TALKATIVE_PASSENGER_I)
   events.append({"kind":"sound", "text":"steam_hiss"})
 if s.tick == timing("steam_fatal", STEAM_FATAL) and not s.safe.has("chatterbox"):
  _death("chatterbox", Text.MISSION1_THE_PASSENGER_COLLAPSED_BEHIND_THE_STEAM, "controls")
 if s.tick == timing("steam_fatal", STEAM_FATAL) + 30 and s.dead.has("chatterbox"):
  # The late public alarm is audible throughout the ship, but reveals no cause.
  note("alarm", Text.MISSION1_CREW_A_PASSENGER_NEEDS_HELP_IN_THE_STEAM_PASSAGE, true)
  events.append({"kind":"sound", "text":"crew_alarm"})
 if s.tick == timing("creak", CREAK):
  s.flags.chandelier_warning = true
  if s.room == "foyer":
   note("creak", Text.MISSION1_THE_CHANDELIER_CREAKS_AND_TREMBLES_ABOVE_THE_GUEST)
   events.append({"kind":"sound", "text":"chandelier_creak"})
 if s.tick == timing("fall", FALL)-DROP_TICKS and not s.flags.has("chandelier_drop_tick"):
  s.flags.chandelier_drop_tick = s.tick
  s.flags.chandelier_drop_frame = s.frame
 if not flag("chandelier_fallen") and s.tick >= int(s.flags.get("chandelier_impact_tick",timing("fall", FALL))):
  s.flags.chandelier_impact_tick = s.tick
  s.flags.chandelier_impact_frame = s.frame
  s.flags.chandelier_fallen = true
  s.flags.chandelier_warning = false
  if not s.safe.has("chandelier_guest"): _death("chandelier_guest", Text.MISSION1_THE_CHANDELIER_FELL_ON_THE_GUEST, "foyer")
  elif s.room == "foyer": note("fall_safe", Text.MISSION1_THE_CHANDELIER_CRASHED_ONTO_THE_PLACE_WHERE_THE_GUEST_HAD_BEEN_ST)
  if s.room == "foyer":
   events.append({"kind":"sound", "text":"chandelier_impact"})
   events.append({"kind":"sound", "text":"chandelier_glass"})

func _death(id: String, witnessed: String, room: String) -> void:
 if s.dead.has(id): return
 s.dead.append(id)
 if id == "guest":
  var p := Rooms.point(s.actors.guest.pos)
  s.flags.glass_drop = [p.x+28,p.y+8]
  s.flags.guest_collapse = s.actors.guest.duplicate(true)
 if s.room == room: note("death_" + id, witnessed)
 s.message = witnessed if s.room == room else Text.MISSION1_THE_DIARY_SHIVERS
 memory.reset = true
 s.notice = s.message
 s.notice_until = s.tick+150
 events.append({"kind":"death", "text":id})

func _observe() -> void:
 note("room_"+s.room, Messages.source("UI_VISITED_ROOM",{"room":str(room_definition(s.room).title)}))
 var positions: Dictionary = s.actors
 if flag("bag_retrieved_by_boy") and not flag("sailor_thanked") and s.dialogue.is_empty() and s.get("conversation",{}).is_empty():
  var sailor: Dictionary = positions.get("dock_sailor",{})
  if not sailor.is_empty() and nearby(sailor.room,Rooms.point(sailor.pos)):
   s.flags.sailor_thanked = true
   Conversations.say(self,"dock_sailor",Text.MISSION1_YOU_FOUND_THE_BAG_THANK_YOU_BOY_SAVED_ME_A_SEARCH,"speech","sailor_thanks")
 for id in positions:
  if id.begins_with("incidental_") or id.begins_with("sendoff_guest_"): continue
  var actor: Dictionary = positions[id]
  if actor.room == s.room:
   var name := display_name(id)
   note("seen_%s_%d_%s" % [id,int(s.tick/HOUR),s.room], Messages.source("UI_ACTOR_ROOM",{"actor":name,"room":str(room_definition(s.room).title)}))
 if nearby("docks", Vector2(390,430), 110) and not flag("bag_found"):
  memory.bag = true
  s.flags.bag_lead = true

 if memory.shortcut and s.tick >= 3*HOUR and nearby("foyer", Vector2(580,250)) and not flag("shortcut_lead"):
  s.flags.shortcut_lead = true
  note("stair_reminder", Text.MISSION1_THE_STAIR_S_BRASS_CATCH_IS_STILL_HERE)
 if s.tick >= 3500 and s.tick < timing("creak", CREAK) and int(s.tick)%180 == 0 and s.dialogue.is_empty() and s.get("conversation",{}).is_empty() and nearby("foyer",Rooms.point(s.actors.chandelier_guest.pos),180):
  Conversations.say(self,"chandelier_guest",Text.MISSION1_I_DO_WISH_THEY_WOULD_GET_ON_WITH_IT_SUCH_A_WAIT,"speech","fretting_%d" % s.tick)
 _observe_rescues()

func _rescue_options(_result: Array[Dictionary], _local: bool) -> void:
 _option(_result, "bump", Text.MISSION1_BUMP_INTO_GUEST, "salon", Rooms.BAR_GUEST, _local, flag("spiked") and not s.safe.has("guest") and not s.dead.has("guest"))
 _option(_result, "glass", Text.MISSION1_INSPECT_GLASS, "salon", Rooms.point(s.flags.get("glass_drop",[Rooms.BAR_GUEST.x+28,Rooms.BAR_GUEST.y+8])), _local, s.dead.has("guest"))
 _option(_result, "panel", Text.MISSION1_USE_CONTROLS, "controls", Vector2(350,300), _local, true)
 _option(_result, "shove", "Shove", "foyer", Rooms.point(s.actors.get("chandelier_guest",{}).get("pos",[Rooms.CHANDELIER_GUEST.x,Rooms.CHANDELIER_GUEST.y])), _local, flag("chandelier_warning") and not s.safe.has("chandelier_guest"))
 var guest: Dictionary = s.actors.get("guest",{})
 _option(_result,"apologise","Apologise","cabins",Rooms.point(guest.get("pos",[580,315])),_local,flag("spilled") and guest.get("room","") == "cabins" and not flag("apologised"))
 _option(_result, "wreckage", Text.MISSION1_INSPECT_WRECKAGE, "foyer", Vector2(580,420), _local, flag("chandelier_fallen"))
func _complete_rescue(_id: String) -> void:
 match _id:
  "bump":
   s.safe.append("guest")
   s.flags.spilled = true
   s.flags.spill_tick = s.tick
   s.flags.spill_frame = s.frame
   var spill_position := Rooms.point(s.actors.guest.pos)+Vector2(28,8)
   s.flags.glass_drop = [spill_position.x,spill_position.y]
   note("spill", Text.MISSION1_MY_ELBOW_CAUGHT_THE_GLASS_HIS_DRINK_SOAKED_HIS_SUIT)
   Conversations.start(self,"spill_reply",[["guest",Text.MISSION1_MY_SUIT_DO_WATCH_WHERE_YOU_ARE_GOING]],["guest"])
   events.append({"kind":"sound", "text":"drink_spill"})
  "glass": note("poison_evidence", Text.MISSION1_A_SHARP_CHEMICAL_RESIDUE_IN_THE_GLASS_THE_DRINK_WAS_POISONED_NOTH)
  "apologise":
   s.flags.apologised = true
   Conversations.start(self,"spill_apology",[["amelia",Text.MISSION1_I_WANTED_TO_APOLOGISE_ABOUT_YOUR_DRINK_SIR],["guest",Text.MISSION1_YOU_RUINED_MY_SUIT_I_HAVE_NO_INTEREST_IN_YOUR_EXCUSES_NOW_LEAVE_M]],["amelia","guest"])
  "shove":
   _begin_shove()
   s.safe.append("chandelier_guest")
   s.flags.shove_tick = s.tick
   s.flags.chandelier_drop_tick = s.tick
   s.flags.chandelier_drop_frame = s.frame
   s.flags.chandelier_impact_tick = s.tick+DROP_TICKS
   note("shove", Text.MISSION1_I_SHOVED_THE_GUEST_OUT_FROM_BENEATH_THE_CHANDELIER)
   Conversations.start(self,"shove_reply",[["chandelier_guest",Text.MISSION1_HOW_DARE_YOU_WHAT_DO_YOU_THINK_YOU_ARE_DOING]],["chandelier_guest"])
   events.append({"kind":"sound", "text":"shove"})
  "wreckage":
   var text := Text.MISSION1_SHE_IS_DEAD_BENEATH_THE_CHANDELIER_BROKEN_GLASS_EVERYWHERE_AND_A
   if not s.dead.has("chandelier_guest"):
    text = Text.MISSION1_BROKEN_GLASS_AND_A_SNAPPED_SUSPENSION_PIN_THANK_GOODNESS_I_GOT_HE
   # Inspection always responds, even when this evidence is already in the diary.
   note("wreckage",text,true,false)
   s.message = ""
   Conversations.say(self,"amelia",text,"thought")
func _observe_rescues() -> void:
 if s.room == "salon":
  if flag("party_arrived") and not s.dead.has("guest") and not s.safe.has("guest"):
   note("party_arrival", Text.MISSION1_THE_LUGGAGE_OWNER_IS_WAITING_AT_THE_BAR)
  if s.dead.has("guest"):
   note("guest_body", Text.MISSION1_THE_LUGGAGE_OWNER_HAS_COLLAPSED_BESIDE_HIS_GLASS)
   Hints.see_body(self,"guest")
 if s.room == "controls":
  if flag("trapped") and not s.safe.has("chatterbox") and not s.dead.has("chatterbox"):
   note("trapped", Text.MISSION1_STEAM_BLOCKS_THE_FAR_ROOM_S_NORMAL_EXIT_THE_TALKATIVE_PASSENGER_I)
  if s.dead.has("chatterbox"):
   note("steam_body", Text.MISSION1_THE_PASSENGER_LIES_MOTIONLESS_BEYOND_THE_STEAM_LEAK)
   Hints.see_body(self,"chatterbox")
 if s.room == "foyer":
  if s.dead.has("chandelier_guest"): Hints.see_body(self,"chandelier_guest")
  if flag("chandelier_warning"): note("creak", Text.MISSION1_THE_CHANDELIER_CREAKS_AND_TREMBLES_ABOVE_THE_GUEST)
  if flag("chandelier_fallen"): note("fallen_seen", Text.MISSION1_THE_GUEST_LIES_DEAD_BENEATH_THE_FALLEN_CHANDELIER if s.dead.has("chandelier_guest") else Text.MISSION1_THE_FALLEN_CHANDELIER_LIES_IN_PIECES_THE_GUEST_IS_SAFE)

func actor_positions() -> Dictionary:
 if exploration(): return s.get("actors",{}).duplicate(true)
 var prior := Rooms.authored
 var prior_connections := Rooms.authored_connections
 var prior_states := Rooms.prop_states
 Rooms.prop_states = s.get("prop_states",{})
 var prior_behaviour := Rooms.behaviour
 Rooms.behaviour = authored_content
 Rooms.authored = authored_content.get("rooms", {})
 Rooms.authored_connections = authored_content.get("connections", [])
 var result := _authored_actor_positions()
 Rooms.authored = prior
 Rooms.authored_connections = prior_connections
 Rooms.behaviour = prior_behaviour
 Rooms.prop_states = prior_states
 return result

func _authored_actor_positions() -> Dictionary:
 return Crowd.separate(Authored.actors(self,_planned_actors()),s.flags)

func _planned_actors() -> Dictionary:
 var result := {}
 if tutorial_active():
  return {"captain":{"room":"docks","pos":[CAPTAIN.x,CAPTAIN.y],"action":"talk" if s.tutorial == "briefing" else "idle","facing":"down"},
   "dock_sailor":dock_sailor_position(),
   "crew":Routines.passenger("crew",0,boarding_time(),party_arrival(),s.flags)}
 var t := int(s.tick)
 for id in ["guest","chandelier_guest","chatterbox","crew","porter"]:
  result[id] = Routines.passenger(id,t,boarding_time(),party_arrival(),s.flags)
 result.dock_sailor = dock_sailor_position()
 if flag("captain_departing"):
  var route := Routines.path("docks",CAPTAIN,"docks",Vector2(580,105))
  result.captain = Routines.travel(route,t)
 if s.get("arrivals",false):
  var starts := {"guest":[390,430],"chandelier_guest":[720,440],"chatterbox":[765,440]}
  for id in starts:
   var delay: int = {"guest":0,"chandelier_guest":20,"chatterbox":40}[id]
   var entrance := Routines.path("docks",Vector2(970,620),"docks",Rooms.point(starts[id]))
   if t < delay: result.erase(id)
   elif t < delay+Routines.duration(entrance): result[id] = Routines.travel(entrance,t-delay)
 if t >= timing("demo_start", DEMO_START) and t < timing("demo_end", DEMO_END) and int(s.flags.get("demo_cursor",0)) < 3: result.crew.action = "demonstrate"
 result.crew = Operator.pose(self,result.crew)
 if t >= 3500:
  result.chandelier_guest.solid = false
  if result.chandelier_guest.room == "foyer" and t < timing("creak", CREAK)-20:
   result.chandelier_guest.pos = [580,412+sin(float(t-3500)*TAU/120.0)*55]
   result.chandelier_guest.action = "walk"
 if flag("chandelier_warning"): result.chandelier_guest.action = "chandelier_warn"
 if s.dead.has("chandelier_guest"):
  result.chandelier_guest.action = "chandelier_casualty"
  result.chandelier_guest.pos = [Rooms.CHANDELIER_GUEST.x,Rooms.CHANDELIER_GUEST.y]
  result.chandelier_guest.fixed = true
 if s.safe.has("chandelier_guest"):
  result.chandelier_guest.pos = s.flags.get("shove_target",[Rooms.CHANDELIER_SAFE.x,Rooms.CHANDELIER_SAFE.y])
  if s.flags.has("shove_motion"):
   var motion: Dictionary = s.flags.shove_motion
   var fraction := clampf(float(s.frame-motion.frame)/6.0,0,1)
   var location := Rooms.point(motion.guest).lerp(Rooms.point(s.flags.shove_target),fraction)
   result.chandelier_guest.pos = [location.x,location.y]
  result.chandelier_guest.fixed = true
 if flag("party_arrived") and (not flag("spiked") or int(s.frame)-int(s.flags.get("spike_frame",-100)) < 7): result.guest.action = "idle"
 if s.dead.has("guest"):
  result.guest = s.flags.get("guest_collapse",result.guest).duplicate(true)
  result.guest.action = "poison_collapse"
  result.guest.fixed = true
 if s.safe.has("guest"):
  var elapsed := t-int(s.flags.spill_tick)
  result.guest = Routines.travel(Routines.path("salon",Rooms.BAR_GUEST,"cabins",Vector2(580,315)),maxi(0,elapsed-15))
  if elapsed < 15: result.guest.action = "spill_react"
 if flag("trapped"): result.chatterbox.action = "steam_trapped"
 if s.dead.has("chatterbox"): result.chatterbox.action = "steam_casualty"
 if s.safe.has("chatterbox"):
  result.chatterbox = Routines.travel(_escape_path(),t-int(s.flags.escape_tick),"idle")
 if flag("chat_delay"):
  var depart := _chat_departure()
  var room: String = s.flags.get("chat_room","cabins")
  var guest_point := Rooms.point(s.flags.get("chat_guest_pos",[745,530]))
  var chatter_point := Rooms.point(s.flags.get("chat_chatter_pos",[700,530]))
  if not s.dead.has("guest") and not s.safe.has("guest"):
   result.guest = {"room":room,"pos":[guest_point.x,guest_point.y],"action":"talk","facing":"left"} if t < depart else Routines.travel(Routines.path(room,guest_point,"salon",Rooms.BAR_GUEST),t-depart,"hold_drink")
  result.chatterbox = {"room":room,"pos":[chatter_point.x,chatter_point.y],"action":"talk","facing":"right"} if t < depart else Routines.travel(Routines.path(room,chatter_point,"cabins",Vector2(700,530)),t-depart,"idle")
 result.merge(Routines.incidentals(t,s.flags))
 # New arrivals, including after loading an older save, enter through the closet.
 for id in result:
  if id.begins_with("incidental_") and not s.get("actors",{}).has(id) and not (result[id].room == "cabins" and result[id].pos[0] < 0 and result[id].action == "idle"):
   result[id] = {"room":"cabins","pos":[-25,530],"action":"walk","facing":"right"}
 # Despawn only beyond the left screen edge after completing the return.
 for id in result.keys():
  if not id.begins_with("incidental_"): continue
  if result[id].room == "cabins" and result[id].pos[0] < 0 and result[id].action == "idle":
   result.erase(id)
 # Finish the return trip before disappearing, even after a collision delay.
 for id in s.get("actors",{}):
  if not id.begins_with("incidental_") or result.has(id): continue
  var old_actor: Dictionary = s.actors[id]
  if old_actor.room != "cabins" or old_actor.pos[0] >= 0:
   result[id] = {"room":"cabins","pos":[-25,530],"action":"idle"}
 reserve_groups(result)
 Hospitality.apply_routes(self,result)
 Reactions.apply_routes(self,result)
 Departure.apply(self,result)
 return result

func _escape_path() -> Array:
 var points := Routines.path("controls",Vector2(840,360),"salon",Rooms.BAR_GUEST+Vector2(-40,30)).duplicate(true)
 points.append_array(Routines.path("salon",Rooms.BAR_GUEST+Vector2(-40,30),"cabins",Vector2(700,530)))
 return points

func _chat_departure() -> int:
 return party_arrival()-Routines.duration(Routines.path(str(s.flags.get("chat_room","cabins")),Rooms.point(s.flags.get("chat_guest_pos",[745,530])),"salon",Rooms.BAR_GUEST))-60

func _open_passenger_doors(planned: Dictionary) -> void:
 for actor in planned.values():
  if actor.room != "cabins" or actor.action != "walk": continue
  for id in Rooms.CABIN_DOORS:
   if Rooms.point(actor.pos).distance_to(Vector2(Rooms.CABIN_DOORS[id],405)) < 85:
    s.flags[id] = true

func _witness_departures(previous: Dictionary) -> void:
 if s.safe.has("chatterbox") and previous.get("chatterbox",{}).get("room","") == "controls" and s.actors.chatterbox.room != "controls":
  if s.room == "controls": note("escape_departure", Text.MISSION1_THE_PASSENGER_LEAVES_THROUGH_THE_CLEARED_STEAM_PASSAGE)
  elif s.room == s.actors.chatterbox.room: note("escape_departure", Text.MISSION1_THE_PASSENGER_EMERGES_FROM_THE_STEAM_ROOM)

func _travel(from: Vector2, to: Vector2, time: int, start_tick: int, end_tick: int) -> Array:
 var p := from.lerp(to,clampf(float(time-start_tick)/float(end_tick-start_tick),0,1))
 return [p.x,p.y]

func party_arrival() -> int:
 if not luggage_delayed(): return timing("creak", CREAK)-30+int(s.flags.get("guest_delay_ticks",0))
 return (timing("poison", POISON) if flag("chat_delay") else 3*HOUR+450)+int(s.flags.get("guest_delay_ticks",0))

func _party_schedule() -> void:
 if s.safe.has("chatterbox") and luggage_delayed() and not flag("chat_delay") and not flag("party_arrived"):
  var people: Dictionary = s.actors
  if people.guest.room == people.chatterbox.room and Rooms.point(people.guest.pos).distance_to(Rooms.point(people.chatterbox.pos)) < 70:
   s.flags.chat_delay = true
   s.flags.chat_room = people.guest.room
   s.flags.chat_guest_pos = people.guest.pos.duplicate()
   s.flags.chat_chatter_pos = people.chatterbox.pos.duplicate()
 var arrival := party_arrival()
 if s.tick >= arrival and not flag("party_arrived"):
  s.flags.party_arrived = true
  if s.room == "salon": note("party_arrival", Text.MISSION1_THE_LUGGAGE_OWNER_IS_WAITING_AT_THE_BAR)
 # Poison follows attendance; 5:15 is earned by preserving Mabel's routine.
 var interval := 80 if luggage_delayed() else 40
 if s.tick >= arrival and not flag("spiked") and not s.safe.has("guest") and not s.dead.has("guest"):
  s.flags.spiked = true
  s.flags.spike_tick = s.tick
  s.flags.spike_frame = s.frame
  s.flags.drink_tick = s.tick+interval
  if s.room == "salon":
   note("spike", Text.MISSION1_AN_OBSCURED_HAND_TIPS_SOMETHING_INTO_THE_GUEST_S_GLASS)
   events.append({"kind":"spike", "text":""})
 var drink := int(s.flags.get("drink_tick",int(s.flags.get("spike_tick",arrival))+interval))
 if flag("spiked") and s.tick >= drink and not s.safe.has("guest") and not s.dead.has("guest"):
  _death("guest", Text.MISSION1_THE_GUEST_DRANK_THEN_COLLAPSED_BESIDE_THE_POISONED_GLASS, "salon")

func succeeded() -> bool:
 return s.dead.is_empty() and not flag("missed_boat")

func summary(localised := false) -> String:
 var lines: Array[String] = []
 for id in Hospitality.GUESTS:
  var message := Messages.make_ref("UI_SUMMARY_DIED" if s.dead.has(id) else "UI_SUMMARY_SURVIVED", {"name":Messages.capture(display_name(id))})
  lines.append(Messages.resolve(message) if localised else str(message.fallback))
 if flag("missed_boat"):
  return Messages.ui(Text.MISSION1_MISSED_THE_BOAT_MISSION_FAILED_EVERYONE_SURVIVED_BUT_YOU_WERE_STI) if localised else Text.MISSION1_MISSED_THE_BOAT_MISSION_FAILED_EVERYONE_SURVIVED_BUT_YOU_WERE_STI
 var message := Messages.make_ref("UI_SUMMARY_SUCCESS" if succeeded() else "UI_SUMMARY_FAILED",{"outcomes":" · ".join(lines)})
 return Messages.resolve(message) if localised else str(message.fallback)

func _demonstration() -> void:
 if s.tick < timing("demo_start", DEMO_START) or s.tick > timing("demo_end", DEMO_END): return
 if not s.flags.has("demo_cursor"):
  s.flags.demo_cursor = 0
  s.flags.demo_progress = 0
  s.flags.demo_heard = []
 var cursor := int(s.flags.demo_cursor)
 if cursor >= 3: return
 var close := nearby("controls", Vector2(310,305), 110)
 var remaining := (3-cursor)*30 - int(s.flags.demo_progress)
 # Waiting and pausing use only spare time inside the authored window.
 if not close and timing("demo_end", DEMO_END)-int(s.tick) > remaining*CLOCK_RATE:

  return
 s.flags.demo_progress += 1
 if close:
  var lines := [Text.MISSION1_PRESSURE_MUST_BE_RUNNING_FOR_THE_CONTROLS_TO_RESPOND, Text.MISSION1_ENTER_THREE_DIGITS_THEN_PRESS_COMMIT_CLEAR_STARTS_YOUR_ENTRY_AGAI, Text.MISSION1_TODAY_S_SHUTOFF_CODE_IS_S % s.code]
  if not s.flags.get("demo_spoken",[]).has(cursor):
   if not s.flags.has("demo_spoken"): s.flags.demo_spoken = []
   s.flags.demo_spoken.append(cursor)
   s.conversation = {}
   Conversations.say(self,"crew",lines[cursor],"speech","demo_%d" % cursor,30)
  if s.flags.demo_progress >= ceili(lines[cursor].length()/Conversations.CPS*10):
   if not s.flags.demo_heard.has(cursor): s.flags.demo_heard.append(cursor)
   if cursor == 2:
    s.flags.known_code = s.code
    if s.flags.demo_heard.size() == 3: memory.procedure = true
 s.flags.demo_progress = int(s.flags.demo_progress)
 if s.flags.demo_progress >= 30:
  s.flags.demo_cursor += 1
  s.flags.demo_progress = 0

func submit_code() -> bool:
 events.clear()
 if not s.code_open or not nearby("controls", Vector2(350,300)): return false
 if s.entry.length() != 3 or s.entry != s.code:
  s.message = Text.MISSION1_CODE_REJECTED_CLEAR_AND_TRY_AGAIN
  s.flags.panel_rejected = true
  return false
 s.flags.panel_rejected = false
 s.flags.steam_shutdown_frame = s.frame
 s.flags.steam_shutdown_visible = Rooms.steam_blocked(s.flags)
 s.flags.steam_off = true
 s.code_open = false
 note("shutoff_%d" % s.tick, Text.MISSION1_I_STOPPED_THE_STEAM)
 events.append({"kind":"sound", "text":"steam_valve"})
 if flag("trapped") and s.tick < timing("steam_fatal", STEAM_FATAL) and not s.dead.has("chatterbox"):
  _steam_rescue()
 return true


func luggage_delayed() -> bool:
 return flag("bag_delayed") or flag("bag_hidden")

func boarding_time() -> int:
 return int(s.flags.get("boarding_tick", HOUR if luggage_delayed() else 800))

func _luggage_schedule() -> void:
 var found_at := (HOUR if luggage_delayed() else 800) - 80
 if not flag("bag_found") and s.tick >= found_at:
  s.flags.sailor_return_pos = s.actors.dock_sailor.pos.duplicate()
  s.flags.bag_delayed = luggage_delayed()
  s.flags.bag_hidden = false
  s.flags.bag_found = true
  s.flags.bag_found_tick = s.tick
  s.flags.boarding_tick = s.tick + 80
  if s.room == "docks":
   s.conversation = {}
   Conversations.say(self,"dock_sailor",Text.MISSION1_FOUND_IT_BROWN_LEATHER_JUST_AS_YOU_SAID,"speech","bag_found")

func dock_sailor_position() -> Dictionary:
 var t := int(s.tick)
 var p := Vector2(435,430)
 var action := "talk"
 if flag("bag_found"):
  return Routines.travel(Routines.path("docks",Rooms.point(s.flags.get("sailor_return_pos",[190,390])),"docks",Vector2(435,430)),t-int(s.flags.get("bag_found_tick",720)))
 elif t >= 160 and t < 210:
  p = Rooms.point(_travel(Vector2(435,430),Vector2(190,390),t,160,210))
  action = "walk"
 elif t >= 210:
  p = Vector2(190,390)
  action = "handle_baggage"
 return {"room":"docks", "pos":[p.x,p.y], "action":action, "skin":"sailor"}

static func observation_time(tick: int) -> String:
 var minutes := int(tick * 60 / HOUR)
 return "%02d:%02d" % [1 + int(minutes / 60), minutes % 60]

## Restore only recorded data; never sample current schedules for old frames.
func restore_record(record: Dictionary) -> void:
 authored_content = record.get("authored_content",{}).duplicate(true)
 content_versions = record.get("content_versions",{}).duplicate(true)
 s = record.current.duplicate(true)
 memory = record.memory.duplicate(true)
 history = record.history.duplicate(true)
 # Update stock Mission 1 geometry without replacing schedules or prior history.
 if authored_content.get("version","") in ["mission1-layout-2","mission1-layout-3","mission1-layout-4","mission1-layout-5"]:
  content_versions[authored_content.version] = authored_content.duplicate(true)
  var layout := preload("res://mission1/authoring_content.gd").seed(s.actors)
  for room in ["foyer","passage","controls"]: authored_content.rooms[room] = layout.rooms[room].duplicate(true)
  authored_content.templates.code_panel.states = layout.templates.code_panel.states.duplicate(true)
  for index in authored_content.connections.size():
   var door: Dictionary = authored_content.connections[index]
   if door.a == "foyer" and door.b in ["passage","controls"]:
    authored_content.connections[index] = layout.connections[3 if door.b == "passage" else 2].duplicate(true)
  authored_content.version = layout.version
  content_versions[layout.version] = authored_content.duplicate(true)
  s.content_version = layout.version
  record_current_frame()
 # The enlarged stock control housing is solid in each state. Retain old history.
 if authored_content.get("version","") == "mission1-layout-6":
  content_versions[authored_content.version] = authored_content.duplicate(true)
  var layout := preload("res://mission1/authoring_content.gd").seed(s.actors)
  authored_content.templates.code_panel.states = layout.templates.code_panel.states.duplicate(true)
  authored_content.version = layout.version
  content_versions[layout.version] = authored_content.duplicate(true)
  s.content_version = layout.version
  _record_text_fields()
  history.append(s.duplicate(true))
 # Upgrade only the untouched first exploration seed. Edited authoring documents
 # keep their own version, and all earlier recorded frames remain unchanged.
 if authored_content.get("version","") in ["mission2-layout-1","mission2-layout-2","mission2-layout-3","mission2-layout-4","mission2-layout-5","mission2-layout-6","mission2-layout-7"]:
  var old_version: String = authored_content.version
  content_versions[authored_content.version] = authored_content.duplicate(true)
  authored_content = preload("res://mission2/content.gd").seed()
  content_versions[authored_content.version] = authored_content.duplicate(true)
  if old_version == "mission2-layout-1":
   for id in preload("res://mission2/content.gd").CREW_DOORS: s.flags[id] = true
  s.get_or_add("prop_states",{}).chandelier = "fallen"
  if s.room == "docks":
   s.room = "foyer"
   s.pos = [580,580]
  for actor in s.actors.values():
   if actor.room == "docks":
    actor.room = "foyer"
    actor.pos = [650,550]
  s.content_version = authored_content.version
  Authored.update(self)
  record_current_frame()
 if authored_content.get("version","") in ["mission3-layout-1","mission3-layout-2","mission3-layout-3","mission3-layout-4","mission3-layout-5"]:
  content_versions[authored_content.version] = authored_content.duplicate(true)
  authored_content = preload("res://mission3/content.gd").seed()
  content_versions[authored_content.version] = authored_content.duplicate(true)
  for id in ["chandelier","janitor"]: s.get_or_add("prop_states",{}).erase(id)
  if int(s.frame) == 0 and s.room == "docks":
   s.room = authored_content.instances.amelia.room
   s.pos = authored_content.instances.amelia.position.duplicate()
  s.content_version = authored_content.version
  Authored.update(self)
  # Keep every recorded old-layout frame available for scrubbing.
  _record_text_fields()
  history.append(s.duplicate(true))
 if authored_content.get("version","") != record.get("authored_content",{}).get("version",""):
  # Keep occupants clear of the new corridor end wall after a stock-layout upgrade.
  if s.room == "passage" and float(s.pos[0]) > 1090: s.pos[0] = 1080
  if s.room == "foyer" and float(s.pos[0]) > 895 and float(s.pos[1]) < 250: s.pos = [850,260]
  for actor in s.actors.values():
   if actor.room == "passage" and float(actor.pos[0]) > 1090: actor.pos[0] = 1080
   if actor.room == "foyer" and float(actor.pos[0]) > 895 and float(actor.pos[1]) < 250: actor.pos = [850,260]
  if s.room == "passage": s.pos = _corridor_floor_position(s.pos)
  for actor in s.actors.values():
   if actor.room == "passage": actor.pos = _corridor_floor_position(actor.pos)
  record_current_frame()
 # An old save may place someone inside the newly solid stock console base.
 # Move only the resumed state clear; recorded frames keep their old positions.
 if authored_content.is_empty() or authored_content.get("version","") == "mission1-layout-7":
  var panel_base := Rect2(Vector2(350,280)+Rooms.CODE_PANEL_BOUNDS.position,Rooms.CODE_PANEL_BOUNDS.size)
  var relocated := false
  if s.room == "controls" and panel_base.has_point(Rooms.point(s.pos)):
   s.pos[1] = panel_base.end.y+2
   relocated = true
  for actor in s.actors.values():
   if actor.room == "controls" and panel_base.has_point(Rooms.point(actor.pos)):
    actor.pos[1] = panel_base.end.y+2
    relocated = true
  if relocated:
   _record_text_fields()
   history.append(s.duplicate(true))
 events.clear()
 restore_notebook()

func _corridor_floor_position(position: Array) -> Array:
 var room: Dictionary = authored_content.rooms.passage
 var point := Rooms.point(position)
 if preload("res://mission1/authoring_grid.gd").contains(room,point): return position
 var nearest := point
 var distance := INF
 for box in room.get("floor_regions",[]):
  # Recover into a cabin or hallway, clear of closed door leaves.
  if box[2] < 100: continue
  var floor_area := Rect2(box[0],box[1],box[2],box[3]).grow(-12)
  var candidate := point.clamp(floor_area.position,floor_area.end)
  if point.distance_squared_to(candidate) < distance:
   nearest = candidate
   distance = point.distance_squared_to(candidate)
 return [nearest.x,nearest.y]

func record_current_frame() -> void:
 _record_text_fields()
 history[-1] = s.duplicate(true)

func restore_notebook() -> void:
 var records: Array = memory.get("note_records",[])
 if not records.is_empty():
  var matching: bool = records.size() == memory.notes.size()
  for index in mini(records.size(),memory.notes.size()):
   if not records[index].is_empty() and records[index].get("fallback","") != memory.notes[index]: matching = false
  if matching: return
  memory.erase("note_records")
 # Old saves mixed previous loops and unwitnessed death notices into memory.
 # Keep only current-run text with a matching recorded observation timestamp.
 var prefix := Text.MISSION1_LOOP_D_HOUR % (int(s.loop)+1)
 var recorded := {}
 for frame in history:
  if not recorded.has(frame.message): recorded[frame.message] = int(frame.tick)
 var notes: Array = []
 for line in memory.notes:
  var text := str(line)
  if text.begins_with("Loop"):
   if not text.begins_with(prefix): continue
   var parts := text.split(" — ", true, 1)
   if parts.size() < 2 or not recorded.has(parts[1]): continue
   notes.append("%s — %s" % [observation_time(recorded[parts[1]]),parts[1]])
  elif not text.begins_with(Text.MISSION1_HOUR):
   notes.append(text)
 memory.notes = notes

func _steam_rescue() -> void:
 if s.safe.has("chatterbox"): return
 s.safe.append("chatterbox")
 s.flags.escape_tick = s.tick
 if s.room == "controls": note("escape", Text.MISSION1_THE_PASSAGE_IS_CLEAR_THE_PASSENGER_STARTS_TOWARDS_THE_EXIT)

func reserve_groups(planned: Dictionary) -> void:
 var used := {}
 for id in planned:
  var actor: Dictionary = planned[id]
  if not Rooms.GROUPS.has(actor.room) or actor.action not in ["idle","talk"]: continue
  var assigned := false
  for group in 3:
   for slot in 3:
    if assigned: break
    var place := Rooms.group_slot(actor.room,group,slot)
    if Rooms.point(actor.pos).distance_to(Rooms.point(place.pos)) > 1: continue
    var rooms := [actor.room]
    for other in Rooms.GROUPS:
     if other != actor.room: rooms.append(other)
    for room in rooms:
     if assigned: break
     for offset in 3:
      var candidate := (slot+offset)%3
      var key := "%s:%d:%d" % [room,group,candidate]
      if used.has(key): continue
      planned[id] = Rooms.group_slot(room,group,candidate)
      used[key] = id
      assigned = true
      break

func _begin_shove() -> void:
 var guest := Rooms.point(s.actors.chandelier_guest.pos)
 var player := Rooms.point(s.pos)
 var direction := (guest-player).normalized()
 if direction == Vector2.ZERO: direction = Vector2.UP
 var distance := 120.0
 for candidate in range(120,261,10):
  var target := guest+direction*candidate
  var follow := player+direction*candidate
  if Rooms.can_stand("foyer",target,s.flags) and Rooms.can_stand("foyer",follow,s.flags) and not Rooms.WRECKAGE.grow(25).has_point(target) and not Rooms.WRECKAGE.grow(25).has_point(follow):
   distance = candidate
   break
 var target := guest+direction*distance
 s.flags.shove_target = [target.x,target.y]
 s.flags.shove_motion = {"frame":s.frame,"guest":[guest.x,guest.y],"player":[player.x,player.y],"delta":[direction.x*distance,direction.y*distance]}

func _advance_shove() -> void:
 if not s.flags.has("shove_motion"): return
 var motion: Dictionary = s.flags.shove_motion
 var age := int(s.frame)-int(motion.frame)
 if age > 6: return
 var p := Rooms.point(motion.player)+Rooms.point(motion.delta)*clampf(float(age)/6.0,0,1)
 s.pos = [p.x,p.y]

func nearest_options(available: Array[Dictionary]) -> Array[Dictionary]:
 if available.is_empty(): return available
 var nearest: Dictionary = available[0]
 var distance := INF
 for option in available:
  var candidate := Rooms.point(s.pos).distance_squared_to(Rooms.point(option.pos))
  if candidate < distance:
   nearest = option
   distance = candidate
 var target: String = nearest.target
 return available.filter(func(option): return option.target == target if target != "" else option.pos == nearest.pos)

func room_definition(id: String) -> Dictionary:
 return authored_content.get("rooms", {}).get(id, Rooms.ROOMS.get(id, {"title":id,"scene":""}))

func apply_authored(content: Dictionary, frame_index := -1) -> Dictionary:
 var candidate: Dictionary = history[frame_index] if frame_index >= 0 and frame_index < history.size() else s
 var errors := preload("res://mission1/authoring_content.gd").validate(content)
 if errors.is_empty(): errors = Authored.compatibility(content, self, candidate)
 if not errors.is_empty(): return {"ok":false,"reason":"; ".join(errors)}
 if authored_content.is_empty() and not content_versions.has("legacy"):
  content_versions.legacy = preload("res://mission1/authoring_content.gd").seed(history[0].get("actors",{}))
 authored_content = content.duplicate(true)
 content_versions[content.version] = content.duplicate(true)
 if frame_index >= 0:
  s = candidate.duplicate(true)
  history = history.slice(0, frame_index + 1)
  events.clear()
 return {"ok":true,"reason":Text.MISSION1_CONTENT_APPLIED}

func timing(key: String, fallback: int) -> int:
 return int(authored_content.get("timings",{}).get(key,fallback))

func _schedule() -> void:
 if authored_content.is_empty(): _legacy_schedule()
 else: Authored.execute_phase(self, "schedule")

func execute_mission_effect(id: String) -> void:
 match id:
  "luggage_routine": _luggage_schedule()
  "party_routine": _party_schedule()
  "steam_trap": _effect_steam_trap()
  "steam_fatal": _effect_steam_fatal()
  "steam_alarm": _effect_steam_alarm()
  "chandelier_warning": _effect_chandelier_warning()
  "chandelier_drop": _effect_chandelier_drop()
  "chandelier_impact": _effect_chandelier_impact()

func _effect_steam_trap() -> void:
 s.flags.trapped = true
 if flag("steam_off"):
  _steam_rescue()
 else: s.flags.trapped = true
 if not flag("steam_off") and s.room == "controls":
  note("trapped", Text.MISSION1_STEAM_BLOCKS_THE_FAR_ROOM_S_NORMAL_EXIT_THE_TALKATIVE_PASSENGER_I)
  events.append({"kind":"sound", "text":"steam_hiss"})

func _effect_steam_fatal() -> void:
 _death("chatterbox", Text.MISSION1_THE_PASSENGER_COLLAPSED_BEHIND_THE_STEAM, "controls")

func _effect_steam_alarm() -> void:
 # The late public alarm is audible throughout the ship, but reveals no cause.
 note("alarm", Text.MISSION1_CREW_A_PASSENGER_NEEDS_HELP_IN_THE_STEAM_PASSAGE, true)
 events.append({"kind":"sound", "text":"crew_alarm"})

func _effect_chandelier_warning() -> void:
 s.flags.chandelier_warning = true
 if s.room == "foyer":
  note("creak", Text.MISSION1_THE_CHANDELIER_CREAKS_AND_TREMBLES_ABOVE_THE_GUEST)
  events.append({"kind":"sound", "text":"chandelier_creak"})

func _effect_chandelier_drop() -> void:
 s.flags.chandelier_drop_tick = s.tick
 s.flags.chandelier_drop_frame = s.frame

func _effect_chandelier_impact() -> void:
 s.flags.chandelier_impact_tick = s.tick
 s.flags.chandelier_impact_frame = s.frame
 s.flags.chandelier_fallen = true
 s.flags.chandelier_warning = false
 if not s.safe.has("chandelier_guest"): _death("chandelier_guest", Text.MISSION1_THE_CHANDELIER_FELL_ON_THE_GUEST, "foyer")
 elif s.room == "foyer": note("fall_safe", Text.MISSION1_THE_CHANDELIER_CRASHED_ONTO_THE_PLACE_WHERE_THE_GUEST_HAD_BEEN_ST)
 if s.room == "foyer":
  events.append({"kind":"sound", "text":"chandelier_impact"})
  events.append({"kind":"sound", "text":"chandelier_glass"})

func _record_text_fields(initial := false) -> void:
 for field in ["message", "notice"]:
  if not s.has(field): continue
  var value := str(s[field])
  var previous: Dictionary = s.get(field+"_ref",{})
  if not previous.is_empty() and previous.get("fallback","") == value: continue
  # A restored literal remains literal until gameplay changes the field.
  if not initial and previous.is_empty() and not history.is_empty() and history[-1].get(field,"") == value: continue
  s[field+"_ref"] = Messages.capture(value)

func notebook_text() -> String:
 var rendered: PackedStringArray = []
 var records: Array = memory.get("note_records",[])
 for index in memory.notes.size():
  var fallback := str(memory.notes[index])
  if index < records.size() and records[index].get("fallback","") == fallback:
   rendered.append("%s — %s" % [observation_time(int(records[index].tick)), Messages.resolve(records[index].text_ref)])
  else: rendered.append(fallback)
 return "\n\n".join(rendered)
