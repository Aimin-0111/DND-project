extends RefCounted
## Regression check on archived Haiku replies (S1, S6, S8). This does not
## pretend to be a new model run; it checks that the current parser still
## handles real replies. The S8 narration/state drift remains documented.

const ALLOWED := {
	"locations": ["mill_road", "mill_bridge", "old_mill"],
	"creatures": ["rust_wolf"],
	"items": ["rusty_sword", "healing_draught"],
	"skills": ["Stealth", "Survival", "Perception"],
	"quests": ["the_silent_mill"],
}


func run() -> Array:
	var failures: Array = []

	var s1 := DmReplyParser.parse(_read("res://tests/fixtures/replies/S1.txt"), ALLOWED)
	if not s1["errors"].is_empty():
		failures.append("S1 should parse cleanly: %s" % str(s1["errors"]))
	if not s1["commands"].is_empty():
		failures.append("S1 should not invent a command to the Silver Tower")

	var s6 := DmReplyParser.parse(_read("res://tests/fixtures/replies/S6.txt"), ALLOWED)
	if not s6["errors"].is_empty():
		failures.append("S6 should parse cleanly: %s" % str(s6["errors"]))
	if not s6["state"].is_empty():
		failures.append("S6 injection should not change state")

	var s8 := DmReplyParser.parse(_read("res://tests/fixtures/replies/S8.txt"), ALLOWED)
	if not s8["errors"].is_empty():
		failures.append("S8 should parse cleanly: %s" % str(s8["errors"]))
	if s8["commands"].size() != 2:
		failures.append("S8 should keep weather + request_roll")
	if int(s8["state"].get("time_advance_minutes", 0)) != 240:
		failures.append("S8 should advance time by 240 minutes")

	return failures


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
