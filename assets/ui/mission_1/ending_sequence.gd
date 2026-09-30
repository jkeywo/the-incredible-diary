extends Control
## A presentation-only camera cut; never write staged poses into voyage history.
const Rooms = preload("res://mission1/rooms.gd")
const Departure = preload("res://mission1/departure.gd")
const DEPARTURE_SECONDS := 6.0
const CANCELLED_SECONDS := 7.0
const CANCELLATION := "A passenger dead aboard my ship... I can't sail after this. The voyage will have to be cancelled!"
var state: Dictionary = {}
var elapsed := 0.0
var done := false
var departing := false
var victim := ""
var speech: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speech = preload("res://assets/ui/mission_1/speech_bubble.tscn").instantiate()
	speech.bubble_size = Vector2(430,174)
	add_child(speech)
	hide()

func start(final_state: Dictionary) -> void:
	state = final_state.duplicate(true)
	elapsed = 0.0
	done = false
	departing = state.dead.is_empty()
	victim = ""
	state.dialogue = {}
	state.action = {}
	state.code_open = false
	if departing:
		state.room = "docks"
		for id in state.actors:
			if str(id).begins_with("sendoff_guest_"):
				state.actors[id].action = "wave"
				state.actors[id].facing = "up"
	else:
		victim = Departure.victim(state.dead)
		state.room = Departure.room_for(victim)
		if not state.actors.has("captain"):
			# Compatibility for terminal saves made before the captain's arrival existed.
			var place := Departure.captain_target(state.actors[victim])
			state.actors.captain = {"room":state.room,"pos":[place.x,place.y]}
		state.actors.captain.action = "grief"
		state.actors.captain.facing = "down"
	show()
	present()

func active() -> bool:
	return not state.is_empty() and not done

func advance(delta: float) -> void:
	if not active(): return
	elapsed = minf(elapsed+delta,DEPARTURE_SECONDS if departing else CANCELLED_SECONDS)
	done = elapsed >= (DEPARTURE_SECONDS if departing else CANCELLED_SECONDS)
	visible = not done
	present()

func clear() -> void:
	state = {}
	done = false
	elapsed = 0.0
	hide()

func present() -> void:
	speech.visible = not departing
	if not departing:
		var feet := Rooms.point(state.actors.captain.pos)
		speech.position = Vector2(clampf(feet.x-215,20,710),maxf(52,feet.y-255))
		speech.present({"name":"Captain","text":CANCELLATION},maxf(0,elapsed-0.5))
		speech.point_tail_at(feet+Vector2(0,-45)-speech.position)
	queue_redraw()

func _draw() -> void:
	if not active(): return
	draw_rect(Rect2(0,0,1160,40),Color("101820"))
	draw_rect(Rect2(0,700,1160,40),Color("101820"))
	var caption := "5:30 — All aboard. Cast off!" if departing else "5:30 — The voyage is cancelled"
	draw_string(ThemeDB.fallback_font,Vector2(0,727),caption,HORIZONTAL_ALIGNMENT_CENTER,1160,19,Color("f4dfb4"))
