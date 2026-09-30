extends RefCounted
## Retire test scenes before shutting down the audio mixer.
static func finish(tree: SceneTree, exit_code := 0) -> void:
	tree.paused = false
	var children := tree.root.get_children()
	children.reverse()
	for child in children:
		child.queue_free()
	await tree.process_frame
	# Playback objects are released by a later mixer update, not by queue_free.
	await tree.create_timer(0.5).timeout
	tree.quit(exit_code)
