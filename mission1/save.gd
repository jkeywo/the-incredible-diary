extends RefCounted
const Text = preload("res://localisation/source_text.gd")
## Append-only transactions retain the entire recorded leg without rewriting it each second.
## A checksum protects each transaction; an interrupted tail is ignored and repaired on load.
const DEFAULT_PATH := "user://mission1_v2.journal"
const SCHEMA := 5
const Messages = preload("res://foundation/message_text.gd")
const Rooms = preload("res://mission1/rooms.gd")
var saved_count := 0
var generation := -1
var sequence := 0
var saved_content_version := ""

static func has_any(path: String = DEFAULT_PATH) -> bool:
 for suffix in ["", ".next", ".bak"]:
  if FileAccess.file_exists(path+suffix): return true
 return false

static func clear(path: String = DEFAULT_PATH) -> Dictionary:
 for suffix in ["", ".next", ".bak"]:
  if FileAccess.file_exists(path+suffix):
   var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
   if err != OK: return {"ok":false, "reason":Text.MISSION1_COULD_NOT_CLEAR_MISSION_1_SAVE_D % err}
 return {"ok":true}

func restore_run(run: RefCounted, record: Dictionary) -> void:
 run.restore_record(record)
 sequence = int(record.get("sequence",0))
 saved_count = 0
 generation = -1

func save_run(run: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
 # Input such as code digits can change the current tick without advancing time.
 run.record_current_frame()
 var rewrite := saved_count == 0 or generation != int(run.s.loop) or not FileAccess.file_exists(path)
 if not run.authored_content.is_empty() and saved_content_version != str(run.authored_content.version): rewrite = true
 if rewrite: saved_count = 0
 sequence += 1
 var batch := {"schema":SCHEMA, "sequence":sequence, "loop":run.s.loop, "start":saved_count,
  "history":run.history.slice(saved_count), "current":run.s, "memory":run.memory}
 if rewrite:
  batch.authored_content = run.authored_content
  batch.content_versions = run.content_versions
 var body := JSON.stringify(batch)
 var line := JSON.stringify({"body":body,"sha256":body.sha256_text()})+"\n"
 var target := path+".next" if rewrite else path
 var file := FileAccess.open(target, FileAccess.WRITE if rewrite else FileAccess.READ_WRITE)
 if file == null: return {"ok":false,"reason":Text.MISSION1_COULD_NOT_WRITE_VOYAGE_JOURNAL}
 if not rewrite: file.seek_end()
 file.store_string(line)
 file.flush()
 var error := file.get_error()
 file.close()
 if error != OK: return {"ok":false,"reason":Text.MISSION1_COULD_NOT_FLUSH_VOYAGE_JOURNAL}
 if rewrite:
  var absolute := ProjectSettings.globalize_path(path)
  if FileAccess.file_exists(path+".bak"):
   error = DirAccess.remove_absolute(absolute+".bak")
   if error != OK: return {"ok":false,"reason":Text.MISSION1_COULD_NOT_ROTATE_VOYAGE_BACKUP}
  if FileAccess.file_exists(path):
   error = DirAccess.rename_absolute(absolute, absolute+".bak")
   if error != OK: return {"ok":false,"reason":Text.MISSION1_COULD_NOT_PROTECT_PREVIOUS_VOYAGE}
  error = DirAccess.rename_absolute(absolute+".next", absolute)
  if error != OK: return {"ok":false,"reason":Text.MISSION1_COULD_NOT_PROMOTE_VOYAGE_JOURNAL}
 saved_content_version = str(run.authored_content.get("version", ""))
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
 return best if not best.is_empty() else {"ok":false,"reason":Text.MISSION1_NO_VALID_MISSION_1_JOURNAL}

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
  if not batch is Dictionary or not _valid_batch(batch, history.size(),latest.get("authored_content",{}),latest.get("content_versions",{})): break
  if not latest.is_empty() and (int(batch.sequence)<=int(latest.sequence) or int(batch.loop)!=int(latest.current.loop)): break
  history.append_array(batch.history)
  history[-1] = batch.current.duplicate(true)
  latest = {"current":batch.current, "memory":batch.memory, "sequence":batch.sequence,"authored_content":batch.get("authored_content",latest.get("authored_content",{})),"content_versions":batch.get("content_versions",latest.get("content_versions",{}))}
 file.close()
 if latest.is_empty(): return {}
 latest.history = history
 return {"ok":true,"data":latest,"source":path}

static func _valid_state(state: Variant, rooms: Dictionary = Rooms.ROOMS) -> bool:
 if not state is Dictionary: return false
 for field in ["message_ref","notice_ref"]:
  if state.has(field) and not Messages.valid(state[field]): return false
 if state.get("dialogue") is Dictionary:
  for field in ["text_ref","name_ref"]:
   if state.dialogue.has(field) and not Messages.valid(state.dialogue[field]): return false
 for key in ["tick","loop","room","pos","facing","code","flags","dead","safe","action","entry","code_open","dialogue","observed","message","finished","door_cooldown"]:
  if not state.has(key): return false
 if not rooms.has(state.room) or not state.pos is Array or state.pos.size()!=2: return false
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

static func _valid_batch(batch: Dictionary, count: int, prior_content: Dictionary = {}, prior_versions: Dictionary = {}) -> bool:
 if int(batch.get("schema",-1)) not in [2,3,4,SCHEMA] or int(batch.get("start",-1))!=count or not batch.get("history") is Array: return false
 var content: Variant = batch.get("authored_content",prior_content)
 if not content is Dictionary: return false
 if batch.has("authored_content") and not content.is_empty() and not preload("res://mission1/authoring_content.gd").validate(content).is_empty(): return false
 var rooms: Dictionary = content.get("rooms",Rooms.ROOMS)
 var recorded_rooms := rooms.duplicate()
 var versions: Variant = batch.get("content_versions",prior_versions)
 if not versions is Dictionary: return false
 for version in versions.values():
  if not version is Dictionary or not version.get("rooms") is Dictionary: return false
  recorded_rooms.merge(version.rooms,false)
 if not batch.get("content_versions",{}) is Dictionary: return false
 if not _valid_state(batch.get("current"),rooms) or not batch.get("memory") is Dictionary: return false
 var legacy: bool = batch.schema == 2
 if not legacy and not _valid_extension(batch.current): return false
 if int(batch.current.get("tick" if legacy else "frame",-1))!=count+batch.history.size()-1: return false
 for key in ["notes","bag","procedure","shortcut","reset","completed"]:
  if not batch.memory.has(key): return false
 if not batch.memory.notes is Array: return false
 if batch.memory.has("note_records"):
  if not batch.memory.note_records is Array or batch.memory.note_records.size() != batch.memory.notes.size(): return false
  for entry in batch.memory.note_records:
   if not entry is Dictionary: return false
   if entry.is_empty(): continue
   if not entry.get("fallback") is String or not (entry.get("tick") is int or entry.get("tick") is float) or not Messages.valid(entry.get("text_ref")): return false
 for i in batch.history.size():
  if not _valid_state(batch.history[i],recorded_rooms) or int(batch.history[i].get("tick" if legacy else "frame",-1))!=count+i: return false
  if not legacy and not _valid_extension(batch.history[i]): return false
 if legacy:
  for state in batch.history: _migrate_state(state)
  _migrate_state(batch.current)
 if not batch.memory.has("cabins"): batch.memory.cabins = []
 if not batch.memory.has("preferences"): batch.memory.preferences = []
 return batch.has("sequence") and batch.has("loop")

static func _migrate_state(state: Dictionary) -> void:
 state.frame = state.tick
 state.tutorial = "done"
 state.arrivals = false
 state.hospitality = {"carried":"","outcomes":{},"detours":{},"menu":""}

static func _valid_extension(state: Dictionary) -> bool:
 if not state.get("frame") is float and not state.get("frame") is int: return false
 if int(state.frame)<0 or state.get("tutorial") not in ["approach","briefing","done"]: return false
 if state.tutorial != "done" and int(state.tick)!=0: return false
 var duties: Variant = state.get("hospitality")
 if not duties is Dictionary: return false
 return duties.get("carried") in ["","lemonade","water","tea"] and duties.get("outcomes") is Dictionary and duties.get("detours") is Dictionary and duties.get("menu") is String
