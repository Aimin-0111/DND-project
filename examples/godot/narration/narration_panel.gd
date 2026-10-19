extends RichTextLabel
## The story log: typewriter reveal, keyword effects, and a limit on how
## many entries keep animating (so a long campaign doesn't slow down).
## Attach to the "Story" RichTextLabel in story_panel.tscn.

signal finished_typing

@export var chars_per_second := 45.0
## Only the newest entries animate. Older ones keep a fixed colour.
@export var animated_entries := 4
@export var reduce_motion := false

## Fixed colours used when an entry stops animating (or with reduce_motion).
const STILL_COLORS := {
	"burn": "#ff8a3d", "freeze": "#9fd8ff", "shock": "#ffe066",
	"poison": "#8fd16a", "whisper": "#b9b3c9", "holy": "#ffe9a8",
}

var _entries: Array[String] = []
var _shown := 0.0          # characters revealed so far (float for smooth speed)
var _typing := false


func _ready() -> void:
	bbcode_enabled = true
	scroll_following = true
	install_effect(BurnEffect.new())
	install_effect(FreezeEffect.new())
	install_effect(ShockEffect.new())
	# poison, whisper and holy are installed the same way once written.


## bbcode_text comes from KeywordTagger, already made safe.
func add_entry(bbcode_text: String) -> void:
	# Reveal only the new entry: start after the characters already shown.
	var already_shown := get_total_character_count()
	_entries.append(bbcode_text)
	_rebuild()
	_shown = float(already_shown)
	visible_characters = already_shown
	_typing = true


## Player input lines and dice results appear instantly, without effects.
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


## Clicking the story skips the typewriter.
func _gui_input(event: InputEvent) -> void:
	if _typing and event is InputEventMouseButton and event.pressed:
		_finish()


func _finish() -> void:
	_typing = false
	visible_characters = -1   # -1 = show everything
	finished_typing.emit()


func _rebuild() -> void:
	clear()
	var first_animated := _entries.size() - animated_entries
	for i in _entries.size():
		var entry := _entries[i]
		if reduce_motion or i < first_animated:
			entry = _freeze_effects(entry)
		append_text(entry + "\n\n")


## "[burn]fire[/burn]" -> "[color=#ff8a3d]fire[/color]"
func _freeze_effects(bbcode_text: String) -> String:
	for effect in STILL_COLORS:
		bbcode_text = bbcode_text.replace("[%s]" % effect, "[color=%s]" % STILL_COLORS[effect])
		bbcode_text = bbcode_text.replace("[/%s]" % effect, "[/color]")
	return bbcode_text

