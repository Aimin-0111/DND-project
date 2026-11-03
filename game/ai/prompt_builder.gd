class_name PromptBuilder
extends RefCounted
## Builds the AI prompt from most stable to least stable, so prompt caching can
## reuse the beginning. The language and the player action are last.

## allowed = {"locations": [...], "creatures": [...], "items": [...], "skills": [...], "quests": [...]}
## plus, with the world map, "travel": [...] and "map": {...}. The map view is
## taken out of the allowed ids and becomes its own MAP part.
static func build(state: Dictionary, action: String, rules: String, codex: String,
		allowed: Dictionary, language: String) -> Dictionary:
	var ids := allowed.duplicate()
	var map_view: Variant = ids.get("map")
	ids.erase("map")
	var visible_state := {
		"hero": state["hero"],
		"gold": state["gold"],
		"pack": state["pack"],
		"quests": state["quests"],
		"location": state["location"],
		"weather": state.get("weather", "clear"),
		"creatures": _creatures_here(state),
		"time": _clock(int(state["time_minutes"])),
	}
	return {
		"rules": rules,
		"codex": codex,
		"summary": str(state.get("story_summary", "")),
		"state": visible_state,
		"map": map_view if map_view is Dictionary else {},
		"allowed": ids,
		"last_roll": state.get("last_roll"),
		"turn": {"language": language, "action": action.strip_edges()},
	}


## Copy-paste mode needs everything as ONE block of text.
static func to_single_text(prompt: Dictionary) -> String:
	return "\n\n".join([
		"=== RULES ===\n" + str(prompt["rules"]),
		"=== CODEX ===\n" + str(prompt["codex"]),
		"=== STORY SO FAR ===\n" + str(prompt.get("summary", "")),
		"=== STATE ===\n" + JSON.stringify(prompt["state"], "\t"),
		"=== MAP ===\n" + _map_text(prompt.get("map")),
		"=== ALLOWED IDS ===\n" + JSON.stringify(prompt["allowed"], "\t"),
		"=== LAST ROLL ===\n" + _roll_text(prompt.get("last_roll")),
		"=== TURN INPUT ===\n" + JSON.stringify(prompt["turn"], "\t"),
	])


static func _map_text(view: Variant) -> String:
	if not (view is Dictionary) or view.is_empty():
		return "none"
	return JSON.stringify(view, "\t")


## Creatures in the hero's square only (the others stayed behind), without
## their stored tile.
static func _creatures_here(state: Dictionary) -> Array:
	var square := str(state.get("square", ""))
	var out: Array = []
	for creature in state.get("creatures", []):
		if creature is Dictionary and str(creature.get("square", "")) == square:
			out.append({"id": creature.get("id", ""), "near": creature.get("near", "")})
	return out


## The game rolled it last turn; the AI narrates the outcome, never rerolls.
static func _roll_text(roll: Variant) -> String:
	if not (roll is Dictionary):
		return "none"
	return JSON.stringify(roll, "\t")


static func _clock(minutes: int) -> String:
	var day := minutes / (24 * 60) + 1
	var hour := (minutes / 60) % 24
	return "Day %d, %02d:%02d" % [day, hour, minutes % 60]
