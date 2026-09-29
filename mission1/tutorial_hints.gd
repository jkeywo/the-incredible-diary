extends RefCounted
const Speech = preload("res://mission1/conversations.gd")
const TEXT := {"highlight":"I wonder what I should do?", "wait":"Hurry up and wait…", "diary":"Something has changed in the diary. I should open it."}

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
  var text := "What a tragedy. Hmmm, my diary is shaking, I feel like I should take a look."
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
 if touch: return {"highlight":"Tap Highlight", "wait":"Hold Wait", "diary":"Tap Diary"}.get(id,"")
 if controller: return {"highlight":"A — Highlight", "wait":"Hold B — Wait", "diary":"Y — Open diary"}.get(id,"")
 return {"highlight":"H — Highlight", "wait":"Hold F — Wait", "diary":"Tab — Open diary"}.get(id,"")


static func see_body(run, victim: String) -> void:
 if run.memory.get("hints",{}).get("diary",false): return
 if not run.s.has("body_thought_queue"): run.s.body_thought_queue = []
 if not run.s.body_thought_queue.has(victim): run.s.body_thought_queue.append(victim)
