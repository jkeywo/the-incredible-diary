extends SceneTree
func _initialize() -> void: call_deferred("checks")
func checks() -> void:
 var loader := preload("res://assets/ui/loading/native_loading.tscn").instantiate()
 root.add_child(loader)
 loader.set_process(false)
 loader._process(0.1)
 assert(not loader.completed and loader.elapsed == 0.1)
 await capture("first")
 loader._process(0.11)
 assert(not loader.completed and loader.elapsed > 0.2)
 await capture("second")
 for i in 500:
  if loader.ticket.done: break
  await process_frame
 assert(loader.ticket.done and loader.ticket.error.is_empty())
 loader._process(1.0)
 await process_frame
 await process_frame
 assert(current_scene.scene_file_path == "res://assets/ui/mission_1/title_screen.tscn")
 await capture("title")
 print("NATIVE LOADING PASS: animated frames, background title load and transition")
 await preload("res://tests/shutdown.gd").finish(self)
func capture(label: String) -> void:
 if "--screenshots" not in OS.get_cmdline_user_args(): return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/native-loading-"+label+".png")
