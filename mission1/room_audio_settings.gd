extends Node
## Edit these streams on each room's RoomAudioSettings node.

@export var music: AudioStream
@export_range(-60.0, 0.0, 0.5) var music_volume_db := -16.0
@export var ambience: AudioStream
@export_range(-60.0, 0.0, 0.5) var ambience_volume_db := -18.0
@export var secondary_ambience: AudioStream
@export_range(-60.0, 0.0, 0.5) var secondary_ambience_volume_db := -25.0
@export var intermittent_ambience: Array[AudioStream] = []
@export_range(-60.0, 0.0, 0.5) var intermittent_volume_db := -28.0
@export_range(2.0, 60.0, 0.5) var intermittent_interval_seconds := 14.0
@export_range(0.0, 3.0, 0.05) var fade_seconds := 0.7
