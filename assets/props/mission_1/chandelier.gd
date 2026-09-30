@tool
extends "res://assets/props/mission_1/stateful_prop.gd"
const Depth = preload("res://mission1/render_depth.gd")
## The origin stays on the floor; the intact fixture falls from overhead.
const HANG_HEIGHT := 150.0
var accents: Node2D

func _ready() -> void:
 super._ready()
 accents = preload("res://assets/effects/mission_1/physical_accents.gd").new()
 add_child(accents)
 show_at(false,-1.0,-1.0,0.0)

func show_at(warning: bool, progress: float, impact_seconds: float, time: float) -> void:
 var landed := impact_seconds >= 0.0
 var next := "fallen" if landed else "warning" if warning else "intact"
 if current_state != next: super.set_state(next)
 # Gravity accelerates the whole fixture downwards. Do not squash its sprite.
 var fraction := clampf(progress,0.0,1.0)
 offset = Vector2(-cell_size.x*0.5,-cell_size.y-HANG_HEIGHT*(1.0-fraction*fraction))
 if landed: offset.y = -cell_size.y
 scale = Vector2.ONE
 rotation = sin(time*16.0)*0.018 if warning and progress<0.0 else 0.0
 Depth.assign(self,Depth.ENTITY if landed else Depth.OVERHEAD,true)
 var dust: AnimatedSprite2D = $Dust
 dust.pause()
 dust.visible = landed and impact_seconds < 0.8
 dust.scale = Vector2(1.0+maxf(impact_seconds,0.0)*0.7,1.0)
 dust.modulate.a = clampf(1.0-impact_seconds/0.8,0.0,1.0)
 if dust.visible: dust.frame = mini(dust.frame_count-1,int(impact_seconds/0.8*dust.frame_count))
 if is_instance_valid(accents): accents.show_at("impact",impact_seconds)
