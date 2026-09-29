extends RefCounted
## Deterministic 10 Hz Mission 1 simulation. No rendering or wall clock dependencies.
const Rooms = preload("res://mission1/rooms.gd")
const Routines = preload("res://mission1/routines.gd")
const Crowd = preload("res://mission1/crowd.gd")
const HOUR := 1800
const END := 6 * HOUR
const CREAK := 2 * HOUR + 480
const FALL := CREAK + 80
const TRAP := 3 * HOUR + 100
const STEAM_FATAL := 3 * HOUR + 600
const DEMO_START := HOUR + 50
const DEMO_END := HOUR + 500
var s: Dictionary
var memory: Dictionary = {"notes":[], "bag":false, "procedure":false, "shortcut":false, "reset":false, "completed":false}
var history: Array = []
var events: Array[Dictionary] = []

func _init() -> void:
 reset()

func reset() -> void:
 memory.notes = []
 var loop := int(s.get("loop", -1)) + 1
 var value := (loop * 71 + 83) % 216
 var code := ""
 for i in 3:
  code += str(value % 6 + 1)
  value = int(value / 6)
 s = {"tick":0, "loop":loop, "room":"docks", "pos":[580.0,490.0], "facing":"down", "code":code,
  "flags":{"shortcut":true}, "dead":[], "safe":[], "action":{}, "entry":"", "code_open":false,
  "dialogue":{}, "observed":[], "message":"A new posting. An unmooring party. What could possibly go wrong?",
  "finished":false, "door_cooldown":0}
 _open_passenger_doors(_planned_actors())
 s.actors = actor_positions()
 history = [s.duplicate(true)]
 events.clear()

func flag(key: String) -> bool:
 return bool(s.flags.get(key, false))

func note(key: String, text: String, permanent := true) -> void:
 if s.observed.has(key): return
 s.observed.append(key)
 var line := "%s — %s" % [observation_time(int(s.tick)), text]
 if permanent: memory.notes.append(line)
 s.message = text
 events.append({"kind":"observation", "text":text})

func nearby(room: String, p: Vector2, radius := 80.0) -> bool:
 return s.room == room and Rooms.point(s.pos).distance_to(p) <= radius

func options(local := true) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 if not s.action.is_empty() or s.finished: return result
 _option(result, "inspect_bag", "Inspect luggage", "docks", Rooms.LUGGAGE, local, not flag("bag_found"))
 _option(result, "retrieve_bag", "Retrieve bag", "docks", Rooms.LUGGAGE, local, not flag("bag_found"))
 _option(result, "hide_bag", "Hide bag", "docks", Rooms.LUGGAGE, local, not flag("bag_found") and not flag("bag_hidden") and s.tick < 700)
 for id in Rooms.CABIN_DOORS:
  var occupied: bool = s.room == "cabins" and Rooms.door_bounds(id).has_point(Rooms.point(s.pos))
  for actor in s.actors.values():
   if actor.room == "cabins" and Rooms.door_bounds(id).grow(8).has_point(Rooms.point(actor.pos)): occupied = true
  _option(result, id, "Close door" if flag(id) else "Open door", "cabins", Vector2(Rooms.CABIN_DOORS[id],405), local, not (flag(id) and occupied))
 _rescue_options(result, local)
 return result

func _option(result: Array[Dictionary], id: String, label: String, room: String, p: Vector2, local: bool, eligible: bool) -> void:
 if eligible and s.room == room and (not local or nearby(room, p)):
  result.append({"id":id, "label":label, "pos":[p.x,p.y], "room":room})

func start(id: String) -> bool:
 for item in options():
  if item.id == id:
   if id == "panel":
    s.code_open = true
    s.entry = ""
   else:
    s.action = {"id":id, "progress":0, "duration":20 if id == "hide_bag" else 10, "pos":item.pos, "room":item.room}
   return true
 return false

func step(direction := Vector2.ZERO, cancel := false) -> void:
 if s.finished: return
 events.clear()
 var player_before := {"room":s.room,"pos":s.pos.duplicate()}
 s.tick = int(s.tick)+1
 s.door_cooldown = maxi(0, int(s.door_cooldown)-1)
 if direction.length_squared() > 0.01:
  var p := Crowd.move_player(s.room, Rooms.point(s.pos), direction.limit_length() * 14.0, s.flags, s.actors)
  s.pos = [p.x,p.y]
  s.facing = ("right" if direction.x > 0 else "left") if absf(direction.x)>absf(direction.y) else ("down" if direction.y>0 else "up")
  if s.door_cooldown == 0:
   for door in Rooms.exits(s.room, flag("shortcut")):
    if p.distance_to(Rooms.point(door.point)) < 24 and Crowd.clear(door.room,Rooms.point(door.arrival),s.actors):
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
   s.message = "Action interrupted. Unfinished progress lost."
  else:
   action.progress += 1
   if action.progress >= action.duration:
    s.action = {}
    _complete(action.id)
 if s.code_open and not nearby("controls", Vector2(350,300)): s.code_open = false
 _schedule()
 _open_passenger_doors(_planned_actors())
 _open_passenger_doors(s.actors)
 var previous: Dictionary = s.actors
 s.actors = Crowd.separate(_planned_actors(),s.flags,previous,{"player":{"room":s.room,"pos":s.pos}}, {"player":player_before})
 _witness_departures(previous)
 _observe()
 if s.tick >= END:
  s.finished = true
  memory.completed = bool(memory.completed) or s.dead.is_empty()
  if s.dead.is_empty(): memory.location_rewriting = true
  events.append({"kind":"end", "text":"The unmooring party has ended."})
 history.append(s.duplicate(true))

func _still_valid(id: String) -> bool:
 var active: Dictionary = s.action
 s.action = {}
 var valid := false
 for item in options():
  if item.id == id: valid = true
 s.action = active
 return valid

func _complete(id: String) -> void:
 if Rooms.CABIN_DOORS.has(id):
  s.flags[id] = not flag(id)
  s.message = "I opened the cabin door." if flag(id) else "I closed the cabin door."
  return
 match id:
  "inspect_bag":
   if memory.bag:
    s.flags.bag_lead = true
    note("bag_reminder", "The same monogram. He still refuses to board without this bag.")
   else:
    note("bag_inspect", "A monogrammed suitcase tucked among the trunks.")
  "hide_bag":
   s.flags.bag_hidden = true
   s.flags.bag_delayed = true
   note("bag_hidden", "I tucked the suitcase behind the baggage screen.")
   events.append({"kind":"sound", "text":"baggage_move"})
  "retrieve_bag":
   var deadline := boarding_time()
   s.flags.sailor_return_pos = s.actors.dock_sailor.pos.duplicate()
   s.flags.bag_found = true
   s.flags.bag_hidden = false
   s.flags.bag_delayed = false
   s.flags.bag_found_tick = s.tick
   s.flags.boarding_tick = mini(s.tick + 80, deadline)
   note("bag_retrieved", "I brought the suitcase back to its owner.")
   events.append({"kind":"sound", "text":"baggage_move"})
  "porter":
   s.flags.shortcut_lead = true
   memory.shortcut = true
   note("stair_lead", "Porter: The centre stair is only latched. Release the brass catch at its foot.")
  "latch":
   s.flags.shortcut = true
   note("stair_open", "I released the latch. The centre stair leads straight to the salon.")
  _: _complete_rescue(id)

func _schedule() -> void:
 _luggage_schedule()
 _party_schedule()
 _demonstration()
 if s.tick == TRAP or s.tick == STEAM_FATAL + 100:
  s.flags.steam_off = false
  if s.room == "controls": note("restart_%d" % s.tick, "The engineer restores pressure on his round.")
 if s.tick == TRAP:
  s.flags.trapped = true
  if s.room == "controls":
   note("trapped", "Steam blocks the far room's normal exit. The talkative passenger is trapped.")
   events.append({"kind":"sound", "text":"steam_hiss"})
 if s.tick == STEAM_FATAL and not s.safe.has("chatterbox"):
  _death("chatterbox", "The passenger collapsed behind the steam.", "controls")
 if s.tick == STEAM_FATAL + 30:
  # The late public alarm is audible throughout the ship, but reveals no cause.
  note("alarm", "Crew: A passenger needs help in the steam passage!", true)
  events.append({"kind":"sound", "text":"crew_alarm"})
 if s.tick == CREAK:
  s.flags.chandelier_warning = true
  if s.room == "foyer":
   note("creak", "The chandelier creaks and trembles above the guest.")
   events.append({"kind":"sound", "text":"chandelier_creak"})
 if s.tick == FALL:
  s.flags.chandelier_fallen = true
  s.flags.chandelier_warning = false
  if not s.safe.has("chandelier_guest"): _death("chandelier_guest", "The chandelier fell on the guest.", "foyer")
  elif s.room == "foyer": note("fall_safe", "The chandelier crashed onto the place where the guest had been standing.")
  if s.room == "foyer": events.append({"kind":"sound", "text":"chandelier_impact"})

func _death(id: String, witnessed: String, room: String) -> void:
 if s.dead.has(id): return
 s.dead.append(id)
 if s.room == room: note("death_" + id, witnessed)
 s.message = witnessed if s.room == room else "The diary shivers."
 if not memory.reset:
  memory.reset = true
  s.message += " The ink runs backwards. Tab / Y: read the diary; R / Back: return to the docks. You may keep investigating."
 s.notice = s.message
 s.notice_until = s.tick+150
 events.append({"kind":"death", "text":id})

func _observe() -> void:
 note("room_"+s.room, "I visited " + str(Rooms.ROOMS[s.room].title) + ".")
 var positions: Dictionary = s.actors
 for id in positions:
  var actor: Dictionary = positions[id]
  if actor.room == s.room:
   var name: String = {"guest":"The luggage owner", "chandelier_guest":"The foyer guest", "chatterbox":"The talkative passenger", "crew":"The sailor", "porter":"The porter", "dock_sailor":"The dock sailor"}[id]
   note("seen_%s_%d_%s" % [id,int(s.tick/HOUR),s.room], name + " is in " + str(Rooms.ROOMS[s.room].title) + ".")
 if s.room == "docks" and not flag("bag_found") and s.actors.guest.action == "talk":
  note("docks", "The luggage owner is complaining to a sailor about his missing bags.")
 if nearby("docks", Vector2(390,430), 110) and not flag("bag_found"):
  memory.bag = true
  s.flags.bag_lead = true
  note("bag_lead", "Guest: Where are my bags, sailor? I will not board without them!")
 if memory.shortcut and s.tick >= 3*HOUR and nearby("foyer", Vector2(580,250)) and not flag("shortcut_lead"):
  s.flags.shortcut_lead = true
  note("stair_reminder", "The stair's brass catch is still here.")
 _observe_rescues()

func _rescue_options(_result: Array[Dictionary], _local: bool) -> void:
 _option(_result, "bump", "Bump into guest", "salon", Vector2(800,330), _local, flag("spiked") and not s.safe.has("guest") and not s.dead.has("guest"))
 _option(_result, "glass", "Inspect glass", "salon", Vector2(815,310), _local, s.dead.has("guest"))
 _option(_result, "panel", "Use controls", "controls", Vector2(350,300), _local, memory.procedure)
 _option(_result, "shove", "Shove", "foyer", Vector2(680,440), _local, flag("chandelier_warning") and not s.safe.has("chandelier_guest"))
 _option(_result, "wreckage", "Inspect wreckage", "foyer", Vector2(680,440), _local, flag("chandelier_fallen"))
func _complete_rescue(_id: String) -> void:
 match _id:
  "bump":
   s.safe.append("guest")
   s.flags.spilled = true
   s.flags.spill_tick = s.tick
   note("spill", "My elbow caught the glass. His drink soaked his suit.")
   events.append({"kind":"sound", "text":"drink_spill"})
  "glass": note("poison_evidence", "A sharp chemical residue in the glass. The drink was poisoned; nothing here identifies who did it.")
  "shove":
   s.safe.append("chandelier_guest")
   s.flags.shove_tick = s.tick
   note("shove", "I shoved the guest out from beneath the chandelier. She was furious.")
   events.append({"kind":"sound", "text":"shove"})
  "wreckage": note("wreckage", "Broken glass and a snapped suspension pin.")
func _observe_rescues() -> void:
 if s.room == "salon":
  if flag("party_arrived") and not s.dead.has("guest") and not s.safe.has("guest"):
   note("party_arrival", "The luggage owner is at the party, holding a drink.")
  if s.dead.has("guest"): note("guest_body", "The luggage owner has collapsed beside his glass.")
 if flag("chat_delay") and s.room == str(s.flags.get("chat_room","cabins")) and s.tick < _chat_departure():
  note("chat_seen", "The talkative passenger has stopped the luggage owner for a conversation.")
  if nearby(s.room, Rooms.point(s.flags.get("chat_guest_pos",[745,530])),100):
   note("chat_heard", "Passenger: Before you go to the party, you must hear about my nephew…")
 if s.room == "controls":
  if flag("trapped") and not s.safe.has("chatterbox") and not s.dead.has("chatterbox"):
   note("trapped", "Steam blocks the far room's normal exit. The talkative passenger is trapped.")
  if s.dead.has("chatterbox"): note("steam_body", "The passenger lies motionless beyond the steam leak.")
 if s.room == "foyer":
  if flag("chandelier_warning"): note("creak", "The chandelier creaks and trembles above the guest.")
  if flag("chandelier_fallen"): note("fallen_seen", "The fallen chandelier leaves enough space to cross the foyer.")

func actor_positions() -> Dictionary:
 return Crowd.separate(_planned_actors(),s.flags)

func _planned_actors() -> Dictionary:
 var result := {}
 var t := int(s.tick)
 for id in ["guest","chandelier_guest","chatterbox","crew","porter"]:
  result[id] = Routines.passenger(id,t,boarding_time(),party_arrival(),s.flags)
 result.dock_sailor = dock_sailor_position()
 if t >= DEMO_START and t < DEMO_END: result.crew.action = "demonstrate"
 if flag("chandelier_warning"): result.chandelier_guest.action = "chandelier_warn"
 if s.dead.has("chandelier_guest"): result.chandelier_guest.action = "chandelier_casualty"
 if s.safe.has("chandelier_guest"):
  result.chandelier_guest.pos = [780,470]
 if s.dead.has("guest"): result.guest.action = "poison_collapse"
 if s.safe.has("guest"):
  var elapsed := t-int(s.flags.spill_tick)
  result.guest = Routines.travel(Routines.path("salon",Vector2(800,330),"cabins",Vector2(580,315)),maxi(0,elapsed-15))
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
   result.guest = {"room":room,"pos":[guest_point.x,guest_point.y],"action":"talk","facing":"left"} if t < depart else Routines.travel(Routines.path(room,guest_point,"salon",Vector2(800,330)),t-depart,"hold_drink")
  result.chatterbox = {"room":room,"pos":[chatter_point.x,chatter_point.y],"action":"talk","facing":"right"} if t < depart else Routines.travel(Routines.path(room,chatter_point,"cabins",Vector2(700,530)),t-depart,"idle")
 return result

func _escape_path() -> Array:
 var points := Routines.path("controls",Vector2(840,360),"salon",Vector2(850,365)).duplicate(true)
 points.append_array(Routines.path("salon",Vector2(850,365),"cabins",Vector2(700,530)))
 return points

func _chat_departure() -> int:
 return 4*HOUR-Routines.duration(Routines.path(str(s.flags.get("chat_room","cabins")),Rooms.point(s.flags.get("chat_guest_pos",[745,530])),"salon",Vector2(800,330)))-60

func _open_passenger_doors(planned: Dictionary) -> void:
 for actor in planned.values():
  if actor.room != "cabins" or actor.action != "walk": continue
  for id in Rooms.CABIN_DOORS:
   if Rooms.point(actor.pos).distance_to(Vector2(Rooms.CABIN_DOORS[id],405)) < 85:
    s.flags[id] = true

func _witness_departures(previous: Dictionary) -> void:
 if s.safe.has("chatterbox") and previous.get("chatterbox",{}).get("room","") == "controls" and s.actors.chatterbox.room != "controls":
  if s.room == "controls": note("escape_departure", "The passenger leaves through the cleared steam passage.")
  elif s.room == s.actors.chatterbox.room: note("escape_departure", "The passenger emerges from the steam room.")

func _travel(from: Vector2, to: Vector2, time: int, start_tick: int, end_tick: int) -> Array:
 var p := from.lerp(to,clampf(float(time-start_tick)/float(end_tick-start_tick),0,1))
 return [p.x,p.y]

func party_arrival() -> int:
 if not luggage_delayed(): return CREAK-30
 return 4*HOUR if flag("chat_delay") else 3*HOUR+300

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
  if s.room == "salon": note("party_arrival", "The luggage owner is at the party, holding a drink.")
 var spike := arrival+30 if luggage_delayed() else CREAK+20
 var drink := spike + (80 if luggage_delayed() else 40)
 if s.tick == spike:
  s.flags.spiked = true
  if s.room == "salon":
   note("spike", "An obscured hand tips something into the guest's glass.")
   events.append({"kind":"spike", "text":""})
 if s.tick == drink and not s.safe.has("guest"):
  _death("guest", "The guest drank, then collapsed beside the poisoned glass.", "salon")

func summary() -> String:
 var lines: Array[String] = []
 var names := {"guest":"Luggage owner", "chandelier_guest":"Foyer guest", "chatterbox":"Talkative passenger"}
 for id in names:
  lines.append("%s: %s" % [names[id], "died" if s.dead.has(id) else "survived"])
 if s.dead.is_empty():
  return "EVERYONE SURVIVED · ALL ABOARD COMPLETE\n" + " · ".join(lines) + "\nThe next page reveals a new gift: location rewriting."
 return "THE PARTY HAS ENDED\n" + " · ".join(lines) + "\nYour diary records what you witnessed on this voyage. Turn back the pages to try again."

func _demonstration() -> void:
 if s.tick < DEMO_START or s.tick > DEMO_END: return
 if not s.flags.has("demo_cursor"):
  s.flags.demo_cursor = 0
  s.flags.demo_progress = 0
  s.flags.demo_heard = []
 var cursor := int(s.flags.demo_cursor)
 if cursor >= 3: return
 var close := nearby("controls", Vector2(310,305), 110)
 var remaining := (3-cursor)*30 - int(s.flags.demo_progress)
 # Waiting and pausing use only spare time inside the authored window.
 if not close and DEMO_END-int(s.tick) > remaining:
  if s.room == "controls": s.message = "The engineer glances at his watch, waiting for an audience."
  return
 s.flags.demo_progress += 1
 if close:
  var lines := ["Engineer: Pressure must be running for the controls to respond.", "Engineer: Enter three digits, then press Commit. Clear starts your entry again.", "Engineer: Today's shutoff code is %s." % s.code]
  note("demo_%d" % cursor, lines[cursor])
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
 if not s.code_open or not nearby("controls", Vector2(350,300)) or not memory.procedure: return false
 if s.entry.length() != 3 or s.entry != s.code:
  s.message = "Code rejected. Clear and try again."
  s.flags.panel_rejected = true
  return false
 s.flags.panel_rejected = false
 s.flags.steam_off = true
 s.code_open = false
 note("shutoff_%d" % s.tick, "I stopped the steam.")
 events.append({"kind":"sound", "text":"steam_valve"})
 if flag("trapped") and s.tick < STEAM_FATAL and not s.dead.has("chatterbox"):
  if not s.safe.has("chatterbox"): s.safe.append("chatterbox")
  s.flags.escape_tick = s.tick
  note("escape", "The steam clears. The passenger starts towards the exit.")
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
  if s.room == "docks": note("bag_found", "The sailor found the suitcase and called to its owner.")

func dock_sailor_position() -> Dictionary:
 var t := int(s.tick)
 var p := Vector2(435,430)
 var action := "talk"
 if flag("bag_found"):
  return Routines.travel(Routines.path("docks",Rooms.point(s.flags.get("sailor_return_pos",[190,390])),"docks",Vector2(435,430)),t-int(s.flags.get("bag_found_tick",720)))
 elif t >= 50 and t < 100:
  p = Rooms.point(_travel(Vector2(435,430),Vector2(190,390),t,50,100))
  action = "walk"
 elif t >= 100:
  p = Vector2(190,390)
  action = "handle_baggage"
 return {"room":"docks", "pos":[p.x,p.y], "action":action, "skin":"sailor"}

static func observation_time(tick: int) -> String:
 var minutes := int(tick * 60 / HOUR)
 return "%02d:%02d" % [1 + int(minutes / 60), minutes % 60]

func restore_notebook() -> void:
 # Old saves mixed previous loops and unwitnessed death notices into memory.
 # Keep only current-run text with a matching recorded observation timestamp.
 var prefix := "Loop %d · Hour " % (int(s.loop)+1)
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
  elif not text.begins_with("Hour "):
   notes.append(text)
 memory.notes = notes
