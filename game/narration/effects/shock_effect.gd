@tool
class_name ShockEffect
extends RichTextEffect
## "A [shock]crackle[/shock] of static." Yellow letters jitter.

var bbcode := "shock"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var tick := int(char_fx.elapsed_time * 20.0)
	var h := absi(hash(Vector2i(char_fx.relative_index, tick)))
	char_fx.offset = Vector2(float(h % 3) - 1.0, float((h >> 2) % 3) - 1.0)
	char_fx.color = Color(1.0, 0.88, 0.4, char_fx.color.a)
	return true
