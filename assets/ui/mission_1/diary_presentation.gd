extends Node
## Presentation can finish while the owner keeps voyage time paused.
signal closed
var target: Control
var phase := "closed"
var amount := 0.0
var wanted := false

func setup(control: Control) -> void:
	target = control
	apply()

func set_open(value: bool) -> void:
	wanted = value
	phase = "opening" if value else "closing"
	apply()

func clear() -> void:
	wanted = false
	amount = 0.0
	phase = "closed"
	apply()

func advance(delta: float) -> void:
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
