class_name GameState
extends RefCounted
## The whole game in one JSON-serializable Dictionary. Version 1 is the M1
## shape; any shape change bumps VERSION and adds a migration in SaveSystem.

const VERSION := 1
const MAX_CREATURES := 6
const MAX_QTY := 99
const MAX_TIME_ADVANCE := 24 * 60
## Every skill the DM may ask a roll for, and the ability it falls back to.
const SKILL_ABILITY := {
	"Athletics": "str", "Acrobatics": "dex", "Stealth": "dex", "Perception": "wis",
	"Investigation": "int", "Persuasion": "cha", "Insight": "wis", "Survival": "wis",
}
const CHANGE_KEYS := ["hp_delta", "gold_delta", "time_advance_minutes", "add_items", "quest_updates"]
const STORY_ENTRIES := 3
const STORY_ENTRY_CHARS := 600
const STORY_SEPARATOR := "\n---\n"


static func new_game(seed_value: int) -> Dictionary:
	return {
		"version": VERSION,
		"seed": seed_value,
		"rng_state": 0,
		"turn": 0,
		"time_minutes": 8 * 60,
		"location": "mill_road",
		"weather": "clear",
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
		"creatures": [],
		"last_roll": null,
		"story_summary": "",
		"log": [],
	}


## Applies changes already checked by DmReplyParser. The game clamps again so
## a missed check can never create negative HP, negative gold or a bad stage.
## Returns notes about anything ignored.
static func apply_changes(state: Dictionary, changes: Dictionary) -> Array:
	var notes: Array = []
	for key in changes:
		if not key in CHANGE_KEYS:
			notes.append("Unknown change '%s' ignored." % str(key))
	var hero: Dictionary = state["hero"]
	if changes.has("hp_delta"):
		hero["hp"] = clampi(int(hero["hp"]) + int(changes["hp_delta"]), 0, int(hero["hp_max"]))
	if changes.has("gold_delta"):
		state["gold"] = maxi(0, int(state["gold"]) + int(changes["gold_delta"]))
	if changes.has("time_advance_minutes"):
		var minutes := clampi(int(changes["time_advance_minutes"]), 0, MAX_TIME_ADVANCE)
		state["time_minutes"] = int(state["time_minutes"]) + minutes
	for item in changes.get("add_items", []):
		if item is String or item is StringName:
			_add_item(state, str(item), 1)
	for quest in changes.get("quest_updates", []):
		if quest is Dictionary and quest.has("id"):
			_update_quest(state, str(quest["id"]), int(quest.get("stage", 0)), quest.get("done") == true)
	return notes


## State side of the checked commands; the world plays them afterwards.
## last_roll is cleared first: it was sent in this turn's prompt.
static func apply_commands(state: Dictionary, commands: Array, dice: Dice) -> Array:
	var notes: Array = []
	state["last_roll"] = null
	for command in commands:
		match str(command.get("type", "")):
			"move_to":
				state["location"] = str(command["target"])
			"spawn":
				if state["creatures"].size() >= MAX_CREATURES:
					notes.append("spawn: already %d creatures, '%s' refused." % [MAX_CREATURES, command["creature"]])
				else:
					state["creatures"].append({"id": str(command["creature"]), "near": str(command["near"])})
			"despawn":
				if not _remove_last_creature(state, str(command["creature"])):
					notes.append("despawn: no '%s' present." % command["creature"])
			"weather":
				state["weather"] = str(command["kind"])
			"request_roll":
				var skill := str(command["skill"])
				var result := skill_check(state, skill, int(command["dc"]), dice)
				result["skill"] = skill
				state["last_roll"] = result
	return notes


## d20 + modifier against a difficulty. The game rolls; the AI never does.
static func skill_check(state: Dictionary, skill: String, dc: int, dice: Dice) -> Dictionary:
	return dice.check(skill_modifier(state["hero"], skill), dc)


static func skill_modifier(hero: Dictionary, skill: String) -> int:
	if hero["skills"].has(skill):
		return int(hero["skills"][skill])   # int(): JSON numbers load as floats
	var score := int(hero["abilities"][SKILL_ABILITY.get(skill, "wis")])
	return floori((score - 10) / 2.0)


## M1 "story so far": the last few narrations, each cut short, so the AI
## remembers recent turns without a growing transcript.
static func remember_narration(state: Dictionary, narration: String) -> void:
	var recent := str(state.get("story_summary", "")).split(STORY_SEPARATOR, false)
	recent.append(narration.strip_edges().left(STORY_ENTRY_CHARS))
	while recent.size() > STORY_ENTRIES:
		recent.remove_at(0)
	state["story_summary"] = STORY_SEPARATOR.join(recent)


## Fills the fields a Beta-0.1 save didn't have yet (same version 1).
static func fill_defaults(state: Dictionary) -> Dictionary:
	if not state.has("weather"):
		state["weather"] = "clear"
	if not (state.get("creatures") is Array):
		state["creatures"] = []
	if not state.has("last_roll"):
		state["last_roll"] = null
	return state


## Deep copy used by Rewind and tests.
static func snapshot(state: Dictionary) -> Dictionary:
	return state.duplicate(true)


## Skills the DM may use in request_roll: the full list, not only the
## hero's trained ones (the others use the ability modifier).
static func allowed_skills(_state: Dictionary) -> Array:
	return SKILL_ABILITY.keys()


static func _add_item(state: Dictionary, item_id: String, qty: int) -> void:
	if qty <= 0:
		return
	for entry in state["pack"]:
		if str(entry.get("id", "")) == item_id:
			entry["qty"] = mini(int(entry.get("qty", 0)) + qty, MAX_QTY)
			return
	state["pack"].append({"id": item_id, "qty": mini(qty, MAX_QTY)})


## A stage never goes down and a finished quest stays finished.
static func _update_quest(state: Dictionary, quest_id: String, stage: int, done: bool) -> void:
	var current: Dictionary = state["quests"].get(quest_id, {"stage": 0, "done": false})
	state["quests"][quest_id] = {
		"stage": maxi(int(current.get("stage", 0)), stage),
		"done": bool(current.get("done", false)) or done,
	}


static func _remove_last_creature(state: Dictionary, creature_id: String) -> bool:
	var creatures: Array = state["creatures"]
	for i in range(creatures.size() - 1, -1, -1):
		if str(creatures[i].get("id", "")) == creature_id:
			creatures.remove_at(i)
			return true
	return false
