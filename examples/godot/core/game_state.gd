class_name GameState
extends RefCounted
## The whole game in ONE Dictionary, so it can be saved as JSON, copied for
## Rewind, and sent to the AI. Two ways to store state were considered:
##
##   Option A (used here): a plain Dictionary + JSON.
##     + Easy to save, read, diff, migrate and send to the AI.
##     - No type checking: a typo like state["hpp"] fails silently.
##
##   Option B: Godot Resources (.tres files with typed @export fields).
##     + Typed, editable in the Godot inspector.
##     - Harder to migrate, and NEVER load a .tres a player imports:
##       resource files can contain scripts, so an "imported save" could run code.

const VERSION := 3


static func new_game(seed_value: int) -> Dictionary:
	return {
		"version": VERSION,
		"seed": seed_value,
		"rng_state": 0,           # Dice.rng.state, saved after every roll
		"turn": 0,
		"time_minutes": 8 * 60,   # day 1, 08:00
		"location": "mill_road",
		"hero": {
			"name": "Kael",
			"class": "ranger",
			"level": 1,
			"xp": 0,
			"hp": 12,
			"hp_max": 12,
			"ac": 14,
			"abilities": {"str": 12, "dex": 16, "con": 13, "int": 10, "wis": 14, "cha": 8},
			"skills": {"Stealth": 5, "Survival": 4, "Perception": 4},
		},
		"gold": 10,
		"pack": [{"id": "rusty_sword", "qty": 1}, {"id": "healing_draught", "qty": 2}],
		"quests": {},             # quest_id -> {"stage": int, "done": bool}
		"story_summary": "",      # rolling summary refreshed by the cheap model
		"log": [],                # every action, for Rewind and replays
	}


## Changes the AI asked for, ALREADY checked by DmReplyParser.
## The game still clamps every value, in case a check was missed.
static func apply_changes(state: Dictionary, changes: Dictionary) -> void:
	# int(...) everywhere: after a JSON load, numbers are floats.
	var hero: Dictionary = state["hero"]
	if changes.has("hp_delta"):
		hero["hp"] = clampi(int(hero["hp"]) + int(changes["hp_delta"]), 0, int(hero["hp_max"]))
	if changes.has("gold_delta"):
		state["gold"] = maxi(0, int(state["gold"]) + int(changes["gold_delta"]))
	if changes.has("time_advance_minutes"):
		state["time_minutes"] = int(state["time_minutes"]) + clampi(int(changes["time_advance_minutes"]), 0, 24 * 60)
	for item_id in changes.get("add_items", []):
		_add_item(state, item_id, 1)
	for quest in changes.get("quest_updates", []):
		state["quests"][quest["id"]] = {"stage": int(quest["stage"]), "done": bool(quest.get("done", false))}


## Rewind: keep a copy before each turn. duplicate(true) copies nested
## arrays and dictionaries too, so the snapshot can't change later.
static func snapshot(state: Dictionary) -> Dictionary:
	return state.duplicate(true)


static func _add_item(state: Dictionary, item_id: String, qty: int) -> void:
	for entry in state["pack"]:
		if entry["id"] == item_id:
			entry["qty"] += qty
			return
	state["pack"].append({"id": item_id, "qty": qty})
