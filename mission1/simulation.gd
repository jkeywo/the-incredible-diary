extends RefCounted
## Deterministic 10 Hz Mission 1 simulation. No rendering or wall clock dependencies.
const Rooms = preload("res://mission1/rooms.gd")
const HOUR := 1800
const END := 6 * HOUR
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
 _option(result, "porter", "Ask about the stair", "foyer", Vector2(450,365), local, not flag("shortcut"))
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
 pass

func _observe() -> void:
 if s.room == "docks" and s.tick < HOUR:
  note("docks", "The luggage owner is waiting on the docks.")
 if nearby("docks", Vector2(390,430), 110) and s.tick >= 50 and s.tick <= 500:
  memory.bag = true
  s.flags.bag_lead = true
  note("bag_lead", "Guest: That is somebody else's suitcase! I will not board without mine.")
 if memory.shortcut and nearby("foyer", Vector2(580,250)) and not flag("shortcut_lead"):
  s.flags.shortcut_lead = true
  note("stair_reminder", "The stair's brass catch is still here.")
 _observe_rescues()

func _rescue_options(_result: Array[Dictionary], _local: bool) -> void:
 pass
func _complete_rescue(_id: String) -> void:
 pass
func _observe_rescues() -> void:
 pass

func actor_positions() -> Dictionary:
 var t := int(s.tick)
 var guest := {"room":"docks", "pos":[390,430], "action":"search_bag" if flag("bag_hidden") else "idle", "skin":"rake"}
 if t >= (HOUR if flag("bag_hidden") else 800):
  guest = {"room":"cabins", "pos":[580,315], "action":"idle", "skin":"rake"}
 return {"guest":guest, "chandelier_guest":{"room":"foyer", "pos":[680,440], "action":"idle", "skin":"glamorous"}, "chatterbox":{"room":"cabins", "pos":[930,320], "action":"idle", "skin":"matron"}, "crew":{"room":"controls", "pos":[310,305], "action":"idle", "skin":"ex_army"}}
