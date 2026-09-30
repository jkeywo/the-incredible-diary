@tool
extends AnimatedSprite2D
## Normalise the generated four-by-four poses to the shared 32x48 grid.
const Grounding = preload("res://assets/characters/grounding.gd")
var character_id := "captain"
static var cached: SpriteFrames
var grief: Node2D
func _ready() -> void:
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 Grounding.install(self)
 if cached == null: cached = make_frames()
 sprite_frames = cached
 grief = preload("res://assets/characters/captain_grief.gd").new()
 add_child(grief)
 play_action("idle","down")
func play_action(action: String, direction := "down") -> void:
 if is_instance_valid(grief): grief.visible = action == "grief"
 self_modulate.a = 0.0 if action == "grief" else 1.0
 var clip := (action if action in ["idle","walk","talk"] else "idle")+"_"+direction
 if animation != clip or not is_playing(): play(clip)
 Grounding.sync(self)
static func make_frames() -> SpriteFrames:
 var source := load("res://assets/characters/source/captain.png") as Texture2D
 var image := source.get_image()
 # Sprite import uses hard pixel edges; discard the generator's faint matte.
 for y in image.get_height():
  for x in image.get_width():
   var color := image.get_pixel(x,y)
   color.a = 1.0 if color.a >= 0.5 else 0.0
   image.set_pixel(x,y,color)
 var cell := Vector2i(image.get_width()/4,image.get_height()/4)
 var sheet := Image.create(128,192,false,Image.FORMAT_RGBA8)
 for row in 4:
  for col in 4:
   var pose := image.get_region(Rect2i(Vector2i(col,row)*cell,cell))
   var bounds := pose.get_used_rect()
   if bounds.size.x == 0: continue
   pose = pose.get_region(bounds)
   var factor := minf(30.0/pose.get_width(),46.0/pose.get_height())
   pose.resize(maxi(1,roundi(pose.get_width()*factor)),maxi(1,roundi(pose.get_height()*factor)),Image.INTERPOLATE_NEAREST)
   sheet.blit_rect(pose,Rect2i(Vector2i.ZERO,pose.get_size()),Vector2i(col*32+(32-pose.get_width())/2,row*48+48-pose.get_height()))
 var texture := ImageTexture.create_from_image(sheet)
 var frames := SpriteFrames.new()
 frames.remove_animation("default")
 for row in 4:
  for action in ["idle","walk","talk"]:
   var name: String = action+"_"+["down","left","up","right"][row]
   frames.add_animation(name)
   frames.set_animation_speed(name,6 if action == "walk" else 2)
   var columns: Array = [0,1,0,3] if action == "walk" else [0,2] if action == "talk" else [0]
   for col in columns:
    var atlas := AtlasTexture.new()
    atlas.atlas = texture
    atlas.region = Rect2(col*32,row*48,32,48)
    frames.add_frame(name,atlas)
 return frames
