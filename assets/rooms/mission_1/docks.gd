@tool
extends Node2D
## Visual-only harbor motion. Keep the pier/stairs and gameplay coordinates fixed.
## Pause automatic motion and call set_motion_time() when showing recorded time.

const WATER_BASE := Vector2(-20.0, -13.0)
const SHIP_BASE := Vector2(-20.0, -90.0)

@export var animate_bobbing := true:
	set(value):
		animate_bobbing = value
		set_process(value)
@export var initial_motion_time := 0.0
@export_range(0.0, 8.0, 0.25) var ship_vertical_range := 5.0
@export_range(0.0, 8.0, 0.25) var ship_horizontal_range := 2.0
@export_range(0.0, 8.0, 0.25) var water_vertical_range := 2.0
@export_range(0.0, 8.0, 0.25) var water_horizontal_range := 3.0

@onready var water: Sprite2D = $Water
@onready var ship: Sprite2D = $Ship
var _motion_time := 0.0


func _ready() -> void:
	_motion_time = initial_motion_time
	set_process(animate_bobbing)
	_apply_motion()


func _process(delta: float) -> void:
	_motion_time += delta
	_apply_motion()


func set_motion_time(seconds: float) -> void:
	_motion_time = maxf(0.0, seconds)
	if is_node_ready():
		_apply_motion()


func _apply_motion() -> void:
	# Different periods keep the water from looking glued to the hull.
	var ship_phase := TAU * _motion_time / 5.2
	var water_phase := TAU * _motion_time / 7.4
	ship.position = SHIP_BASE + Vector2(
		sin(ship_phase + 0.35) * ship_horizontal_range,
		sin(ship_phase) * ship_vertical_range
	)
	water.position = WATER_BASE + Vector2(
		sin(water_phase + 1.1) * water_horizontal_range,
		sin(water_phase + 0.6) * water_vertical_range
	)
