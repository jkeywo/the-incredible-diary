@tool
extends "res://assets/props/mission_1/stateful_prop.gd"

var _fall_tween: Tween


func set_state(next_state: String) -> bool:
	if _fall_tween != null and _fall_tween.is_running():
		_fall_tween.kill()
	rotation_degrees = 0.0
	scale = Vector2.ONE
	var result: bool = super.set_state(next_state)
	if is_node_ready():
		$Dust.call("stop_effect")
	return result


func play_fall() -> void:
	if current_state == "fallen":
		return
	set_state("warning")
	_fall_tween = create_tween()
	_fall_tween.tween_property(self, "rotation_degrees", -3.0, 0.08)
	_fall_tween.tween_property(self, "rotation_degrees", 3.0, 0.08)
	_fall_tween.tween_property(self, "scale", Vector2(1.05, 0.25), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_fall_tween.finished.connect(_finish_fall)


func _finish_fall() -> void:
	set_state("fallen")
	$Dust.call("play_effect")
