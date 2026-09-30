extends RefCounted
## Optional duties and recorded journeys to the cabin named by Boy.
const Rooms = preload("res://mission1/rooms.gd")
const Speech = preload("res://mission1/conversations.gd")
const STATION := Vector2(865,205)
const DRINKS := {"lemonade":"Lemonade", "water":"Sparkling water", "tea":"Tea"}
const GUESTS := {
 "guest":{"name":"Mr. Felix Harcourt", "door":"cabin_middle", "number":1, "drink":"lemonade", "request":"Lemonade, please, Boy.", "thanks":"Excellent lemonade, Boy. Thank you.", "wrong":"I asked for lemonade, Boy. Do try to remember."},
 "chandelier_guest":{"name":"Miss Evelyn Vale", "door":"cabin_left", "number":2, "drink":"water", "request":"Sparkling water, please, Boy.", "thanks":"Just what I wanted. Thank you, Boy.", "wrong":"That isn't sparkling water. Perhaps someone else ordered it?"},
 "chatterbox":{"name":"Mrs. Mabel Pritchard", "door":"cabin_right", "number":3, "drink":"tea", "request":"A proper cup of tea, please, Boy.", "thanks":"Lovely. A proper cup of tea. Thank you, Boy.", "wrong":"Tea, Boy. A proper cup of tea."}
}
const REACTION_TICKS := 90

static func defaults(run) -> void:
 if not run.memory.has("cabins"): run.memory.cabins = []
 if not run.memory.has("preferences"): run.memory.preferences = []
 if not run.s.has("hospitality"):
  run.s.hospitality = {"carried":"", "outcomes":{}, "detours":{}, "menu":""}

static func owner(door: String) -> String:
 for id in GUESTS:
  if GUESTS[id].door == door: return id
 return ""

static func busy(run, id: String) -> bool:
 if run.s.dead.has(id) or run.s.safe.has(id): return true
 if run.s.get("conversation",{}).get("people",[]).has(id): return true
 if id == "guest" and (run.flag("chat_delay") or run.flag("party_arrived")): return true
 if id == "chatterbox" and (run.flag("chat_delay") or run.flag("trapped")): return true
 return id == "chandelier_guest" and run.s.tick >= 3500

static func detour_plan(run, id: String, door: String) -> Dictionary:
 if busy(run,id) or run.s.hospitality.detours.has(id): return {}
 var actor: Dictionary = run.s.actors[id]
 if actor.room != "foyer": return {}
 return {"door":door,"phase":"outward","home":actor.duplicate(true),"react_until":0}

static func options(run, result: Array[Dictionary], local: bool) -> void:
 defaults(run)
 var state: Dictionary = run.s.hospitality
 if not str(state.menu).is_empty():
  var id: String = state.menu
  if not run.s.actors.has(id) or busy(run,id) or not can_direct(run,id): return
  var actor: Dictionary = run.s.actors[id]
  for door in Rooms.CABIN_DOORS:
   var label := "Cabin %d" % GUESTS[owner(door)].number
   run._option(result,"direct:%s:%s" % [id,door],label,actor.room,Rooms.point(actor.pos),local,true)
  run._option(result,"duties_back","Back",actor.room,Rooms.point(actor.pos),local,true)
  return
 for door in Rooms.CABIN_DOORS:
  run._option(result,"plate:"+door,"Inspect nameplate", "cabins",Vector2(Rooms.CABIN_DOORS[door],405),local,true)
 if state.carried == "":
  for drink in DRINKS: run._option(result,"collect:"+drink,"Get "+DRINKS[drink],"salon",STATION,local,true)
 else: run._option(result,"return_drink","Return drink","salon",STATION,local,true)
 for id in GUESTS:
  if not run.s.actors.has(id) or busy(run,id) or state.detours.has(id): continue
  var actor: Dictionary = run.s.actors[id]
  var outcome: Dictionary = state.outcomes.get(id,{})
  var request_label: String = "Prefers "+DRINKS[GUESTS[id].drink] if run.memory.preferences.has(id) else "Ask about drinks"
  run._option(result,"request:"+id,request_label,actor.room,Rooms.point(actor.pos),local,actor.room == "salon" and not outcome.get("asked",false) and not outcome.get("served",false))
  if actor.room == "salon" and state.carried != "" and not outcome.get("served",false):
   var allowed: bool = not outcome.get("wrong_drink",false) or state.carried == GUESTS[id].drink
   run._option(result,"serve:"+id,"Offer "+DRINKS[state.carried],actor.room,Rooms.point(actor.pos),local,allowed)
  run._option(result,"directions:"+id,"Give cabin directions",actor.room,Rooms.point(actor.pos),local,can_direct(run,id))

static func can_direct(run, id: String) -> bool:
 var actor: Dictionary = run.s.actors.get(id,{})
 var outcome: Dictionary = run.s.hospitality.outcomes.get(id,{})
 return actor.get("room","") == "foyer" and not outcome.get("found_cabin",false) and not outcome.get("directed",false) and not run.s.hospitality.detours.has(id)

static func reply(run, id: String, text: String) -> void:
 Speech.say(run,id,text,"speech","duty_%s_%d" % [id,run.s.frame])

static func complete(run, action: String) -> bool:
 defaults(run)
 var state: Dictionary = run.s.hospitality
 var parts := action.split(":")
 var verb: String = parts[0]
 var id: String = parts[1] if parts.size()>1 else ""
 match verb:
  "plate":
   if not run.memory.cabins.has(id): run.memory.cabins.append(id)
   var guest: Dictionary = GUESTS[owner(id)]
   var text := "Cabin %d — %s" % [guest.number,guest.name]
   run.note("plate_"+id,text,true,false)
   Speech.say(run,"amelia",text,"thought")
  "collect": state.carried = id
  "return_drink": state.carried = ""
  "duties_back": state.menu = ""
  "directions": state.menu = id
  "request":
   if not state.outcomes.has(id): state.outcomes[id] = {}
   state.outcomes[id].asked = true
   if not run.memory.preferences.has(id): run.memory.preferences.append(id)
   reply(run,id,GUESTS[id].request)
  "serve", "direct":
   if not state.outcomes.has(id): state.outcomes[id] = {}
   var outcome: Dictionary = state.outcomes[id]
   if verb == "serve":
    var correct: bool = state.carried == GUESTS[id].drink
    outcome["served" if correct else "wrong_drink"] = true
    if correct: state.carried = ""
    if not run.memory.preferences.has(id): run.memory.preferences.append(id)
    reply(run,id,GUESTS[id].thanks if correct else GUESTS[id].wrong)
   else:
    state.menu = ""
    var door: String = parts[2]
    var plan := detour_plan(run,id,door)
    if plan.is_empty(): return true
    state.detours[id] = plan
    if GUESTS[id].door == door:
     outcome.directed = true
     reply(run,id,"Cabin %d. Thank you, Boy." % GUESTS[id].number)
    else:
     outcome.wrong_cabin = true
     reply(run,id,"Cabin %d, you say? Very well, Boy." % GUESTS[owner(door)].number)
  _: return false
 return true

static func update(run) -> void:
 defaults(run)
 var state: Dictionary = run.s.hospitality
 for id in GUESTS:
  var guest_actor: Dictionary = run.s.actors.get(id,{})
  if guest_actor.get("room","") == "cabins" and Rooms.point(guest_actor.pos).distance_to(Vector2(Rooms.CABIN_DOORS[GUESTS[id].door],315)) < 35:
   if not state.outcomes.has(id): state.outcomes[id] = {}
   state.outcomes[id].found_cabin = true
 if state.menu != "":
  var actor: Dictionary = run.s.actors.get(state.menu,{})
  if actor.is_empty() or busy(run,state.menu) or not can_direct(run,state.menu) or not run.nearby(actor.room,Rooms.point(actor.pos)): state.menu = ""
 for id in state.detours.keys():
  var trip: Dictionary = state.detours[id]
  var actor: Dictionary = run.s.actors[id]
  if run.s.dead.has(id) or run.s.safe.has(id):
   state.detours.erase(id)
   continue
  var door: String = trip.door
  if trip.phase == "outward" and actor.room == "cabins" and Rooms.point(actor.pos).distance_to(Vector2(Rooms.CABIN_DOORS[door],465)) < 12:
   if door == GUESTS[id].door:
    trip.phase = "correct"
    continue
   if not run.s.dialogue.is_empty(): continue
   trip.phase = "reaction"
   trip.react_until = int(run.s.tick)+REACTION_TICKS
   var name: String = GUESTS[owner(door)].name
   var complaint: String = {
    "guest":"This is %s's cabin! You sent me to the wrong door, Boy.",
    "chandelier_guest":"%s? How curious, Boy. I seem to have become somebody else.",
    "chatterbox":"The plate says %s! Read the names properly next time, Boy."
   }[id] % name
   reply(run,id,complaint)
  if trip.phase == "reaction" and int(run.s.tick) >= int(trip.react_until): trip.phase = "correct"
  if trip.phase in ["correct","return"] and state.outcomes.get(id,{}).get("found_cabin",false):
   state.detours.erase(id)

static func apply_routes(run, planned: Dictionary) -> void:
 for id in run.s.get("hospitality",{}).get("detours",{}):
  if run.s.dead.has(id) or run.s.safe.has(id): continue
  var trip: Dictionary = run.s.hospitality.detours[id]
  if trip.phase in ["correct","return"]: planned[id] = {"room":"cabins","pos":[Rooms.CABIN_DOORS[GUESTS[id].door],315],"action":"idle"}
  else:
   planned[id] = {"room":"cabins","pos":[Rooms.CABIN_DOORS[trip.door],465],"action":"talk" if trip.phase == "reaction" else "idle","facing":"up"}
