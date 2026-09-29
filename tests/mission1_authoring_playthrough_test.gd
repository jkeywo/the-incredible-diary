extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Content = preload("res://mission1/authoring_content.gd")
func _initialize() -> void:
	var run := Sim.new(false)
	var data := Content.seed(run.s.actors)
	var applied := run.apply_authored(data)
	if not applied.ok: push_error(applied.reason); quit(1); return
	var started := Time.get_ticks_msec()
	for i in 5600:
		run.step()
		if run.s.finished: break
	assert(run.s.finished and run.s.flags.get("chandelier_fallen",false) and run.s.flags.get("trapped",false))
	assert(run.s.dead.has("chandelier_guest") and run.s.dead.has("chatterbox"))
	assert(run.history[0].tick == 0 and run.history[-1].frame == run.history.size()-1)
	print("MISSION1 AUTHORING PLAYTHROUGH PASS: whole leg, hazards, recorded frames (%d ms)" % (Time.get_ticks_msec()-started))
	quit()
