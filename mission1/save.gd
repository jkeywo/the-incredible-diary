extends RefCounted
## Append-only transactions retain the entire recorded leg without rewriting it each second.
## A checksum protects each transaction; an interrupted tail is ignored and repaired on load.
const DEFAULT_PATH := "user://mission1_v2.journal"
const SCHEMA := 2
const Rooms = preload("res://mission1/rooms.gd")
var saved_count := 0
var generation := -1
var sequence := 0

static func has_any(path: String = DEFAULT_PATH) -> bool:
 for suffix in ["", ".next", ".bak"]:
  if FileAccess.file_exists(path+suffix): return true
 return false

static func clear(path: String = DEFAULT_PATH) -> Dictionary:
 for suffix in ["", ".next", ".bak"]:
  if FileAccess.file_exists(path+suffix):
   var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
   if err != OK: return {"ok":false, "reason":"Could not clear Mission 1 save (%d)" % err}
 return {"ok":true}

func save_run(run: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
 # Input such as code digits can change the current tick without advancing time.
 run.history[-1] = run.s.duplicate(true)
 var rewrite := saved_count == 0 or generation != int(run.s.loop) or not FileAccess.file_exists(path)
 if rewrite: saved_count = 0
 sequence += 1
 var batch := {"schema":SCHEMA, "sequence":sequence, "loop":run.s.loop, "start":saved_count,
  "history":run.history.slice(saved_count), "current":run.s, "memory":run.memory}
 var body := JSON.stringify(batch)
 var line := JSON.stringify({"body":body,"sha256":body.sha256_text()})+"\n"
 var target := path+".next" if rewrite else path
 var file := FileAccess.open(target, FileAccess.WRITE if rewrite else FileAccess.READ_WRITE)
 if file == null: return {"ok":false,"reason":"Could not write voyage journal."}
 if not rewrite: file.seek_end()
 file.store_string(line)
 file.flush()
 var error := file.get_error()
 file.close()
 if error != OK: return {"ok":false,"reason":"Could not flush voyage journal."}
 if rewrite:
  var absolute := ProjectSettings.globalize_path(path)
  if FileAccess.file_exists(path+".bak"):
   error = DirAccess.remove_absolute(absolute+".bak")
   if error != OK: return {"ok":false,"reason":"Could not rotate voyage backup."}
  if FileAccess.file_exists(path):
   error = DirAccess.rename_absolute(absolute, absolute+".bak")
   if error != OK: return {"ok":false,"reason":"Could not protect previous voyage."}
  error = DirAccess.rename_absolute(absolute+".next", absolute)
  if error != OK: return {"ok":false,"reason":"Could not promote voyage journal."}
 saved_count = run.history.size()
 generation = int(run.s.loop)
 if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
 return {"ok":true}

static func load_saved(path: String = DEFAULT_PATH) -> Dictionary:
 var best: Dictionary = {}
 for suffix in ["", ".next", ".bak"]:
  var candidate := _read(path+suffix)
  if candidate.get("ok",false) and (best.is_empty() or int(candidate.data.sequence)>int(best.data.sequence)):
   best = candidate
 return best if not best.is_empty() else {"ok":false,"reason":"No valid Mission 1 journal."}

static func _read(path: String) -> Dictionary:
 if not FileAccess.file_exists(path): return {}
 var file := FileAccess.open(path, FileAccess.READ)
 if file == null: return {}
 var history: Array = []
 var latest: Dictionary = {}
 while not file.eof_reached():
  var line := file.get_line()
  if line.is_empty(): continue
  var parser := JSON.new()
  if parser.parse(line) != OK: break
  var wrapper: Variant = parser.data
  if not wrapper is Dictionary or not wrapper.get("body") is String: break
  if str(wrapper.body).sha256_text() != wrapper.get("sha256",""): break
  if parser.parse(wrapper.body) != OK: break
  var batch: Variant = parser.data
  if not batch is Dictionary or not _valid_batch(batch, history.size()): break
  if not latest.is_empty() and (int(batch.sequence)<=int(latest.sequence) or int(batch.loop)!=int(latest.current.loop)): break
  history.append_array(batch.history)
  history[-1] = batch.current.duplicate(true)
  latest = {"current":batch.current, "memory":batch.memory, "sequence":batch.sequence}
 file.close()
 if latest.is_empty(): return {}
 latest.history = history
 return {"ok":true,"data":latest,"source":path}

static func _valid_state(state: Variant) -> bool:
 if not state is Dictionary: return false
 for key in ["tick","loop","room","pos","facing","code","flags","dead","safe","action","entry","code_open","dialogue","observed","message","finished","door_cooldown"]:
  if not state.has(key): return false
 if not Rooms.ROOMS.has(state.room) or not state.pos is Array or state.pos.size()!=2: return false
 if not state.flags is Dictionary or not state.action is Dictionary or not state.dead is Array or not state.safe is Array: return false
 if not state.observed is Array or not state.entry is String or not state.message is String: return false
 if str(state.code).length()!=3 or int(state.tick)<0 or int(state.tick)>10800: return false
 if not state.facing in ["up","down","left","right"]: return false
 for coordinate in state.pos:
  if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)): return false
 if not state.action.is_empty():
  for key in ["id","progress","duration","pos","room"]:
   if not state.action.has(key): return false
 return true

static func _valid_batch(batch: Dictionary, count: int) -> bool:
 if batch.get("schema")!=SCHEMA or int(batch.get("start",-1))!=count or not batch.get("history") is Array: return false
 if not _valid_state(batch.get("current")) or not batch.get("memory") is Dictionary: return false
 if int(batch.current.tick)!=count+batch.history.size()-1: return false
 for key in ["notes","bag","procedure","shortcut","reset","completed"]:
  if not batch.memory.has(key): return false
 if not batch.memory.notes is Array: return false
 for i in batch.history.size():
  if not _valid_state(batch.history[i]) or int(batch.history[i].tick)!=count+i: return false
 return batch.has("sequence") and batch.has("loop")
