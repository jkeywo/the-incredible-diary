extends AudioStreamPlayer
## Uses listening time: pauses stop both the clip and the gap between clips.

var sequence: Resource
var clip_index := -1
var gap_remaining := -1.0
var active := true
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	finished.connect(_on_finished)
	set_process(false)


func start_sequence(config: Resource) -> void:
	sequence = config
	active = true
	clip_index = -1
	if sequence.clips.is_empty():
		return
	if sequence.delay_first_clip:
		_on_finished()
	else:
		_play_next()


func _process(delta: float) -> void:
	if not active or gap_remaining < 0.0:
		return
	gap_remaining -= delta
	if gap_remaining <= 0.0:
		_play_next()


func retire() -> void:
	# Let the current clip fade out, but never start another outgoing clip.
	active = false
	set_process(false)


func _on_finished() -> void:
	if not active:
		return
	gap_remaining = rng.randf_range(sequence.gap_min_seconds, maxf(sequence.gap_min_seconds, sequence.gap_max_seconds))
	set_process(true)


func _play_next() -> void:
	if not active:
		return
	var count: int = sequence.clips.size()
	if sequence.random_order:
		# Avoid an immediate repeat when there is more than one effect.
		var next := rng.randi_range(0, count - 2) if count > 1 and clip_index >= 0 else rng.randi_range(0, count - 1)
		if count > 1 and clip_index >= 0 and next >= clip_index:
			next += 1
		clip_index = next
	else:
		clip_index = (clip_index + 1) % count
	stream = sequence.clips[clip_index].duplicate(true)
	if stream is AudioStreamMP3:
		stream.loop = false
	elif stream is AudioStreamOggVorbis:
		stream.loop = false
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	gap_remaining = -1.0
	set_process(false)
	play()
