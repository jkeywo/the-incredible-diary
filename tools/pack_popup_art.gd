extends SceneTree
func _initialize() -> void:
 var image := Image.load_from_file("res://assets/ui/popup/source/panel.png")
 image.resize(384, 384, Image.INTERPOLATE_LANCZOS)
 var cuts := [0, 48, 336, 384]
 var names := [["top_left", "top", "top_right"], ["left", "body", "right"], ["bottom_left", "bottom", "bottom_right"]]
 for y in range(3):
  for x in range(3):
   var region := Rect2i(cuts[x], cuts[y], cuts[x+1]-cuts[x], cuts[y+1]-cuts[y])
   image.get_region(region).save_png("res://assets/ui/popup/%s.png" % names[y][x])
 var tab := Image.load_from_file("res://assets/ui/popup/source/tab.png")
 tab = tab.get_region(tab.get_used_rect())
 tab.resize(240, 52, Image.INTERPOLATE_LANCZOS)
 tab.save_png("res://assets/ui/popup/tab.png")
 quit()
