class_name DmReplyParser
extends RefCounted
## Splits the AI's reply into narration + commands + state changes and checks
## everything. The AI's output is untrusted: nothing reaches the game without
## passing these checks.

const MARKER := "<<STATE>>"
const MAX_COMMANDS := 5
const COMMANDS := {
	"move_to": {"target": TYPE_STRING},
	"spawn": {"creature": TYPE_STRING, "near": TYPE_STRING},
	"despawn": {"creature": TYPE_STRING},
	"emote": {"who": TYPE_STRING, "emote": TYPE_STRING},
	"weather": {"kind": TYPE_STRING},
	"request_roll": {"skill": TYPE_STRING, "dc": TYPE_FLOAT},
}
const WEATHER := ["clear", "rain", "fog", "storm", "snow", "ash"]
const EMOTES := ["surprised", "angry", "happy", "scared", "sleep"]
const LIMITS := {
	"hp_delta": Vector2i(-30, 30),
	"gold_delta": Vector2i(-200, 200),
	"time_advance_minutes": Vector2i(0, 24 * 60),
}


## Returns {"narration": String, "commands": Array, "state": Dictionary, "errors": Array}
static func parse(reply: String, allowed: Dictionary) -> Dictionary:
	var out := {"narration": reply.strip_edges(), "commands": [], "state": {}, "errors": []}
	var at := reply.find(MARKER)
	if at == -1:
		out["errors"].append("No %s block: narration only." % MARKER)
		return out
	out["narration"] = reply.substr(0, at).strip_edges()
	if str(out["narration"]).is_empty():
		out["errors"].append("Empty narration before %s." % MARKER)

	var json_text := _extract_json(reply.substr(at + MARKER.length()))
	var data: Variant = JSON.parse_string(json_text)
	if not (data is Dictionary):
		out["errors"].append("The state block is not valid JSON.")
		return out

	var commands: Variant = data.get("commands", [])
	if commands is Array:
		if commands.size() > MAX_COMMANDS:
			out["errors"].append("Too many commands: %d (max %d)." % [commands.size(), MAX_COMMANDS])
		for command in commands.slice(0, MAX_COMMANDS):
			var problem := _check_command(command, allowed)
			if problem.is_empty():
				out["commands"].append(command)
			else:
				out["errors"].append(problem)
	elif data.has("commands"):
		out["errors"].append("commands must be an array.")

	var changes: Variant = data.get("state", {})
	if changes is Dictionary:
		out["state"] = _check_changes(changes, allowed, out["errors"])
	elif data.has("state"):
		out["errors"].append("state must be an object.")
	return out


## The AI sometimes wraps JSON in ```json fences: keep the first { to last }.
static func _extract_json(text: String) -> String:
	var start := text.find("{")
	var end := text.rfind("}")
	if start == -1 or end < start:
		return ""
	return text.substr(start, end - start + 1)


static func _check_command(command: Variant, allowed: Dictionary) -> String:
	if not (command is Dictionary) or not COMMANDS.has(command.get("type", "")):
		return "Unknown command: %s" % str(command)
	var fields: Dictionary = COMMANDS[command["type"]]
	for field in fields:
		if typeof(command.get(field)) != fields[field]:
			return "%s: missing or wrong '%s'" % [command["type"], field]
	match command["type"]:
		"move_to":
			if not command["target"] in allowed.get("locations", []):
				return "move_to: unknown place '%s'" % command["target"]
		"spawn":
			if not command["creature"] in allowed.get("creatures", []):
				return "spawn: unknown creature '%s'" % command["creature"]
			if not command["near"] in allowed.get("locations", []):
				return "spawn: unknown place '%s'" % command["near"]
		"weather":
			if not command["kind"] in WEATHER:
				return "weather: unknown kind '%s'" % command["kind"]
		"emote":
			if not command["emote"] in EMOTES:
				return "emote: unknown emote '%s'" % command["emote"]
		"request_roll":
			if not command["skill"] in allowed.get("skills", []):
				return "request_roll: unknown skill '%s'" % command["skill"]
			if command["dc"] < 5.0 or command["dc"] > 30.0:
				return "request_roll: DC must be between 5 and 30"
	return ""


static func _check_changes(changes: Dictionary, allowed: Dictionary, errors: Array) -> Dictionary:
	var ok := {}
	for key in LIMITS:
		if changes.has(key) and typeof(changes[key]) == TYPE_FLOAT:
			var limits: Vector2i = LIMITS[key]
			var value := int(changes[key])
			if value < limits.x or value > limits.y:
				errors.append("%s = %d is out of range, clamped." % [key, value])
			ok[key] = clampi(value, limits.x, limits.y)
	var items: Array = []
	for item_id in changes.get("add_items", []):
		if item_id in allowed.get("items", []):
			items.append(item_id)
		else:
			errors.append("add_items: unknown item '%s'" % str(item_id))
	if not items.is_empty():
		ok["add_items"] = items
	var quests: Array = []
	for quest in changes.get("quest_updates", []):
		if quest is Dictionary and quest.get("id") in allowed.get("quests", []) \
				and typeof(quest.get("stage")) == TYPE_FLOAT:
			quests.append({
				"id": quest["id"],
				"stage": maxi(0, int(quest["stage"])),
				"done": quest.get("done") == true,
			})
		else:
			errors.append("quest_updates: bad entry %s" % str(quest))
	if not quests.is_empty():
		ok["quest_updates"] = quests
	return ok
