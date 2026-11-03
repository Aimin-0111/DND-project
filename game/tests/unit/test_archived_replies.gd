extends RefCounted
## Regression check on the 8 archived Haiku replies (SPEC-dm "Saved replies").
## This is not a new model run: it checks that the current parser drops
## nothing from real replies and keeps exactly the commands RESULTS.md lists.
## The parser can't see the narration problems found there (S1 invents the
## tower, S8 moves the hero without a move_to).

const FIXTURES := "res://tests/fixtures/replies/"
const MARKER := "<<STATE>>"

## The ALLOWED IDS block of the prompt these replies answered
## (examples/ai-tests/dm_test_context.md).
const ALLOWED := {
	"locations": ["mill_road", "old_mill", "mill_bridge", "mill_bridge_east", "copper_river"],
	"creatures": ["rust_wolf", "bog_ghoul", "cinder_imp", "brass_sentinel", "river_troll"],
	"items": ["rusty_sword", "hunting_bow", "leather_coat", "healing_draught", "tallow_candle", "brass_key"],
	"skills": ["Athletics", "Acrobatics", "Stealth", "Perception", "Investigation", "Persuasion", "Insight", "Survival"],
	"quests": ["the_silent_mill"],
}

## What each reply must keep. Commands: SPEC-dm and RESULTS.md. State: SPEC-dm
## lists S8's 240 minutes; the minutes in S3, S4 and S5 are the files' values.
const EXPECTED := {
	"S1": {"commands": [], "state": {}},
	"S2": {"commands": [], "state": {}},
	"S3": {
		"commands": [{"type": "request_roll", "skill": "Athletics", "dc": 13}],
		"state": {"time_advance_minutes": 1},
	},
	"S4": {
		"commands": [
			{"type": "move_to", "target": "old_mill"},
			{"type": "request_roll", "skill": "Perception", "dc": 12},
		],
		"state": {"time_advance_minutes": 15},
	},
	"S5": {
		"commands": [{"type": "request_roll", "skill": "Persuasion", "dc": 13}],
		"state": {"time_advance_minutes": 5},
	},
	"S6": {"commands": [], "state": {}},
	"S7": {"commands": [], "state": {}},
	"S8": {
		"commands": [
			{"type": "weather", "kind": "fog"},
			{"type": "request_roll", "skill": "Stealth", "dc": 13},
		],
		"state": {"time_advance_minutes": 240},
	},
}


func run() -> Array:
	var failures: Array = []
	for scenario in EXPECTED:
		var path: String = FIXTURES + scenario + ".txt"
		if not FileAccess.file_exists(path):
			failures.append("%s: missing fixture %s" % [scenario, path])
			continue
		var reply := FileAccess.get_file_as_string(path)
		var at := reply.find(MARKER)
		if at == -1:
			failures.append("%s: the fixture has no %s line" % [scenario, MARKER])
			continue
		var parsed := DmReplyParser.parse(reply, ALLOWED)
		var expected: Dictionary = EXPECTED[scenario]
		if not parsed["errors"].is_empty():
			failures.append("%s should drop nothing: %s" % [scenario, str(parsed["errors"])])
		if _json(parsed["commands"]) != _json(expected["commands"]):
			failures.append("%s kept commands %s, expected %s" % [scenario, _json(parsed["commands"]), _json(expected["commands"])])
		if _json(parsed["state"]) != _json(expected["state"]):
			failures.append("%s kept state %s, expected %s" % [scenario, _json(parsed["state"]), _json(expected["state"])])
		if parsed["narration"] != reply.left(at).strip_edges():
			failures.append("%s: the narration should be the whole text before %s" % [scenario, MARKER])
	return failures


## JSON text with every number as a float and keys sorted. The parser keeps
## JSON numbers as floats (dc 13.0) but returns state values as ints, so
## 13 and 13.0 must compare equal.
static func _json(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))
