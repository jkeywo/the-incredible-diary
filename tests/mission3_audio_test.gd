extends SceneTree

const Audio = preload("res://mission1/room_audio.gd")
const Sequence = preload("res://mission1/audio_sequence.gd")
const Player = preload("res://mission1/audio_sequence_player.gd")
const Dock = preload("res://assets/rooms/mission_3/greek_docks.tscn")
const Restaurant = preload("res://assets/rooms/mission_3/restaurant.tscn")
const Market = preload("res://assets/rooms/mission_3/market.tscn")
const Foyer = preload("res://assets/rooms/mission_1/02_foyer.tscn")


func _initialize() -> void:
	call_deferred("checks")


func checks() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	var rooms: Array[Node] = [Dock.instantiate(), Restaurant.instantiate(), Market.instantiate(), Foyer.instantiate()]
	for room in rooms: root.add_child(room)
	var dock = rooms[0].get_node("RoomAudioSettings")
	var restaurant = rooms[1].get_node("RoomAudioSettings")
	var market = rooms[2].get_node("RoomAudioSettings")
	var foyer = rooms[3].get_node("RoomAudioSettings")
	audio.set_presentation_gain(0.5)
	audio.set_room(dock, 0, 0.0)
	var music = audio._players.music
	assert(music is Player and music.clip_index == 0 and music.playing)
	assert(is_equal_approx(music.volume_linear, db_to_linear(dock.music_volume_db)*0.5))
	assert(music.sequence.clips.size() == 5)
	for index in 5:
		assert(music.sequence.clips[index].resource_path.ends_with("greece_vol_%d.mp3" % (index+1)))
	assert(audio._players.has("ambience") and audio._players.has("secondary_ambience"))
	audio.set_room(restaurant, 8000, 0.0)
	assert(audio._players.music == music and music.clip_index == 0)
	assert(audio._players.ambience.get_meta("source_path").ends_with("restaurant_walla.ogg"))
	var kitchen = audio._players.random_ambience
	assert(not kitchen.playing and kitchen.gap_remaining >= 3.0 and kitchen.gap_remaining <= 9.0)
	var chosen := {}
	var previous := -1
	kitchen.rng.seed = 1234
	for index in 30:
		kitchen._process(kitchen.gap_remaining + 0.01)
		assert(kitchen.playing and kitchen.clip_index != previous)
		assert(not kitchen.stream.loop)
		previous = kitchen.clip_index
		chosen[previous] = true
		kitchen.stop()
		kitchen.finished.emit()
	assert(chosen.size() == 5)
	# A completed clip starts a silent, bounded gap. Room changes retain it.
	music.stop()
	music.finished.emit()
	var gap: float = music.gap_remaining
	assert(gap >= 5.0 and gap <= 20.0 and not music.playing)
	audio.set_room(market, 9000, 0.0)
	assert(audio._players.music == music and music.gap_remaining == gap)
	assert(not kitchen.active and not audio._players.has("random_ambience"))
	assert(audio._players.ambience.get_meta("source_path").ends_with("market_walla.ogg"))
	paused = true
	await create_timer(0.1, true).timeout
	assert(music.gap_remaining == gap and not music.playing)
	paused = false
	# Complete two whole passes, including a random gap after volume five.
	var gaps := {}
	for index in 10:
		gaps[music.gap_remaining] = true
		music._process(music.gap_remaining - 0.01)
		assert(not music.playing)
		music._process(0.02)
		assert(music.clip_index == (index+1)%5 and music.playing and not music.stream.loop)
		music.stop()
		music.finished.emit()
		assert(music.gap_remaining >= 5.0 and music.gap_remaining <= 20.0)
	assert(gaps.size() > 1)
	# Leaving the shore retires its sequence even during a silent gap.
	audio.set_room(foyer, 10000, 0.1)
	assert(not music.active and not music.is_processing())
	assert(not audio._players.music is Player)
	await create_timer(0.2).timeout
	assert(not is_instance_valid(music))
	# Real stream completion drives the next clip (not just mocked signals).
	var short_clip := AudioStreamWAV.new()
	short_clip.mix_rate = 8000
	short_clip.data = PackedByteArray()
	var samples := PackedByteArray()
	samples.resize(400)
	short_clip.data = samples
	var quick := Sequence.new()
	quick.clips = [short_clip, short_clip]
	quick.gap_min_seconds = 0.05
	quick.gap_max_seconds = 0.05
	var player := Player.new()
	root.add_child(player)
	player.start_sequence(quick)
	await player.finished
	assert(player.gap_remaining >= 0.0)
	await create_timer(0.07).timeout
	assert(player.clip_index == 1)
	player.queue_free()
	audio.queue_free()
	for room in rooms: room.queue_free()
	await process_frame
	print("MISSION3 AUDIO PASS: ordered playlist, random gaps, shared rooms, kitchen pool, pause and completion")
	await preload("res://tests/shutdown.gd").finish(self)
