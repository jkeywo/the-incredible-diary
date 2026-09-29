extends Node2D
## Layered steam sampled from voyage time, including recorded rewind frames.
var phase := 0.0
var active := false

func show_at(time: float, enabled: bool) -> void:
 phase = time
 active = enabled
 visible = enabled
 queue_redraw()

func _draw() -> void:
 if not active: return
 var xs := [625.0,685.0,1050.0,1125.0]
 var ys := [30.0,130.0,575.0,690.0]
 var fade := [0.0,1.0,1.0,0.0]
 for x in 3:
  for y in 3:
   var points := PackedVector2Array([Vector2(xs[x],ys[y]),Vector2(xs[x+1],ys[y]),Vector2(xs[x+1],ys[y+1]),Vector2(xs[x],ys[y+1])])
   var colors := PackedColorArray()
   for corner in [Vector2i(x,y),Vector2i(x+1,y),Vector2i(x+1,y+1),Vector2i(x,y+1)]:
    colors.append(Color(0.78,0.84,0.85,0.22*fade[corner.x]*fade[corner.y]))
   draw_polygon(points,colors)
 for i in 32:
  var x := 680.0+fmod(i*79.0+phase*(7+i%4),370.0)
  var y := 135.0+fposmod(i*53.0-phase*(4+i%3),460.0)
  for layer in 4:
   draw_circle(Vector2(x,y),35.0+layer*10.0,Color(0.85,0.89,0.9,0.022))
