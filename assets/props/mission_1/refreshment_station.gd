@tool
extends Node2D
## A small service table, sorted by its feet alongside the characters.
func _draw() -> void:
 for x in [-39,33]:
  draw_rect(Rect2(x,-6,6,15),Color("412e29"))
  draw_rect(Rect2(x,5,6,4),Color("bd9149"))
 draw_rect(Rect2(-49,-26,98,25),Color("412e29"))
 draw_rect(Rect2(-49,-26,98,18),Color("91633c"))
 draw_rect(Rect2(-49,-26,98,18),Color("ceae6a"),false,2)
 draw_rect(Rect2(-42,-24,84,12),Color("dfc18a"))
 for i in 3:
  var x := i*25-29
  draw_rect(Rect2(x,-37,10,17),Color("e8dcc1"))
  draw_rect(Rect2(x+2,-33,6,10),[Color("e3b94c"),Color("83b3bf"),Color("69422d")][i])
  draw_line(Vector2(x,-37),Vector2(x+10,-37),Color("fff1cc"),2)
