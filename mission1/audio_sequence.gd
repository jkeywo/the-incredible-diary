extends Resource
## A shared room playlist, or a pool of occasional background effects.

@export var clips: Array[AudioStream] = []
@export var random_order := false
@export_range(0.0, 60.0, 0.5) var gap_min_seconds := 5.0
@export_range(0.0, 60.0, 0.5) var gap_max_seconds := 20.0
@export var delay_first_clip := false
