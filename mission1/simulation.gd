extends RefCounted
## Deterministic 10 Hz Mission 1 simulation. No rendering or wall clock dependencies.
const Rooms = preload("res://mission1/rooms.gd")
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
 var loop := int(s.get("loop", -1)) + 1
 var value := (loop * 71 + 83) % 216
 var code := ""
 for i in 3:
  code += str(value % 6 + 1)
  value = int(value / 6)
 s = {"tick":0, "loop":loop, "room":"docks", "pos":[580.0,490.0], "facing":"down", "code":code,
  "flags":{}, "dead":[], "safe":[], "action":{}, "entry":"", "code_open":false,
  "dialogue":{}, "observed":[], "message":"A new posting. An unmooring party. What could possibly go wrong?",
  "finished":false, "door_cooldown":0}
 history = [s.duplicate(true)]
 events.clear()

func flag(key: String) -> bool:
 return bool(s.flags.get(key, false))

func note(key: String, text: String, permanent := true) -> void:
 if s.observed.has(key): return
 s.observed.append(key)
 var line := "Loop %d · Hour %d — %s" % [int(s.loop)+1, mini(6, 1+int(s.tick/HOUR)), text]
 if permanent: memory.notes.append(line)
 s.message = text
 events.append({"kind":"observation", "text":text})

func nearby(room: String, p: Vector2, radius := 80.0) -> bool:
 return s.room == room and Rooms.point(s.pos).distance_to(p) <= radius

func options(local := true) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 if not s.action.is_empty() or s.finished: return result
 _option(result, "inspect_bag", "Inspect luggage", "docks", Vector2(340,430), local, s.tick < HOUR and not flag("bag_hidden"))
 _option(result, "hide_bag", "Hide bag nearby", "docks", Vector2(340,430), local, s.tick < HOUR and flag("bag_lead") and not flag("bag_hidden"))
 _option(result, "porter", "Ask about the stair", "foyer", Vector2(450,365), local, s.tick >= 3*HOUR and not flag("shortcut"))
 _option(result, "latch", "Release stair latch", "foyer", Vector2(580,250), local, flag("shortcut_lead") and not flag("shortcut"))
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
 s.tick += 1
 s.door_cooldown = maxi(0, int(s.door_cooldown)-1)
 if direction.length_squared() > 0.01:
  var p := Rooms.move(s.room, Rooms.point(s.pos), direction.limit_length() * 14.0)
  s.pos = [p.x,p.y]
  s.facing = ("right" if direction.x > 0 else "left") if absf(direction.x)>absf(direction.y) else ("down" if direction.y>0 else "up")
  if s.door_cooldown == 0:
   for door in Rooms.exits(s.room, flag("shortcut")):
    if p.distance_to(Rooms.point(door.point)) < 24:
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
 _observe()
 if s.tick >= END:
  s.finished = true
  memory.completed = bool(memory.completed) or s.dead.is_empty()
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
 match id:
  "inspect_bag":
   if memory.bag:
    s.flags.bag_lead = true
    note("bag_reminder", "The same monogram. He still refuses to board without this bag.")
   else:
    note("bag_inspect", "A monogrammed suitcase. Its owner is arguing with the porter nearby.")
  "hide_bag":
   s.flags.bag_hidden = true
   note("bag_hidden", "I tucked the suitcase behind the baggage screen. Its owner missed boarding.")
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
 var names := {"guest":"the luggage owner", "chandelier_guest":"the foyer guest", "chatterbox":"the talkative passenger"}
 memory.notes.append("Hour %d — The diary records the death of %s." % [mini(6,1+int(s.tick/HOUR)), names[id]])
 s.message = "The diary records the death of %s." % names[id]
 if not memory.reset:
  memory.reset = true
  s.message += " The ink runs backwards. Tab / Y: read the diary; R / Back: return to the docks. You may keep investigating."
 events.append({"kind":"death", "text":id})

func _observe() -> void:
 if s.room == "docks" and s.tick < HOUR:
  note("docks", "The luggage owner is waiting on the docks.")
 if nearby("docks", Vector2(390,430), 110) and s.tick >= 50 and s.tick <= 500:
  memory.bag = true
  s.flags.bag_lead = true
  note("bag_lead", "Guest: That is somebody else's suitcase! I will not board without mine.")
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
   note("spill", "My elbow caught the glass. His drink soaked his suit; he stormed off to change.")
   events.append({"kind":"sound", "text":"drink_spill"})
  "glass": note("poison_evidence", "A sharp chemical residue in the glass. The drink was poisoned; nothing here identifies who did it.")
  "shove":
   s.safe.append("chandelier_guest")
   note("shove", "I shoved the guest out from beneath the chandelier. She was furious.")
   events.append({"kind":"sound", "text":"shove"})
  "wreckage": note("wreckage", "Broken glass and a snapped suspension pin. The chandelier fell during Hour 3.")
func _observe_rescues() -> void:
 if s.room == "salon":
  if flag("party_arrived") and not s.dead.has("guest") and not s.safe.has("guest"):
   note("party_arrival", "The luggage owner is at the party, holding a drink.")
  if s.dead.has("guest"): note("guest_body", "The luggage owner has collapsed beside his glass.")
 if s.room == "cabins" and flag("chat_delay") and s.tick < 4*HOUR:
  note("chat_seen", "The talkative passenger has stopped the luggage owner in the corridor.")
  if nearby("cabins", Vector2(700,530),100):
   note("chat_heard", "Passenger: Before you go to the party, you must hear about my nephew…")
 if s.room == "controls":
  if flag("trapped") and not s.safe.has("chatterbox") and not s.dead.has("chatterbox"):
   note("trapped", "Steam blocks the far room's normal exit. The talkative passenger is trapped.")
  if s.dead.has("chatterbox"): note("steam_body", "The passenger lies motionless beyond the steam leak.")
 if s.room == "foyer":
  if flag("chandelier_warning"): note("creak", "The chandelier creaks and trembles above the guest.")
  if flag("chandelier_fallen"): note("fallen_seen", "The fallen chandelier leaves enough space to cross the foyer.")

func actor_positions() -> Dictionary:
 var t := int(s.tick)
 var guest := {"room":"docks", "pos":[390,430], "action":"search_bag" if flag("bag_hidden") else "idle", "skin":"rake"}
 if t >= (HOUR if flag("bag_hidden") else 800):
  guest = {"room":"cabins", "pos":[580,315], "action":"idle", "skin":"rake"}
 if flag("chat_delay") and t < 4*HOUR:
  guest.room = "cabins"
  guest.pos = [745,530]
  guest.action = "talk"
 if flag("party_arrived"):
  guest.room = "salon"
  guest.pos = [800,330]
  guest.action = "hold_drink"
 if s.dead.has("guest"): guest.action = "poison_collapse"
 if s.safe.has("guest"):
  guest.action = "spill_react" if t-int(s.flags.spill_tick)<15 else "walk"
  var travel := clampf(float(t-int(s.flags.spill_tick)-15)/45.0, 0, 1)
  var p := Vector2(800,330).lerp(Vector2(580,650),travel)
  guest.pos = [p.x,p.y]
  if travel >= 1:
   guest.room = "cabins"
   guest.pos = [580,315]
   guest.action = "idle"
 var chandelier := {"room":"foyer", "pos":[680,440], "action":"idle", "skin":"glamorous"}
 if s.safe.has("chandelier_guest"): chandelier.pos = [780,470]
 elif s.dead.has("chandelier_guest"): chandelier.action = "chandelier_casualty"
 elif flag("chandelier_warning"): chandelier.action = "chandelier_warn"
 var chatter := {"room":"cabins", "pos":[930,320], "action":"idle", "skin":"matron"}
 if t >= 3 * HOUR:
  chatter.room = "controls"
  chatter.pos = [840,360]
  chatter.action = "steam_trapped" if flag("trapped") else "idle"
 if s.dead.has("chatterbox"): chatter.action = "steam_casualty"
 if s.safe.has("chatterbox"):
  chatter.room = "cabins"
  chatter.pos = [700,530]
  chatter.action = "chatter"
 return {"guest":guest, "chandelier_guest":chandelier, "chatterbox":chatter, "crew":{"room":"controls", "pos":[310,305], "action":"talk" if t >= DEMO_START and t < DEMO_END else "idle", "skin":"ex_army"}}

func party_arrival() -> int:
 if not flag("bag_hidden"): return CREAK-30
 return 4*HOUR if flag("chat_delay") else 3*HOUR+300

func _party_schedule() -> void:
 if s.safe.has("chatterbox") and flag("bag_hidden") and s.tick < 3*HOUR+300 and not flag("chat_delay"):
  s.flags.chat_delay = true
 var arrival := party_arrival()
 if s.tick >= arrival and not flag("party_arrived"):
  s.flags.party_arrived = true
  if s.room == "salon": note("party_arrival", "The luggage owner is at the party, holding a drink.")
 var spike := arrival+30 if flag("bag_hidden") else CREAK
 var drink := spike+80
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
  return "EVERYONE SURVIVED · MISSION 1 COMPLETE\n" + " · ".join(lines) + "\nThe next page reveals a new gift: location rewriting."
 return "THE PARTY HAS ENDED\n" + " · ".join(lines) + "\nYour diary retains only what you witnessed. Continue to turn back the pages."

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
  var lines := ["Engineer: Pressure must be running for the controls to respond.", "Engineer: Enter three digits, then press Confirm. Clear starts your entry again.", "Engineer: Today's shutoff code is %s." % s.code]
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
  note("escape", "The passenger crosses the cleared path and leaves through the normal exit.")
 return true
