class_name PromptBuilder
extends RefCounted
## Builds what the AI receives each turn, ordered from MOST stable to LEAST
## stable. That order matters for cost: Claude's prompt caching reuses the
## unchanged beginning of a prompt at a fraction of the price.
##
##   1. rules   - the DM's instructions (content/writing/dm-rules.md). Never changes.
##   2. codex   - lore, places, NPCs of this campaign. Changes rarely.
##   3. summary - rolling "story so far", refreshed every few turns.
##   4. state   - HP, gold, place, time, quests. Changes every turn.
##   5. action  - what the player just did.
##
## The AI also gets the ids it may use (locations, creatures, items, skills,
## quests), so its commands can point at things that exist. DmReplyParser
## checks the reply against the same lists.


## allowed = {"locations": [...], "creatures": [...], "items": [...], "skills": [...], "quests": [...]}
static func build(state: Dictionary, action: String, rules: String, codex: String,
		allowed: Dictionary) -> Dictionary:
	var visible_state := {
		"hero": state["hero"],
		"gold": state["gold"],
		"pack": state["pack"],
		"quests": state["quests"],
		"location": state["location"],
		"time": _clock(int(state["time_minutes"])),
	}
	return {
		"rules": rules,
		"codex": codex,
		"summary": state["story_summary"],
		"state": visible_state,
		"allowed": allowed,
		"action": action,
	}


## Copy-paste mode needs everything as ONE block of text.
static func to_single_text(prompt: Dictionary) -> String:
	return "\n\n".join([
		prompt["rules"],
		"=== CODEX ===\n" + prompt["codex"],
		"=== STORY SO FAR ===\n" + prompt["summary"],
		"=== STATE ===\n" + JSON.stringify(prompt["state"]),
		"=== ALLOWED IDS ===\n" + JSON.stringify(prompt["allowed"]),
		"=== PLAYER ACTION ===\n" + prompt["action"],
	])


static func _clock(minutes: int) -> String:
	var day := minutes / (24 * 60) + 1
	var hour := (minutes / 60) % 24
	return "Day %d, %02d:%02d" % [day, hour, minutes % 60]
