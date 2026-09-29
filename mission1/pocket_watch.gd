extends Control
## Separate pixel-art hands rotate around the dial using recorded simulation time.
const HOUR_SECONDS := 180.0
var hour_hand: Sprite2D
var minute_hand: Sprite2D
var elapsed_seconds := 0.0:
 set(value):
  elapsed_seconds = clampf(value, 0.0, HOUR_SECONDS * 6.0)
  _update_hands()

static func hand_angles(seconds: float) -> Vector2:
 var hours := seconds / HOUR_SECONDS
 return Vector2((1.0 + hours) * TAU / 12.0 - PI / 2.0, fmod(hours, 1.0) * TAU - PI / 2.0)

func _ready() -> void:
 custom_minimum_size = Vector2(132, 168)
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 var body := Sprite2D.new()
 body.texture = preload("res://assets/ui/mission_1/watch/body.png")
 body.position = Vector2(66, 76)
 add_child(body)
 hour_hand = _hand(preload("res://assets/ui/mission_1/watch/hour_hand.png"), 4)
 minute_hand = _hand(preload("res://assets/ui/mission_1/watch/minute_hand.png"), 5)
 _update_hands()

func _hand(texture: Texture2D, pivot: int) -> Sprite2D:
 var hand := Sprite2D.new()
 hand.texture = texture
 hand.position = Vector2(66, 94)
 hand.offset.y = -texture.get_height() / 2.0 + pivot
 add_child(hand)
 return hand

func _update_hands() -> void:
 if hour_hand == null: return
 var angles := hand_angles(elapsed_seconds)
 hour_hand.rotation = angles.x + PI / 2.0
 minute_hand.rotation = angles.y + PI / 2.0
