@tool
class_name FreezeEffect
extends RichTextEffect
## "Your breath turns to [freeze]mist[/freeze]." Pale blue, shimmering letters.

var bbcode := "freeze"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var wave := sin(char_fx.elapsed_time * 2.0 - char_fx.relative_index * 0.6)
	var sparkle := 1.0 if wave > 0.95 else 0.0
	var base := Color(0.62, 0.85, 1.0)
	char_fx.color = base.lerp(Color.WHITE, sparkle * 0.8)
	char_fx.color.a *= 0.8 + 0.2 * wave
	return true
