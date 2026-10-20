extends RefCounted
## The parser must accept one good reply and reject or clamp every bad one.

const ALLOWED := {
	"locations": ["mill_road", "mill_bridge", "old_mill"],
	"creatures": ["rust_wolf"],
	"items": ["rusty_sword", "healing_draught"],
	"skills": ["Stealth", "Survival", "Perception"],
	"quests": ["the_silent_mill"],
}


func run() -> Array:
	var failures: Array = []

	var valid := """Vous poussez la porte du moulin.
<<STATE>>
{"commands": [
  {"type": "move_to", "target": "old_mill"},
  {"type": "spawn", "creature": "rust_wolf", "near": "old_mill"}
],
 "state": {"gold_delta": -5.0, "time_advance_minutes": 30.0,
           "add_items": ["healing_draught"],
           "quest_updates": [{"id": "the_silent_mill", "stage": 1.0}]}}
"""
	var parsed := DmReplyParser.parse(valid, ALLOWED)
	if not parsed["errors"].is_empty():
		failures.append("valid reply produced errors: %s" % str(parsed["errors"]))
	if parsed["commands"].size() != 2:
		failures.append("valid reply should keep 2 commands")
	if int(parsed["state"].get("gold_delta", 0)) != -5:
		failures.append("gold_delta -5 was not kept")
	if int(parsed["state"].get("time_advance_minutes", 0)) != 30:
		failures.append("time_advance_minutes 30 was not kept")
	if not "healing_draught" in parsed["state"].get("add_items", []):
		failures.append("known item was not kept")

	var fenced := DmReplyParser.parse("Narration.\n<<STATE>>\n```json\n{\"commands\":[],\"state\":{}}\n```", ALLOWED)
	if not fenced["errors"].is_empty():
		failures.append("fenced JSON should parse: %s" % str(fenced["errors"]))

	var missing := DmReplyParser.parse("Narration only.", ALLOWED)
	if missing["errors"].is_empty():
		failures.append("missing marker should be an error")

	var broken := DmReplyParser.parse("Narration.\n<<STATE>>\n{not json", ALLOWED)
	if broken["errors"].is_empty():
		failures.append("broken JSON should be an error")

	var unknown := DmReplyParser.parse(
		"Narration.\n<<STATE>>\n{\"commands\":[{\"type\":\"teleport\",\"target\":\"old_mill\"},{\"type\":\"move_to\",\"target\":\"silver_tower\"}],\"state\":{}}",
		ALLOWED,
	)
	if unknown["commands"].size() != 0:
		failures.append("unknown command/location should be dropped")
	if unknown["errors"].size() < 2:
		failures.append("unknown command and location should both be reported")

	var clamped := DmReplyParser.parse(
		"Narration.\n<<STATE>>\n{\"commands\":[],\"state\":{\"gold_delta\":9999.0,\"hp_delta\":-999.0}}",
		ALLOWED,
	)
	if int(clamped["state"].get("gold_delta", 0)) != 200:
		failures.append("gold_delta should clamp to 200")
	if int(clamped["state"].get("hp_delta", 0)) != -30:
		failures.append("hp_delta should clamp to -30")
	if clamped["errors"].size() < 2:
		failures.append("clamped values should be reported")

	var too_many := DmReplyParser.parse(
		"Narration.\n<<STATE>>\n{\"commands\":[" + _commands(6) + "],\"state\":{}}",
		ALLOWED,
	)
	if too_many["commands"].size() != 5:
		failures.append("parser should keep at most 5 commands")
	if too_many["errors"].is_empty():
		failures.append("too many commands should be reported")

	var bad_roll := DmReplyParser.parse(
		"Narration.\n<<STATE>>\n{\"commands\":[{\"type\":\"request_roll\",\"skill\":\"Flying\",\"dc\":99.0}],\"state\":{}}",
		ALLOWED,
	)
	if not bad_roll["commands"].is_empty():
		failures.append("request_roll with unknown skill should be dropped")

	return failures


func _commands(count: int) -> String:
	var parts: Array[String] = []
	for i in count:
		parts.append('{"type":"move_to","target":"mill_road"}')
	return ",".join(parts)
