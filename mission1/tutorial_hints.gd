extends RefCounted
const Text = preload("res://localisation/source_text.gd")
const Speech = preload("res://mission1/conversations.gd")
const TEXT := {"highlight":Text.MISSION1_I_WONDER_WHAT_I_SHOULD_DO, "wait":Text.MISSION1_HURRY_UP_AND_WAIT, "diary":Text.MISSION1_SOMETHING_HAS_CHANGED_IN_THE_DIARY_I_SHOULD_OPEN_IT}

static func queue(run, id: String) -> void:
 if run.memory.get("hints",{}).get(id,false): return
 if not run.s.has("hint_queue"): run.s.hint_queue = []
 if not run.s.hint_queue.has(id): run.s.hint_queue.append(id)

static func update(run) -> void:
 if run.tutorial_active(): return
 if run.s.room == "foyer": queue(run,"highlight")
 # Body thoughts are triggered by sight, never by an unseen death or retained knowledge.
 if run.s.has("hint_queue"): run.s.hint_queue.erase("diary")
 if not run.s.dialogue.is_empty() or not run.s.get("conversation",{}).is_empty(): return
 if run.memory.get("hints",{}).get("diary",false):
  run.s["body_thought_queue"] = []
 var bodies: Array = run.s.get("body_thought_queue",[])
 if not bodies.is_empty():
  var victim: String = str(bodies.pop_front())
  var text := Text.MISSION1_WHAT_A_TRAGEDY_HMMM_MY_DIARY_IS_SHAKING_I_FEEL_LIKE_I_SHOULD_TAKE
  Speech.say(run,"amelia",text,"thought","diary_magic_"+victim)
  run.s.dialogue.hint = "diary"
  run.s.dialogue.victim = victim
  if not run.memory.has("hints"): run.memory.hints = {}
  run.memory.hints.diary = true
  return
 var pending: Array = run.s.get("hint_queue",[])
 if pending.is_empty(): return
 var id: String = "diary" if pending.has("diary") else str(pending[0])
 pending.erase(id)
 if not run.memory.has("hints"): run.memory.hints = {}
 run.memory.hints[id] = true
 Speech.say(run,"amelia",TEXT[id],"thought")
 run.s.dialogue.hint = id

static func prompt(id: String, controller: bool, touch: bool) -> String:
 if touch: return {"highlight":Text.MISSION1_TAP_HIGHLIGHT, "wait":Text.MISSION1_TAP_WAIT, "diary":Text.MISSION1_TAP_DIARY}.get(id,"")
 var bindings = Engine.get_main_loop().root.get_node("InputBindings")
 if id not in ["highlight", "wait", "diary"]: return ""
 var key: String = bindings.prompt(id, controller)
 return {"highlight": Text.MISSION1_S_HIGHLIGHT % key, "wait": Text.MISSION1_TOGGLE_S_WAIT % key, "diary": Text.MISSION1_S_OPEN_DIARY % key}.get(id, "")


static func see_body(run, victim: String) -> void:
 if run.memory.get("hints",{}).get("diary",false): return
 if not run.s.has("body_thought_queue"): run.s.body_thought_queue = []
 if not run.s.body_thought_queue.has(victim): run.s.body_thought_queue.append(victim)
