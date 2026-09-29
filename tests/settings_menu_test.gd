extends SceneTree
const Title = preload("res://assets/ui/mission_1/title_screen.tscn")
const Play = preload("res://mission1/play.tscn")
const Save = preload("res://mission1/save.gd")
const PATH := "res://build/settings-menu-save.json"
func _initialize(): call_deferred("checks")
func checks():
 var settings = root.get_node("AudioSettings")
 settings.settings_path = "res://build/settings-menu.cfg"
 Save.clear(PATH)
 var title = Title.instantiate()
 title.mission_save_path = PATH
 root.add_child(title)
 current_scene = title
 await process_frame
 settings.open_settings()
 assert(settings.main_menu_button.disabled)
 settings.close_settings()
 await create_timer(0.2).timeout
 var game = Play.instantiate()
 game.save_path = PATH
 game.configure({},true)
 title.set_game_world(game)
 title._game_world = game
 game.set_physics_process(false)
 game.sim.s.message = "Saved before returning to the menu."
 var expected: Dictionary = game.sim.s.duplicate(true)
 # A failed save keeps the existing game paused and available.
 game.save_path = "res://build/missing-save-directory/cannot-save.json"
 settings.open_settings()
 assert(not settings.main_menu_button.disabled)
 settings.return_to_main_menu()
 assert(current_scene == title and paused and settings.menu_status.visible)
 game.save_path = PATH
 # Starting in an editor pause must not leave the new menu paused.
 settings.close_settings()
 await create_timer(0.2).timeout
 root.get_node("PauseEditor").pause(title)
 settings.open_settings()
 settings.main_menu_button.pressed.emit()
 await scene_changed
 assert(current_scene.scene_file_path == settings.MAIN_MENU)
 assert(not paused and not settings.dialog.visible)
 assert(not root.get_node("PauseEditor").owns_pause)
 var saved: Dictionary = Save.load_saved(PATH)
 assert(saved.ok)
 for key in expected:
  assert(saved.data.current[key] == expected[key])
 assert(saved.data.current.message == expected.message and saved.data.current.tick == expected.tick and saved.data.current.pos == expected.pos)
 current_scene.mission_save_path = PATH
 current_scene._refresh_continue()
 assert(current_scene.continue_button.visible)
 settings.open_settings()
 assert(settings.main_menu_button.disabled)
 settings.close_settings()
 await create_timer(0.2).timeout
 Save.clear(PATH)
 print("SETTINGS MENU PASS: nested gameplay save, failure preservation, return, Continue and pause cleanup")
 quit()
