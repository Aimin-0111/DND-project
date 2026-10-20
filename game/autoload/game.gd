extends Node
## Autoload: the current state, dice and save/load.
## Content stays in the Content autoload; DM owns the AI turn.

signal state_changed(state: Dictionary)

var state: Dictionary = {}
var dice: Dice
var _started := false


func _ready() -> void:
	ensure_started()


## Lazy start keeps the autoload usable from headless tests.
func ensure_started(seed_value: int = 12345) -> void:
	if _started:
		return
	new_game(seed_value)


func new_game(seed_value: int = 12345) -> void:
	_started = true
	dice = Dice.new(seed_value)
	state = GameState.new_game(seed_value)
	state["language"] = Content.language()
	Content.set_language(state["language"])
	state["rng_state"] = dice.state()
	state_changed.emit(state)


## One checked turn: state changes, then the state side of the commands
## (requested rolls happen here). Returns notes about anything refused.
func apply_turn(changes: Dictionary, commands: Array) -> Array:
	var notes := GameState.apply_changes(state, changes)
	notes.append_array(GameState.apply_commands(state, commands, dice))
	state["turn"] = int(state.get("turn", 0)) + 1
	state["rng_state"] = dice.state()
	state_changed.emit(state)
	return notes


func allowed_ids() -> Dictionary:
	var ids := Content.allowed_ids()
	ids["skills"] = GameState.allowed_skills(state)
	return ids


func save(slot: String) -> Error:
	state["rng_state"] = dice.state()
	return SaveSystem.save_game(state, slot)


func load(slot: String) -> bool:
	var loaded := SaveSystem.load_game(slot)
	if loaded.is_empty():
		return false
	state = loaded
	dice = Dice.new(int(state.get("seed", 0)))
	dice.restore_state(int(state.get("rng_state", 0)))
	Content.set_language(str(state.get("language", "fr")))
	state_changed.emit(state)
	return true


func set_location(location_id: String) -> void:
	state["location"] = location_id
	state_changed.emit(state)


func set_language(lang: String) -> void:
	state["language"] = lang
	Content.set_language(lang)
	state_changed.emit(state)
