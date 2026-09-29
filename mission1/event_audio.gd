extends Node
## One-shot Mission 1 sound cues. Add this node to a gameplay scene and call
## play_cue(&"baggage_move"), etc. Players pause with the scene tree.

const CUES := {
 &"hour_chime": [preload("res://assets/audio/mission_1/sfx/hour_chime.wav")],
	&"footstep_dock": [preload("res://assets/audio/mission_1/sfx/footstep_dock_01.wav"), preload("res://assets/audio/mission_1/sfx/footstep_dock_02.wav")],
	&"footstep_wood": [preload("res://assets/audio/mission_1/sfx/footstep_wood_01.wav"), preload("res://assets/audio/mission_1/sfx/footstep_wood_02.wav"), preload("res://assets/audio/mission_1/sfx/footstep_wood_03.wav"), preload("res://assets/audio/mission_1/sfx/footstep_wood_04.wav")],
	&"baggage_rustle": [preload("res://assets/audio/mission_1/sfx/baggage_rustle.wav")],
	&"baggage_move": [preload("res://assets/audio/mission_1/sfx/baggage_move.wav")],
	&"baggage_set_down": [preload("res://assets/audio/mission_1/sfx/baggage_set_down.wav")],
	&"cabin_door_open": [preload("res://assets/audio/mission_1/sfx/cabin_door_open.wav")],
	&"cabin_door_close": [preload("res://assets/audio/mission_1/sfx/cabin_door_close.wav")],
	&"service_door_open": [preload("res://assets/audio/mission_1/sfx/service_door_open.wav")],
	&"service_door_close": [preload("res://assets/audio/mission_1/sfx/service_door_close.wav")],
	&"control_button": [preload("res://assets/audio/mission_1/sfx/control_button.wav")],
	&"control_switch": [preload("res://assets/audio/mission_1/sfx/control_switch.wav")],
	&"steam_valve": [preload("res://assets/audio/mission_1/sfx/steam_valve.wav")],
	&"steam_hiss": [preload("res://assets/audio/mission_1/ambience/steam_hiss_01.wav"), preload("res://assets/audio/mission_1/ambience/steam_hiss_03.wav")],
	&"chandelier_creak": [preload("res://assets/audio/mission_1/sfx/chandelier_creak.wav")],
	&"chandelier_impact": [preload("res://assets/audio/mission_1/sfx/chandelier_impact.wav")],
	&"chandelier_glass": [preload("res://assets/audio/mission_1/sfx/chandelier_glass.wav")],
	&"shove": [preload("res://assets/audio/mission_1/sfx/shove_soft.wav")],
	&"drink_spill": [preload("res://assets/audio/mission_1/sfx/drink_spill_soft.wav")],
	&"steam_cough": [preload("res://assets/audio/mission_1/sfx/steam_cough.wav")],
	&"crew_alarm": [preload("res://assets/audio/mission_1/sfx/crew_alarm_placeholder.wav")],
}

const CUE_VOLUME_DB := {
	&"footstep_dock": -5.0,
	&"footstep_wood": -5.0,
	&"baggage_rustle": -3.0,
	&"baggage_move": -6.0,
	&"baggage_set_down": -7.0,
	&"chandelier_creak": -6.0,
	&"shove": -6.0,
	&"drink_spill": -5.0,
	&"steam_cough": -3.0,
}

var _next_variant: Dictionary = {}


func play_cue(cue: StringName) -> AudioStreamPlayer:
	if not CUES.has(cue):
		push_warning("Unknown Mission 1 sound cue: %s" % cue)
		return null
	var variants: Array = CUES[cue]
	var index: int = _next_variant.get(cue, 0)
	_next_variant[cue] = (index + 1) % variants.size()
	var player := AudioStreamPlayer.new()
	player.name = "Cue_%s" % cue
	player.bus = &"SFX"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.stream = variants[index]
	player.volume_db = CUE_VOLUME_DB.get(cue, -4.0)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player
