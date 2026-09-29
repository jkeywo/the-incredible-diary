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


func show_at(state: Dictionary) -> void:
 var Rooms = preload("res://mission1/rooms.gd")
 position = Rooms.point(state.flags.get("glass_drop",[Rooms.BAR_GUEST.x+28,Rooms.BAR_GUEST.y+8])) if state.dead.has("guest") or state.flags.get("spilled",false) else Rooms.BAR_GLASS
 z_index = 0 if state.dead.has("guest") or state.flags.get("spilled",false) else 2
 var elapsed := int(state.frame)-int(state.flags.spike_frame) if state.flags.has("spike_frame") else int(state.tick)-int(state.flags.get("spike_tick",-100))
 var spiking: bool = state.flags.has("spike_tick") and elapsed >= 0 and elapsed < 7 and not state.flags.get("spilled",false)
 set_state("spilled" if state.flags.get("spilled",false) else "empty" if state.dead.has("guest") else "spiked" if state.flags.get("spiked",false) else "full")
 # The glass is picked up as the hand withdraws, before the original drink deadline.
 self_modulate.a = 1.0 if not state.flags.get("spiked",false) or spiking or state.dead.has("guest") or state.flags.get("spilled",false) else 0.0
 $SpikingHand.pause()
 $SpikingHand.animation = "effect"
 $SpikingHand.frame = mini(3,int(elapsed*0.6)) if spiking else 0
 $SpikingHand.visible = spiking
 var spill_age := int(state.frame)-int(state.flags.spill_frame) if state.flags.has("spill_frame") else int(state.tick)-int(state.flags.get("spill_tick",-100))
 $Splash.pause()
 $Splash.animation = "effect"
 $Splash.frame = mini(3,int(spill_age*0.8)) if spill_age >= 0 else 0
 $Splash.visible = state.flags.has("spill_tick") and spill_age >= 0 and spill_age < 5
