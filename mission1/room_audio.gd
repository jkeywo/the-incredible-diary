extends Node
## Room beds follow elapsed game time, including time spent in other rooms.

const Settings = preload("res://mission1/room_audio_settings.gd")

var _players: Dictionary = {}
var _hiss_player: AudioStreamPlayer
var _intermittent_clips: Array[AudioStream] = []
var _intermittent_interval := 14.0
var _hiss_cycle := -1


func set_room(settings: Node, elapsed_ms: int, opening_fade_override_seconds: float = -1.0) -> void:
	assert(settings is Settings)
	var fade: float = opening_fade_override_seconds if opening_fade_override_seconds >= 0.0 else settings.fade_seconds
	_set_bed("music", settings.music, settings.music_volume_db, fade, elapsed_ms)
	_set_bed("ambience", settings.ambience, settings.ambience_volume_db, fade, elapsed_ms)
	_set_bed("secondary_ambience", settings.secondary_ambience, settings.secondary_ambience_volume_db, fade, elapsed_ms)
	_set_intermittent(settings, elapsed_ms, fade)


func set_game_time(elapsed_ms: int) -> void:
	if _hiss_player == null or _intermittent_clips.is_empty():
		return
	# Three quiet seconds before the first release; afterwards clips repeat in a
	# fixed sequence on the same game-time clock as music and room ambience.
	var seconds := float(elapsed_ms) / 1000.0 - 3.0
	if seconds < 0.0:
		_hiss_player.stop()
		return
	var cycle := floori(seconds / _intermittent_interval)
	var phase := fposmod(seconds, _intermittent_interval)
	var clip: AudioStream = _intermittent_clips[posmod(cycle, _intermittent_clips.size())]
	if phase >= clip.get_length():
		_hiss_player.stop()
		_hiss_cycle = -1
	elif _hiss_cycle != cycle or not _hiss_player.playing:
		_hiss_player.stream = clip
		_hiss_player.play(phase)
		_hiss_cycle = cycle


func _set_intermittent(settings: Node, elapsed_ms: int, fade: float) -> void:
	if _hiss_player != null:
		var old := _hiss_player
		_hiss_player = null
		if fade <= 0.0:
			old.queue_free()
		else:
			var outgoing := create_tween()
			outgoing.tween_property(old, "volume_db", -80.0, fade)
			outgoing.tween_callback(old.queue_free)
	_intermittent_clips = settings.intermittent_ambience.duplicate()
	_hiss_cycle = -1
	if _intermittent_clips.is_empty():
		return
	_intermittent_interval = settings.intermittent_interval_seconds
	_hiss_player = AudioStreamPlayer.new()
	_hiss_player.name = "IntermittentAmbience"
	_hiss_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_hiss_player.volume_db = -80.0 if fade > 0.0 else settings.intermittent_volume_db
	add_child(_hiss_player)
	set_game_time(elapsed_ms)
	if fade > 0.0:
		var incoming := create_tween()
		incoming.tween_property(_hiss_player, "volume_db", settings.intermittent_volume_db, fade)


func _set_bed(slot: String, source: AudioStream, target_db: float, fade: float, elapsed_ms: int) -> void:
	var current: AudioStreamPlayer = _players.get(slot)
	if current != null and source != null and current.get_meta("source_path") == source.resource_path:
		if not is_equal_approx(current.volume_db, target_db):
			_stop_fade(current)
			if fade <= 0.0:
				current.volume_db = target_db
			else:
				var volume_tween := create_tween()
				volume_tween.tween_property(current, "volume_db", target_db, fade)
				current.set_meta("fade_tween", volume_tween)
		return
	if current != null:
		_players.erase(slot)
		_stop_fade(current)
		if fade <= 0.0:
			current.queue_free()
		else:
			var outgoing := create_tween()
			outgoing.tween_property(current, "volume_db", -80.0, fade)
			outgoing.tween_callback(current.queue_free)
			current.set_meta("fade_tween", outgoing)
	if source == null:
		return
	var player := AudioStreamPlayer.new()
	player.name = slot.capitalize() + "Bed"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.stream = _looping_copy(source)
	player.volume_db = -80.0 if fade > 0.0 else target_db
	player.set_meta("source_path", source.resource_path)
	add_child(player)
	_players[slot] = player
	player.play(offset_seconds(elapsed_ms, player.stream.get_length()))
	if fade > 0.0:
		var incoming := create_tween()
		incoming.tween_property(player, "volume_db", target_db, fade)
		player.set_meta("fade_tween", incoming)


func _stop_fade(player: AudioStreamPlayer) -> void:
	var tween: Tween = player.get_meta("fade_tween", null)
	if tween != null and tween.is_running():
		tween.kill()


static func offset_seconds(elapsed_ms: int, length_seconds: float) -> float:
	if length_seconds <= 0.0:
		return 0.0
	return fposmod(maxf(0.0, float(elapsed_ms) / 1000.0), length_seconds)


static func _looping_copy(source: AudioStream) -> AudioStream:
	var copy := source.duplicate(true) as AudioStream
	if copy is AudioStreamMP3:
		(copy as AudioStreamMP3).loop = true
	elif copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = true
	elif copy is AudioStreamWAV:
		(copy as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return copy
