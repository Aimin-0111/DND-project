@tool
class_name BurnEffect
extends RichTextEffect
## "The [burn]fire[/burn] spreads." Each letter flickers and hops like a flame.

var bbcode := "burn"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var power := float(char_fx.env.get("power", 1.0))
	var t := char_fx.elapsed_time * 8.0 + char_fx.relative_index * 1.3
	char_fx.offset.y = -absf(sin(t)) * 2.0 * power
	var heat := 0.5 + 0.5 * sin(t * 1.7)
	char_fx.color = Color(1.0, 0.35 + 0.4 * heat, 0.1, char_fx.color.a)
	return true
