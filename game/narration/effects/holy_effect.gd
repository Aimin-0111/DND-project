@tool
class_name HolyEffect
extends RichTextEffect
## "A [holy]radiant[/holy] light." Soft gold letters glow brighter and back.
## They stay gold, never white, so the word still stands out from plain text.

var bbcode := "holy"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var glow := 0.5 + 0.5 * sin(char_fx.elapsed_time * 3.0 - char_fx.relative_index * 0.3)
	var gold := Color(1.0, 0.86, 0.52, char_fx.color.a)
	char_fx.color = gold.lerp(Color(1.0, 0.97, 0.8, char_fx.color.a), glow)
	return true
