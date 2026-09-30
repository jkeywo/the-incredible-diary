extends Node2D
## Small pixel pose: bowed cap, both hands over the face, elbows drawn inward.
func _draw() -> void:
	var navy := Color("192c49")
	var edge := Color("0b1423")
	var skin := Color("dc9863")
	# Boots and planted legs.
	draw_rect(Rect2(-7,-15,6,13),edge)
	draw_rect(Rect2(2,-15,6,13),edge)
	draw_rect(Rect2(-8,-3,7,3),Color("101419"))
	draw_rect(Rect2(2,-3,8,3),Color("101419"))
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-31),Vector2(7,-31),Vector2(11,-22),Vector2(8,-13),Vector2(-8,-13),Vector2(-11,-22)]),edge)
	draw_rect(Rect2(-7,-28,14,14),navy)
	# Bent sleeves rise from each elbow to the face.
	for side in [-1,1]:
		draw_line(Vector2(side*8,-22),Vector2(side*4,-32),navy,5)
		draw_line(Vector2(side*5,-29),Vector2(side*3,-31),Color("c89f46"),2)
		draw_rect(Rect2(side*3-2,-36,4,7),Color("8b573b"))
		draw_rect(Rect2(side*3-1,-35,3,7),skin)
	# The lowered brim hides the eyes above the hands.
	draw_rect(Rect2(-8,-42,16,4),edge)
	draw_rect(Rect2(-6,-44,12,5),Color("e6ded0"))
	draw_rect(Rect2(-8,-39,16,3),navy)
	draw_rect(Rect2(-6,-36,12,2),edge)
	draw_rect(Rect2(-1,-40,3,3),Color("c89f46"))
	for y in [-23,-18]: draw_rect(Rect2(-1,y,2,2),Color("c89f46"))
