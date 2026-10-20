extends RichTextLabel
## Story log: typewriter reveal, keyword effects, and a limit on how many
## entries keep animating so a long campaign stays fast.

signal finished_typing

@export var chars_per_second := 45.0
@export var animated_entries := 4
@export var reduce_motion := false

## Effects with a moving look; the others always show their still colour.
const ANIMATED := ["burn", "freeze", "shock"]
const STILL_COLORS := {
	"burn": "#ff8a3d", "freeze": "#9fd8ff", "shock": "#ffe066",
	"poison": "#8fd16a", "whisper": "#b9b3c9", "holy": "#ffe9a8",
}

var _entries: Array[String] = []
var _shown := 0.0
var _typing := false


func _ready() -> void:
	bbcode_enabled = true
	scroll_following = true
	install_effect(BurnEffect.new())
	install_effect(FreezeEffect.new())
	install_effect(ShockEffect.new())


## bbcode_text comes from KeywordTagger and is already safe.
func add_entry(bbcode_text: String) -> void:
	var already_shown := get_total_character_count()
	_entries.append(bbcode_text)
	_rebuild()
	_shown = float(already_shown)
	visible_characters = already_shown
	_typing = true


func add_plain_line(text: String) -> void:
	_entries.append("[color=#9aa6a8]%s[/color]" % text.replace("[", "[lb]"))
	_rebuild()
	visible_characters = -1


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown += chars_per_second * delta
	visible_characters = int(_shown)
	if visible_characters >= get_total_character_count():
		_finish()


func _gui_input(event: InputEvent) -> void:
	if _typing and event is InputEventMouseButton and event.pressed:
		_finish()


func skip_typing() -> void:
	if _typing:
		_finish()


func _finish() -> void:
	_typing = false
	visible_characters = -1
	finished_typing.emit()


func _rebuild() -> void:
	clear()
	var first_animated := _entries.size() - animated_entries
	for i in _entries.size():
		var entry := _entries[i]
		if reduce_motion or i < first_animated:
			entry = _freeze_effects(entry, STILL_COLORS.keys())
		else:
			entry = _freeze_effects(entry, STILL_COLORS.keys().filter(
				func(effect: String) -> bool: return not effect in ANIMATED))
		append_text(entry + "\n\n")


func _freeze_effects(bbcode_text: String, effects: Array) -> String:
	for effect in effects:
		bbcode_text = bbcode_text.replace("[%s]" % effect, "[color=%s]" % STILL_COLORS[effect])
		bbcode_text = bbcode_text.replace("[/%s]" % effect, "[/color]")
	return bbcode_text
