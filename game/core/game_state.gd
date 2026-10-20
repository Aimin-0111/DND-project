class_name GameState
extends RefCounted
## The whole game in one JSON-serializable Dictionary. Version 1 is the M1
## shape; any shape change bumps VERSION and adds a migration in SaveSystem.

const VERSION := 1


static func new_game(seed_value: int) -> Dictionary:
	return {
		"version": VERSION,
		"seed": seed_value,
		"rng_state": 0,
		"turn": 0,
		"time_minutes": 8 * 60,
		"location": "mill_road",
		"language": "fr",
		"hero": {
			"name_key": "hero.kael.name",
			"hp": 12,
			"hp_max": 12,
			"ac": 14,
			"abilities": {"str": 12, "dex": 16, "con": 13, "int": 10, "wis": 14, "cha": 8},
			"skills": {"Stealth": 5, "Survival": 4, "Perception": 4},
		},
		"gold": 10,
		"pack": [
			{"id": "rusty_sword", "qty": 1},
			{"id": "healing_draught", "qty": 2},
		],
		"quests": {
			"the_silent_mill": {"stage": 0, "done": false},
		},
		"story_summary": "",
		"log": [],
	}


## Applies changes already checked by DmReplyParser. The game clamps again so
## a missed check can never create negative HP, negative gold or a bad stage.
static func apply_changes(state: Dictionary, changes: Dictionary) -> void:
	var hero: Dictionary = state["hero"]
	if changes.has("hp_delta"):
		hero["hp"] = clampi(int(hero["hp"]) + int(changes["hp_delta"]), 0, int(hero["hp_max"]))
	if changes.has("gold_delta"):
		state["gold"] = maxi(0, int(state["gold"]) + int(changes["gold_delta"]))
	if changes.has("time_advance_minutes"):
		state["time_minutes"] = int(state["time_minutes"]) + maxi(0, int(changes["time_advance_minutes"]))
	for item in changes.get("add_items", []):
		if item is String or item is StringName:
			_add_item(state, str(item), 1)
	for quest in changes.get("quest_updates", []):
		if quest is Dictionary and quest.has("id"):
			state["quests"][str(quest["id"])] = {
				"stage": maxi(0, int(quest.get("stage", 0))),
				"done": bool(quest.get("done", false)),
			}


## Deep copy used by Rewind and tests.
static func snapshot(state: Dictionary) -> Dictionary:
	return state.duplicate(true)


## Skills the DM may use in request_roll.
static func allowed_skills(state: Dictionary) -> Array:
	return state["hero"]["skills"].keys()


static func _add_item(state: Dictionary, item_id: String, qty: int) -> void:
	if qty <= 0:
		return
	for entry in state["pack"]:
		if str(entry.get("id", "")) == item_id:
			entry["qty"] = int(entry.get("qty", 0)) + qty
			return
	state["pack"].append({"id": item_id, "qty": qty})
