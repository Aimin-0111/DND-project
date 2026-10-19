class_name DmReplyParser
extends RefCounted
## Splits the AI's reply into narration + commands + state changes, and
## CHECKS everything. The AI's output is untrusted: it can invent a
## location, ask for 1,000,000 gold, or forget the JSON. Nothing reaches
## the game without passing these checks.
##
## Reply format (kept from the old prototype so copy-paste mode works too):
##
##   The planks groan as you step onto the bridge...
##   <<STATE>>
##   {"commands": [{"type": "move_to", "target": "mill_bridge"}],
##    "state": {"gold_delta": 5, "time_advance_minutes": 10}}
##
## Other option for the API modes only: Claude "structured outputs" (a JSON
## schema the reply must follow). More reliable, but it can't be used in
## copy-paste mode, and the checks below are still needed either way.

const MARKER := "<<STATE>>"
const MAX_COMMANDS := 5

## Allowed command types and the fields each one needs.
## JSON has no integers, so numbers are TYPE_FLOAT.
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

## Limits on what one reply may change.
const LIMITS := {
	"hp_delta": Vector2i(-30, 30),
	"gold_delta": Vector2i(-200, 200),
	"time_advance_minutes": Vector2i(0, 24 * 60),
}


## allowed = {"locations": [...], "creatures": [...], "items": [...], "skills": [...], "quests": [...]}
## Returns {"narration": String, "commands": Array, "state": Dictionary, "errors": Array}
static func parse(reply: String, allowed: Dictionary) -> Dictionary:
	var out := {"narration": reply.strip_edges(), "commands": [], "state": {}, "errors": []}
	var at := reply.find(MARKER)
	if at == -1:
		out["errors"].append("No %s block: narration only." % MARKER)
		return out
	out["narration"] = reply.substr(0, at).strip_edges()

	var json_text := _extract_json(reply.substr(at + MARKER.length()))
	var data = JSON.parse_string(json_text)
	if not (data is Dictionary):
		out["errors"].append("The state block is not valid JSON.")
		return out

	var commands = data.get("commands", [])
	if commands is Array:
		for cmd in commands.slice(0, MAX_COMMANDS):
			var problem := _check_command(cmd, allowed)
			if problem == "":
				out["commands"].append(cmd)
			else:
				out["errors"].append(problem)
	var changes = data.get("state", {})
	if changes is Dictionary:
		out["state"] = _check_changes(changes, allowed, out["errors"])
	return out


## The AI sometimes wraps JSON in ```json ... ``` fences: keep what's between
## the first "{" and the last "}".
static func _extract_json(text: String) -> String:
	var start := text.find("{")
	var end := text.rfind("}")
	if start == -1 or end < start:
		return ""
	return text.substr(start, end - start + 1)


## Returns "" if the command is fine, otherwise the reason it was dropped.
static func _check_command(cmd, allowed: Dictionary) -> String:
	if not (cmd is Dictionary) or not COMMANDS.has(cmd.get("type", "")):
		return "Unknown command: %s" % str(cmd)
	var fields: Dictionary = COMMANDS[cmd["type"]]
	for field in fields:
		if typeof(cmd.get(field)) != fields[field]:
			return "%s: missing or wrong '%s'" % [cmd["type"], field]
	match cmd["type"]:
		"move_to":
			if not cmd["target"] in allowed["locations"]:
				return "move_to: unknown place '%s'" % cmd["target"]
		"spawn":
			if not cmd["creature"] in allowed["creatures"]:
				return "spawn: unknown creature '%s'" % cmd["creature"]
			if not cmd["near"] in allowed["locations"]:
				return "spawn: unknown place '%s'" % cmd["near"]
		"weather":
			if not cmd["kind"] in WEATHER:
				return "weather: unknown kind '%s'" % cmd["kind"]
		"emote":
			if not cmd["emote"] in EMOTES:
				return "emote: unknown emote '%s'" % cmd["emote"]
		"request_roll":
			if not cmd["skill"] in allowed["skills"] or cmd["dc"] < 5 or cmd["dc"] > 30:
				return "request_roll: bad skill or DC"
	return ""


static func _check_changes(changes: Dictionary, allowed: Dictionary, errors: Array) -> Dictionary:
	var ok := {}
	for key in LIMITS:
		if changes.has(key) and typeof(changes[key]) == TYPE_FLOAT:
			var lim: Vector2i = LIMITS[key]
			var value := int(changes[key])
			if value < lim.x or value > lim.y:
				errors.append("%s = %d is out of range, clamped." % [key, value])
			ok[key] = clampi(value, lim.x, lim.y)
	var items := []
	for item_id in changes.get("add_items", []):
		if item_id in allowed["items"]:
			items.append(item_id)
		else:
			errors.append("add_items: unknown item '%s'" % str(item_id))
	if not items.is_empty():
		ok["add_items"] = items
	var quests := []
	for q in changes.get("quest_updates", []):
		if q is Dictionary and q.get("id") in allowed["quests"] and typeof(q.get("stage")) == TYPE_FLOAT:
			quests.append({"id": q["id"], "stage": int(q["stage"]), "done": q.get("done") == true})
		else:
			errors.append("quest_updates: bad entry %s" % str(q))
	if not quests.is_empty():
		ok["quest_updates"] = quests
	return ok
