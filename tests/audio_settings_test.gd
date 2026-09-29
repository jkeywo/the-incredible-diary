extends SceneTree

const RoomAudio = preload("res://mission1/room_audio.gd")
const EventAudio = preload("res://mission1/event_audio.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)

func run_checks() -> void:
	var settings := root.get_node("AudioSettings")
	settings.settings_path = "res://build/audio-settings-test.cfg"
	DirAccess.remove_absolute(settings.settings_path)
	settings.load_settings()
	check(settings.volumes.Master == 50.0, "Master defaults to 50%")
	for bus in ["SFX", "Dialogue", "Music"]:
		check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) == &"Master", "Category feeds Master")
	settings.set_volume("SFX", 0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "Zero mutes SFX")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "SFX leaves music unmuted")
	settings.set_volume("Dialogue", 23)
	settings.save_settings()
	settings.set_volume("Dialogue", 100)
	settings.load_settings()
	check(settings.volumes.Dialogue == 23.0, "Dialogue preference survives reload")
	settings.open_settings()
	check(paused and settings.dialog.visible, "Settings pauses gameplay and opens")
	settings.sliders.Music.value = 37
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.37), "Slider controls its bus")
	settings.close_settings()
	check(not paused, "Settings restores running state")
	paused = true
	settings.open_settings()
	settings.close_settings()
	check(paused, "Settings preserves existing pause")
	paused = false
	var room := preload("res://assets/rooms/mission_1/04_controls_and_steam.tscn").instantiate()
	root.add_child(room)
	var audio := RoomAudio.new()
	root.add_child(audio)
	audio.set_room(room.get_node("RoomAudioSettings"), 3500, 0.1)
	check(audio._players.ambience.bus == &"SFX" and audio._hiss_player.bus == &"SFX", "Ambience and hiss route to SFX")
	var foyer := preload("res://assets/rooms/mission_1/02_foyer.tscn").instantiate()
	root.add_child(foyer)
	audio.set_room(foyer.get_node("RoomAudioSettings"), 0, 0.1)
	check(audio._players.music.bus == &"Music", "Music routes to Music")
	var cues := EventAudio.new()
	root.add_child(cues)
	check(cues.play_cue(&"baggage_move").bus == &"SFX", "One-shots route to SFX")
	room.queue_free()
	foyer.queue_free()
	audio.queue_free()
	cues.queue_free()
	await process_frame
	DirAccess.remove_absolute(settings.settings_path)
	print("AUDIO SETTINGS %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
