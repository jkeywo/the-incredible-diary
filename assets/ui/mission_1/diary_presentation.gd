extends Node
## Presentation can finish while the owner keeps voyage time paused.
signal closed
var target: Control
var phase := "closed"
var amount := 0.0
var wanted := false
var page_flip: Control

func setup(control: Control) -> void:
	target = control
	page_flip = preload("res://assets/ui/mission_1/diary_page_flip.gd").new()
	target.add_child(page_flip)
	apply()

func turn_page(direction: int) -> void:
	page_flip.turn(direction)

func set_open(value: bool) -> void:
	wanted = value
	phase = "opening" if value else "closing"
	apply()

func clear() -> void:
	wanted = false
	page_flip.elapsed = page_flip.DURATION
	page_flip.queue_redraw()
	amount = 0.0
	phase = "closed"
	apply()

func advance(delta: float) -> void:
	page_flip.advance(delta)
	if phase not in ["opening","closing"]: return
	amount = move_toward(amount,1.0 if wanted else 0.0,delta/(0.18 if wanted else 0.12))
	if amount == 1.0: phase = "open"
	elif amount == 0.0:
		phase = "closed"
		closed.emit()
	apply()

func apply() -> void:
	if not is_instance_valid(target): return
	target.visible = phase != "closed"
	target.modulate.a = amount
	target.position.y = 6.0 * (1.0-amount)
