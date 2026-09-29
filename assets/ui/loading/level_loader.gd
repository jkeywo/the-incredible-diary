extends Node
signal prepared
signal failed(message: String)
const MISSION := "res://mission1/play.tscn"
const Plan = preload("res://mission1/content_plan.gd")
var is_prepared := false
var error := ""
var progress := 0.0
var resources: Dictionary = {}
var ticket: Dictionary = {}
var character_ticket: Dictionary = {}
var neighbour_ticket: Dictionary = {}
var requested_scene := ""
var requested_state: Dictionary = {}

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 resources = get_node("/root/ResourceStream").resources
 set_process(false)

func start(scene_path: String = MISSION, state: Dictionary = {}, foreground := false) -> void:
 if state.is_empty(): state = Plan.Sim.new().s
 if scene_path == requested_scene and state == requested_state and error.is_empty() and not ticket.is_empty():
  ticket.foreground = foreground or ticket.foreground
  return
 requested_scene = scene_path
 if not ticket.is_empty(): ticket.cancelled = true
 requested_state = state.duplicate(true)
 is_prepared = false
 error = ""
 var paths := Plan.for_state(state)
 paths.append(scene_path)
 if scene_path != MISSION:
  # The authoring test scene is a separate explicit destination.
  _test_assets("res://assets",paths)
 ticket = get_node("/root/ResourceStream").request_resources(paths,foreground)
 if not neighbour_ticket.is_empty(): neighbour_ticket.cancelled = true
 if scene_path == MISSION:
  neighbour_ticket = get_node("/root/ResourceStream").request_resources(Plan.neighbours(str(state.room)))
 if scene_path == MISSION and character_ticket.is_empty():
  character_ticket = get_node("/root/ResourceStream").request_resources(Plan.level_characters(),false,2)
 progress = ticket.progress
 set_process(true)

func _test_assets(directory: String, paths: Array) -> void:
 for name in ResourceLoader.list_directory(directory):
  var path := directory.path_join(name)
  if name.ends_with("/"): _test_assets(path.trim_suffix("/"),paths)
  elif name.get_extension() in ["png","wav","ogg","mp3","tscn","tres"]: paths.append(path)

func _process(_delta: float) -> void:
 progress = ticket.progress
 if not ticket.done: return
 set_process(false)
 error = ticket.error
 if not error.is_empty(): failed.emit(error)
 else:
  is_prepared = true
  prepared.emit()

func _exit_tree() -> void:
 if not ticket.is_empty(): ticket.cancelled = true
 if not character_ticket.is_empty(): character_ticket.cancelled = true
 if not neighbour_ticket.is_empty(): neighbour_ticket.cancelled = true
