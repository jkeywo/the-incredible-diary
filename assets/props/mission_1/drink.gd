@tool
extends "res://assets/props/mission_1/stateful_prop.gd"


func play_spiking() -> void:
	if current_state == "full":
		$SpikingHand.call("play_effect")


func play_spill() -> void:
	if set_state("spilled"):
		$SpikingHand.call("stop_effect")
		$Splash.call("play_effect")


func _on_spiking_finished() -> void:
	if current_state == "full":
		set_state("spiked")
