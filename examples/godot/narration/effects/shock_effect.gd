@tool
class_name ShockEffect
extends RichTextEffect
## Text: "A [shock]crackle[/shock] of static."
## Yellow letters that jitter randomly, about 20 times per second.
##
## The same pattern works for the other effects in keywords.csv:
##   poison  -> green, letters sway sideways (offset.x = sin(...))
##   whisper -> grey, transparency slowly pulses (color.a)
##   holy    -> gold, brightness pulses (color.lerp to white)

var bbcode := "shock"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# A new random offset 20 times a second. hash() gives the same "random"
	# value for the same letter and moment, so it doesn't need a RNG.
	var tick := int(char_fx.elapsed_time * 20.0)
	var h := absi(hash(Vector2i(char_fx.relative_index, tick)))
	char_fx.offset = Vector2(float(h % 3) - 1.0, float((h >> 2) % 3) - 1.0)
	char_fx.color = Color(1.0, 0.88, 0.4, char_fx.color.a)
	return true
