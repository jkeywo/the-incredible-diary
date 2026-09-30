extends RefCounted
const Text = preload("res://localisation/source_text.gd")
const Rooms = preload("res://mission1/rooms.gd")
const Routes = preload("res://mission1/routines.gd")
const Speech = preload("res://mission1/conversations.gd")
const PANEL := Vector2(310,305)
const INTERVAL := 900

static func update(run) -> void:
 if not run.s.has("operator"):
  run.s.operator = {"phase":"demo","next_check":0,"until":0}
 var state: Dictionary = run.s.operator
 if state.phase == "demo":
  if int(run.s.flags.get("demo_cursor",0)) < 3 and run.s.tick < run.DEMO_END: return
  state.phase = "away"
  state.next_check = (int(run.s.tick/INTERVAL)+1)*INTERVAL
 if not state.has("until_frame"):
  state.until_frame = int(run.s.frame)+maxi(0,ceili((float(state.get("until",run.s.tick))-run.s.tick)/run.CLOCK_RATE))
 var actor: Dictionary = run.s.actors.get("crew",{})
 if actor.is_empty(): return
 if state.phase == "away":
  var travel := Routes.duration(Routes.path(actor.room,Rooms.point(actor.pos),"controls",PANEL))
  if run.s.tick >= state.next_check-travel: state.phase = "check"
 if state.phase == "check" and run.s.tick >= state.next_check and actor.room == "controls" and Rooms.point(actor.pos).distance_to(PANEL)<12:
  if not run.flag("steam_off"):
   finish_visit(run)
  elif run.s.dialogue.is_empty() and run.s.get("conversation",{}).is_empty():
   state.phase = "speak"
   state.until_frame = int(run.s.frame)+40
   Speech.say(run,"crew",Text.MISSION1_WHY_HAS_THIS_BEEN_SWITCHED_OFF,"speech","operator_%d" % state.next_check,40)
 if state.phase == "speak" and run.s.frame >= state.until_frame:
  state.phase = "operate"
  state.until_frame = int(run.s.frame)+15
 if state.phase == "operate" and run.s.frame >= state.until_frame:
  run.s.flags.steam_off = false
  if run.s.room == "controls": run.events.append({"kind":"sound","text":"steam_valve"})
  finish_visit(run)

static func finish_visit(run) -> void:
 run.s.operator.phase = "away"
 run.s.operator.next_check = (int(run.s.tick/INTERVAL)+1)*INTERVAL

static func pose(run, fallback: Dictionary) -> Dictionary:
 var state: Dictionary = run.s.get("operator",{})
 if state.is_empty() or state.phase == "demo": return fallback
 if state.phase == "away": return Rooms.group_slot("foyer",2,0)
 return {"room":"controls","pos":[PANEL.x,PANEL.y],"action":"restore_steam" if state.phase == "operate" else "talk" if state.phase == "speak" else "idle"}
