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
 if run.memory.reset: queue(run,"diary")
 if not run.s.dialogue.is_empty() or not run.s.get("conversation",{}).is_empty(): return
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
 if controller: return {"highlight":"X — Highlight", "wait":"Hold LT — Wait", "diary":"Y — Open diary"}.get(id,"")
 return {"highlight":"H — Highlight", "wait":"Hold F — Wait", "diary":"Tab — Open diary"}.get(id,"")
