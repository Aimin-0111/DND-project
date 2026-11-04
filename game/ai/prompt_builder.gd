class_name PromptBuilder
extends RefCounted
## Builds the AI prompt from most stable to least stable, so prompt caching can
## reuse the beginning. The language and the player action are last.

const RULES_HEADER := "=== RULES ==="
const TURN_INPUT_HEADER := "=== TURN INPUT ==="

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
		RULES_HEADER + "\n" + str(prompt["rules"]),
		"=== CODEX ===\n" + str(prompt["codex"]),
		"=== STORY SO FAR ===\n" + str(prompt.get("summary", "")),
		"=== STATE ===\n" + JSON.stringify(prompt["state"], "\t"),
		"=== MAP ===\n" + _map_text(prompt.get("map")),
		"=== ALLOWED IDS ===\n" + JSON.stringify(prompt["allowed"], "\t"),
		"=== LAST ROLL ===\n" + _roll_text(prompt.get("last_roll")),
		TURN_INPUT_HEADER + "\n" + JSON.stringify(prompt["turn"], "\t"),
	])


## True when `text` is the game's own copy-paste prompt (bug B2): it holds the
## TURN INPUT header or starts with the RULES header. A player who pastes the
## prompt back instead of the DM's reply gets "That's the prompt" rather than
## screens of rules read as narration (the rules quote the <<STATE>> marker).
static func is_prompt_text(text: String) -> bool:
	return text.contains(TURN_INPUT_HEADER) or text.strip_edges().begins_with(RULES_HEADER)


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
