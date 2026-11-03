@tool
class_name WhisperEffect
extends RichTextEffect
## "A [whisper]murmur[/whisper] in the dark." Grey letters fade in and out,
## never below half strength, so the word stays readable.

var bbcode := "whisper"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var breath := 0.5 + 0.5 * sin(char_fx.elapsed_time * 2.6 - char_fx.relative_index * 0.4)
	char_fx.color = Color(0.73, 0.7, 0.79, char_fx.color.a * (0.5 + 0.5 * breath))
	return true
