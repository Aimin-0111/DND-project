class_name DmReplyParser
extends RefCounted
## Splits the AI's reply into narration + commands + state changes and checks
## everything. The AI's output is untrusted: nothing reaches the game without
## passing these checks.

const MARKER := "<<STATE>>"
const MAX_COMMANDS := 5
const COMMANDS := {
	"travel": {"to": TYPE_STRING},
	"move_to": {"target": TYPE_STRING},
	"spawn": {"creature": TYPE_STRING, "near": TYPE_STRING},
	"despawn": {"creature": TYPE_STRING},
	"emote": {"who": TYPE_STRING, "emote": TYPE_STRING},
	"weather": {"kind": TYPE_STRING},
	"request_roll": {"skill": TYPE_STRING, "dc": TYPE_FLOAT},
}
const DIRECTIONS := ["north", "east", "south", "west"]
const WEATHER := ["clear", "rain", "fog", "storm", "snow", "ash"]
const EMOTES := ["surprised", "angry", "happy", "scared", "sleep"]
const LIMITS := {
	"hp_delta": Vector2i(-30, 30),
	"gold_delta": Vector2i(-200, 200),
	"time_advance_minutes": Vector2i(0, 24 * 60),
}
const MAX_ADD_ITEMS := 3
const CHANGE_KEYS := ["hp_delta", "gold_delta", "time_advance_minutes", "add_items", "quest_updates"]


## Returns {"narration": String, "commands": Array, "state": Dictionary, "errors": Array}
## With a map view (allowed["map"], allowed["travel"]), at most one travel is
## kept and put first, and move_to / spawn near are checked against the places
## of the square the hero ends up in. Without one, the M1 checks apply.
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
		out["commands"] = _check_commands(commands.slice(0, MAX_COMMANDS), allowed, out["errors"])
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


## Travel first: the first valid travel is kept (rebuilt with only its type
## and "to") and put at the front; the other commands are checked against
## the square the hero ends up in.
static func _check_commands(commands: Array, allowed: Dictionary, errors: Array) -> Array:
	var travel := {}
	for command in commands:
		if not (command is Dictionary) or command.get("type") != "travel":
			continue
		var problem := _check_command(command, allowed, null)
		if problem.is_empty() and not travel.is_empty():
			problem = "travel: only one per reply, '%s' dropped." % command["to"]
		if problem.is_empty():
			travel = {"type": "travel", "to": command["to"]}
		else:
			errors.append(problem)
	var kept: Array = [] if travel.is_empty() else [travel]
	var places: Variant = _places_after(travel, allowed)
	for command in commands:
		if command is Dictionary and command.get("type") == "travel":
			continue
		var problem := _check_command(command, allowed, places)
		if problem.is_empty():
			kept.append(command)
		else:
			errors.append(problem)
	return kept


## The places of the square the hero will be in after this reply's travel
## (the current square without one), or null when there is no map view.
static func _places_after(travel: Dictionary, allowed: Dictionary) -> Variant:
	var view: Variant = allowed.get("map")
	if not (view is Dictionary):
		return null
	if travel.is_empty():
		return view.get("places", [])
	var to := str(travel["to"])
	if to in DIRECTIONS:
		return view.get("neighbours", {}).get(to, {}).get("places", [])
	for entry in view.get("visited", []):
		if entry is Dictionary and entry.get("square") == to:
			return entry.get("places", [])
	return []


## `places`: the place ids move_to and spawn may name, or null for the M1
## check against every allowed location.
static func _check_command(command: Variant, allowed: Dictionary, places: Variant) -> String:
	if not (command is Dictionary) or not COMMANDS.has(command.get("type", "")):
		return "Unknown command: %s" % str(command)
	var fields: Dictionary = COMMANDS[command["type"]]
	for field in fields:
		if typeof(command.get(field)) != fields[field]:
			return "%s: missing or wrong '%s'" % [command["type"], field]
	var here: Array = places if places is Array else allowed.get("locations", [])
	match command["type"]:
		"travel":
			if not command["to"] in allowed.get("travel", []):
				if command["to"] in DIRECTIONS:
					return "travel: the hero can't go %s from here" % command["to"]
				return "travel: '%s' is not another square the hero has visited" % command["to"]
		"move_to":
			if not command["target"] in here:
				if places is Array and command["target"] in allowed.get("locations", []):
					return "move_to: '%s' is not in this square" % command["target"]
				return "move_to: unknown place '%s'" % command["target"]
		"spawn":
			if not command["creature"] in allowed.get("creatures", []):
				return "spawn: unknown creature '%s'" % command["creature"]
			if command["near"] != "hero" and not command["near"] in here:
				if places is Array and command["near"] in allowed.get("locations", []):
					return "spawn: '%s' is not in this square" % command["near"]
				return "spawn: unknown place '%s'" % command["near"]
		"despawn":
			if not command["creature"] in allowed.get("creatures", []):
				return "despawn: unknown creature '%s'" % command["creature"]
		"weather":
			if not command["kind"] in WEATHER:
				return "weather: unknown kind '%s'" % command["kind"]
		"emote":
			if command["who"] != "hero" and not command["who"] in allowed.get("npcs", []):
				return "emote: unknown character '%s'" % command["who"]
			if not command["emote"] in EMOTES:
				return "emote: unknown emote '%s'" % command["emote"]
		"request_roll":
			if not command["skill"] in allowed.get("skills", []):
				return "request_roll: unknown skill '%s'" % command["skill"]
			if command["dc"] != floorf(command["dc"]):
				return "request_roll: DC must be a whole number"
			if command["dc"] < 5.0 or command["dc"] > 30.0:
				return "request_roll: DC must be between 5 and 30"
	return ""


static func _check_changes(changes: Dictionary, allowed: Dictionary, errors: Array) -> Dictionary:
	var ok := {}
	for key in changes:
		if not key in CHANGE_KEYS:
			errors.append("state: unknown key '%s' ignored." % str(key))
	for key in LIMITS:
		if not changes.has(key):
			continue
		if typeof(changes[key]) != TYPE_FLOAT:
			errors.append("%s must be a number." % key)
			continue
		var limits: Vector2i = LIMITS[key]
		var value := int(changes[key])
		if value < limits.x or value > limits.y:
			errors.append("%s = %d is out of range, clamped." % [key, value])
		ok[key] = clampi(value, limits.x, limits.y)

	var items: Array = []
	for item_id in _list(changes, "add_items", errors):
		if not item_id in allowed.get("items", []):
			errors.append("add_items: unknown item '%s'" % str(item_id))
		elif items.size() >= MAX_ADD_ITEMS:
			errors.append("add_items: more than %d items, '%s' dropped." % [MAX_ADD_ITEMS, item_id])
		else:
			items.append(item_id)
	if not items.is_empty():
		ok["add_items"] = items

	var quests: Array = []
	for quest in _list(changes, "quest_updates", errors):
		if _valid_quest_update(quest, allowed):
			quests.append({
				"id": quest["id"],
				"stage": int(quest["stage"]),
				"done": quest.get("done") == true,
			})
		else:
			errors.append("quest_updates: bad entry %s" % str(quest))
	if not quests.is_empty():
		ok["quest_updates"] = quests
	return ok


## A missing list is fine; null, a number or text instead of a list is noted.
static func _list(changes: Dictionary, key: String, errors: Array) -> Array:
	if not changes.has(key):
		return []
	if changes[key] is Array:
		return changes[key]
	errors.append("%s must be a list." % key)
	return []


static func _valid_quest_update(quest: Variant, allowed: Dictionary) -> bool:
	if not (quest is Dictionary) or not quest.get("id") in allowed.get("quests", []):
		return false
	var stage: Variant = quest.get("stage")
	if typeof(stage) != TYPE_FLOAT or stage < 0.0 or stage != floorf(stage):
		return false
	return not quest.has("done") or typeof(quest["done"]) == TYPE_BOOL
