extends SceneTree
var confirmed := -1
func _initialize(): call_deferred("checks")
func checks():
 var menu = preload("res://assets/ui/mission_1/action_wheel.tscn").instantiate()
 root.add_child(menu)
 menu.option_confirmed.connect(func(index, _label): confirmed = index)
 var labels := PackedStringArray()
 for i in 8: labels.append("Choice %d" % i)
 menu.options = labels
 assert(menu.indices.size() == 8 and not menu.indices.has(-1))
 for i in 8:
  assert(menu.buttons[i].position.x < 100 if i < 4 else menu.buttons[i].position.x > 250)
  menu.activate_slot(i)
  assert(confirmed == i)
 labels.append("Choice 8")
 menu.options = labels
 assert(menu.indices == [0,1,2,3,4,5,6,-1])
 confirmed = -1
 menu.buttons[7].pressed.emit()
 assert(confirmed == -1 and menu.page == 1 and menu.indices == [7,8,-1])
 menu.options = labels
 assert(menu.page == 1)
 menu.activate_slot(1)
 assert(confirmed == 8)
 menu.activate_slot(2)
 assert(menu.page == 0)
 for i in range(9,23): labels.append("Choice %d" % i)
 menu.options = labels
 var reached := []
 for page in 4:
  for i in menu.indices:
   if i >= 0: reached.append(i)
  menu.activate_slot(menu.indices.size()-1)
 assert(reached == range(23) and menu.page == 0)
 menu.select_from_vector(Vector2(1,-1))
 assert(menu.buttons[menu.selected_index].position.x>250)
 menu.confirm_selected()
 assert(confirmed == menu.indices[menu.selected_index])
 menu.options = PackedStringArray(["Inspect"])
 assert(menu.page == 0 and menu.indices == [0])
 await process_frame
 assert(menu.buttons[0].size.y == 48)
 menu.options = PackedStringArray()
 menu.confirm_selected()
 assert(menu.buttons.is_empty())
 menu.queue_free()
 await process_frame
 print("ACTION MENU PASS: two columns, eight choices, paging, stable refresh, mouse and controller selection")
 quit()
