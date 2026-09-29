extends SceneTree
const Watch = preload("res://mission1/pocket_watch.gd")
func _initialize() -> void:
	assert(Watch.hand_angles(0).is_equal_approx(Vector2(PI / 6 - PI / 2, -PI / 2)))
	assert(is_equal_approx(Watch.hand_angles(90).y, PI / 2))
	assert(is_equal_approx(Watch.hand_angles(180).x, PI / 3 - PI / 2))
	assert(is_equal_approx(Watch.hand_angles(1080).x, 7 * PI / 6 - PI / 2))
	print("POCKET_WATCH PASS: continuous hour/minute hands and full six Hours")
	quit()
