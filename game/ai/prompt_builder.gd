class_name PromptBuilder
extends RefCounted
## Builds the AI prompt from most stable to least stable, so prompt caching can
## reuse the beginning. The language and the player action are last.

## allowed = {"locations": [...], "creatures": [...], "items": [...], "skills": [...], "quests": [...]}
static func build(state: Dictionary, action: String, rules: String, codex: String,
		allowed: Dictionary, language: String) -> Dictionary:
	var visible_state := {
		"hero": state["hero"],
		"gold": state["gold"],
		"pack": state["pack"],
		"quests": state["quests"],
		"location": state["location"],
		"weather": state.get("weather", "clear"),
		"creatures": state.get("creatures", []),
		"time": _clock(int(state["time_minutes"])),
	}
	return {
		"rules": rules,
		"codex": codex,
		"summary": str(state.get("story_summary", "")),
		"state": visible_state,
		"allowed": allowed,
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
		"=== ALLOWED IDS ===\n" + JSON.stringify(prompt["allowed"], "\t"),
		"=== LAST ROLL ===\n" + _roll_text(prompt.get("last_roll")),
		"=== TURN INPUT ===\n" + JSON.stringify(prompt["turn"], "\t"),
	])


## The game rolled it last turn; the AI narrates the outcome, never rerolls.
static func _roll_text(roll: Variant) -> String:
	if not (roll is Dictionary):
		return "none"
	return JSON.stringify(roll, "\t")


static func _clock(minutes: int) -> String:
	var day := minutes / (24 * 60) + 1
	var hour := (minutes / 60) % 24
	return "Day %d, %02d:%02d" % [day, hour, minutes % 60]
