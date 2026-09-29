extends Node
## Room beds follow elapsed game time, including time spent in other rooms.

const Settings = preload("res://mission1/room_audio_settings.gd")

var presentation_gain := 1.0
var _gain_tween: Tween
var _players: Dictionary = {}
var _hiss_player: AudioStreamPlayer
var _intermittent_clips: Array[AudioStream] = []
var _intermittent_interval := 14.0
var _hiss_cycle := -1


func set_presentation_gain(value: float) -> void:
	presentation_gain = clampf(value,0.0,1.0)
	for child in get_children():
		if child is AudioStreamPlayer:
			_set_level(float(child.get_meta("level_db",child.volume_db)),child)


func fade_presentation_gain(target: float, seconds: float) -> void:
	if _gain_tween != null: _gain_tween.kill()
	if seconds <= 0.0:
		set_presentation_gain(target)
		return
	_gain_tween = create_tween()
	_gain_tween.tween_method(set_presentation_gain,presentation_gain,target,seconds)


func _set_level(db: float, player: AudioStreamPlayer) -> void:
	player.set_meta("level_db",db)
	player.volume_linear = db_to_linear(db)*presentation_gain


func _set_linear_level(value: float, player: AudioStreamPlayer) -> void:
	_set_level(linear_to_db(maxf(value,0.0001)),player)


func _fade_level(player: AudioStreamPlayer, db: float, seconds: float) -> Tween:
	var tween := create_tween()
	tween.tween_method(_set_linear_level.bind(player),db_to_linear(float(player.get_meta("level_db",player.volume_db))),db_to_linear(db),seconds)
	player.set_meta("fade_tween",tween)
	return tween


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
	if _hiss_player != null and _intermittent_clips == settings.intermittent_ambience and is_equal_approx(_intermittent_interval,settings.intermittent_interval_seconds):
		if not is_equal_approx(float(_hiss_player.get_meta("level_db")),settings.intermittent_volume_db):
			_stop_fade(_hiss_player)
			if fade <= 0.0: _set_level(settings.intermittent_volume_db,_hiss_player)
			else: _fade_level(_hiss_player,settings.intermittent_volume_db,fade)
		return
	if _hiss_player != null:
		var old := _hiss_player
		_stop_fade(old)
		_hiss_player = null
		if fade <= 0.0:
			old.queue_free()
		else:
			var outgoing := _fade_level(old,-80.0,fade)
			outgoing.tween_callback(old.queue_free)
	_intermittent_clips = settings.intermittent_ambience.duplicate()
	_hiss_cycle = -1
	if _intermittent_clips.is_empty():
		return
	_intermittent_interval = settings.intermittent_interval_seconds
	_hiss_player = AudioStreamPlayer.new()
	_hiss_player.name = "IntermittentAmbience"
	_hiss_player.bus = &"SFX"
	_hiss_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_set_level(-80.0 if fade > 0.0 else settings.intermittent_volume_db,_hiss_player)
	add_child(_hiss_player)
	set_game_time(elapsed_ms)
	if fade > 0.0:
		_fade_level(_hiss_player,settings.intermittent_volume_db,fade)


func _set_bed(slot: String, source: AudioStream, target_db: float, fade: float, elapsed_ms: int) -> void:
	var current: AudioStreamPlayer = _players.get(slot)
	if current != null and source != null and current.get_meta("source_path") == source.resource_path:
		if not is_equal_approx(float(current.get_meta("level_db",current.volume_db)), target_db):
			_stop_fade(current)
			if fade <= 0.0:
				_set_level(target_db,current)
			else:
				_fade_level(current,target_db,fade)
		return
	if current != null:
		_players.erase(slot)
		_stop_fade(current)
		if fade <= 0.0:
			current.queue_free()
		else:
			var outgoing := _fade_level(current,-80.0,fade)
			outgoing.tween_callback(current.queue_free)
			current.set_meta("fade_tween", outgoing)
	if source == null:
		return
	var player := AudioStreamPlayer.new()
	player.name = slot.capitalize() + "Bed"
	player.bus = &"Music" if slot == "music" else &"SFX"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.stream = _looping_copy(source)
	_set_level(-80.0 if fade > 0.0 else target_db,player)
	player.set_meta("source_path", source.resource_path)
	add_child(player)
	_players[slot] = player
	player.play(offset_seconds(elapsed_ms, player.stream.get_length()))
	if fade > 0.0:
		_fade_level(player,target_db,fade)


func _stop_fade(player: AudioStreamPlayer) -> void:
	var tween: Tween = player.get_meta("fade_tween") if player.has_meta("fade_tween") else null
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
