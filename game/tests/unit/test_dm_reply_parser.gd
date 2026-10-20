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

	failures.append_array(_beta_02_checks())
	return failures


## Gaps found in the Beta-0.1 review.
func _beta_02_checks() -> Array:
	var failures: Array = []

	var nulls := _parse('{"commands":[{"type":"weather","kind":"fog"}],"state":{"gold_delta":5.0,"add_items":null,"quest_updates":null}}')
	if nulls["commands"].size() != 1 or int(nulls["state"].get("gold_delta", 0)) != 5:
		failures.append("null lists must not drop the rest of the reply: %s" % str(nulls))
	if nulls["errors"].size() != 2:
		failures.append("null add_items and quest_updates should each be noted: %s" % str(nulls["errors"]))

	var five_items := _parse('{"state":{"add_items":["rusty_sword","rusty_sword","healing_draught","healing_draught","rusty_sword"]}}')
	if five_items["state"].get("add_items", []).size() != 3:
		failures.append("add_items should keep at most 3")
	if five_items["errors"].size() != 2:
		failures.append("the 2 extra items should be noted")

	for dc in ['13.5', '"13"', '50.0']:
		var roll := _parse('{"commands":[{"type":"request_roll","skill":"Stealth","dc":%s}]}' % dc)
		if not roll["commands"].is_empty():
			failures.append("dc %s should be dropped" % dc)
	var good_roll := _parse('{"commands":[{"type":"request_roll","skill":"Stealth","dc":13.0}]}')
	if good_roll["commands"].size() != 1:
		failures.append("dc 13 should be kept")

	var emotes := _parse('{"commands":[{"type":"emote","who":"dragon","emote":"angry"},{"type":"emote","who":"oda","emote":"happy"},{"type":"emote","who":"hero","emote":"scared"}]}')
	if emotes["commands"].size() != 2:
		failures.append("emote by an unknown character should be dropped, oda and hero kept: %s" % str(emotes["commands"]))

	var despawn := _parse('{"commands":[{"type":"despawn","creature":"dragon"}]}')
	if not despawn["commands"].is_empty():
		failures.append("despawn of an unknown creature should be dropped")

	var unknown_key := _parse('{"state":{"xp_delta":50.0,"gold_delta":"10"}}')
	if not unknown_key["state"].is_empty():
		failures.append("unknown keys and text numbers must not be applied")
	if unknown_key["errors"].size() != 2:
		failures.append("unknown key and text number should be noted: %s" % str(unknown_key["errors"]))

	var quests := _parse('{"state":{"quest_updates":[{"id":"the_silent_mill","stage":"1"},{"id":"the_silent_mill","stage":1.5},{"id":"the_silent_mill","stage":-1.0},{"id":"the_silent_mill","stage":2.0,"done":"yes"},{"id":"the_silent_mill","stage":2.0,"done":true}]}}')
	if quests["state"].get("quest_updates", []).size() != 1:
		failures.append("only the well-formed quest update should be kept: %s" % str(quests["state"]))

	return failures


func _parse(json_text: String) -> Dictionary:
	var allowed := ALLOWED.duplicate()
	allowed["npcs"] = ["oda"]
	return DmReplyParser.parse("Narration.\n<<STATE>>\n" + json_text, allowed)


func _commands(count: int) -> String:
	var parts: Array[String] = []
	for i in count:
		parts.append('{"type":"move_to","target":"mill_road"}')
	return ",".join(parts)
