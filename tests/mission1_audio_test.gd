extends SceneTree

const RoomAudio = preload("res://mission1/room_audio.gd")
const FOYER = preload("res://assets/rooms/mission_1/02_foyer.tscn")
const CABINS = preload("res://assets/rooms/mission_1/03_cabin_corridor.tscn")
const STEAM = preload("res://assets/rooms/mission_1/04_controls_and_steam.tscn")
const SALON = preload("res://assets/rooms/mission_1/05_party_salon.tscn")
const GEORGE = preload("res://assets/audio/mission_1/music/george_street_shuffle.mp3")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://mission1/room_audio_playtest.tscn")
	var playtest := scene.instantiate()
	root.add_child(playtest)
	await process_frame
	var audio: RoomAudio = playtest.get_node("RoomAudio")
	_check(is_equal_approx(RoomAudio.offset_seconds(61500, 20.0), 1.5), "offset wraps game time")
	_check(RoomAudio.offset_seconds(61500, 0.0) == 0.0, "zero-length stream offset")
	_check(audio._players.has("ambience") and audio._players.has("secondary_ambience"), "dock beds configured")
	var foyer := FOYER.instantiate()
	root.add_child(foyer)
	audio.set_room(foyer.get_node("RoomAudioSettings"), 10_000)
	var piano: AudioStreamPlayer = audio._players.get("music")
	_check(piano != null, "foyer music configured")
	var cabins := CABINS.instantiate()
	root.add_child(cabins)
	audio.set_room(cabins.get_node("RoomAudioSettings"), 15_000)
	_check(audio._players.get("music") == piano, "shared piano continues across rooms")
	var steam := STEAM.instantiate()
	root.add_child(steam)
	audio.set_room(steam.get_node("RoomAudioSettings"), 3_500)
	_check(audio._players.has("ambience") and audio._hiss_player != null and audio._hiss_player.playing, "steam hum and scheduled hiss")
	var salon := SALON.instantiate()
	root.add_child(salon)
	audio.set_room(salon.get_node("RoomAudioSettings"), 61_500)
	var swing: AudioStreamPlayer = audio._players.get("music")
	var expected := RoomAudio.offset_seconds(61_500, swing.stream.get_length())
	_check(absf(swing.get_playback_position() - expected) < 0.15, "salon starts at elapsed game-time phase")
	await create_timer(0.8).timeout
	_check(not is_instance_valid(piano) and absf(swing.volume_db - float(salon.get_node("RoomAudioSettings").music_volume_db)) < 0.5, "changed music crossfades")
	audio.set_room(foyer.get_node("RoomAudioSettings"), 90_000)
	audio.set_room(salon.get_node("RoomAudioSettings"), 120_000)
	var returned: AudioStreamPlayer = audio._players.get("music")
	var return_offset := RoomAudio.offset_seconds(120_000, returned.stream.get_length())
	_check(absf(returned.get_playback_position() - return_offset) < 0.15, "salon re-entry uses elapsed game-time phase")
	salon.get_node("RoomAudioSettings").set("music", GEORGE)
	audio.set_room(salon.get_node("RoomAudioSettings"), 200_000)
	returned = audio._players.get("music")
	var george_offset := RoomAudio.offset_seconds(200_000, returned.stream.get_length())
	_check(absf(returned.get_playback_position() - george_offset) < 0.15, "alternate salon track starts at game-time phase")
	var before: int = playtest.elapsed_ms
	var before_position := returned.get_playback_position()
	paused = true
	await process_frame
	await process_frame
	_check(playtest.elapsed_ms == before and absf(returned.get_playback_position() - before_position) < 0.05, "game clock and music pause together")
	paused = false
	playtest.queue_free()
	foyer.queue_free()
	cabins.queue_free()
	steam.queue_free()
	salon.queue_free()
	await process_frame
	print("MISSION1_AUDIO_RESULT {\"passed\":%s}" % ["false" if _failed else "true"])
	quit(1 if _failed else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("Mission 1 audio test failed: " + label)
		_failed = true
