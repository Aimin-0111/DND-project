@tool
class_name PoisonEffect
extends RichTextEffect
## "The [poison]venom[/poison] seeps in." Green letters wobble slowly up and
## down, never sideways, so neighbours can't overlap.

var bbcode := "poison"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var wave := sin(char_fx.elapsed_time * 2.5 - char_fx.relative_index * 0.6)
	char_fx.offset.y = wave * 1.5
	char_fx.color = Color(0.56, 0.82, 0.42, char_fx.color.a)
	return true
