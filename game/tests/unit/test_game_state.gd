extends RefCounted
## Version-1 state shape, clamping and deep snapshots.


func run() -> Array:
	var failures: Array = []
	var state := GameState.new_game(42)

	if int(state["version"]) != 1:
		failures.append("version: expected 1")
	if state["language"] != "fr":
		failures.append("default language should be fr")
	if int(state["hero"]["hp"]) != 12:
		failures.append("starting HP should be 12")
	if state["hero"]["name_key"] != "hero.kael.name":
		failures.append("hero name key is wrong")

	GameState.apply_changes(state, {"hp_delta": -5})
	if int(state["hero"]["hp"]) != 7:
		failures.append("hp_delta -5 should leave 7 HP, got %s" % str(state["hero"]["hp"]))
	GameState.apply_changes(state, {"hp_delta": 100})
	if int(state["hero"]["hp"]) != 12:
		failures.append("HP should clamp to hp_max")
	GameState.apply_changes(state, {"gold_delta": -100})
	if int(state["gold"]) != 0:
		failures.append("gold should clamp to 0")
	GameState.apply_changes(state, {"time_advance_minutes": 60})
	if int(state["time_minutes"]) != 9 * 60:
		failures.append("time should advance by 60 minutes")

	GameState.apply_changes(state, {
		"add_items": ["healing_draught", "brass_key"],
		"quest_updates": [{"id": "the_silent_mill", "stage": 1, "done": false}],
	})
	if int(state["pack"][1]["qty"]) != 3:
		failures.append("existing pack item should stack")
	if state["pack"].size() != 3:
		failures.append("new item should be appended")
	if int(state["quests"]["the_silent_mill"]["stage"]) != 1:
		failures.append("quest stage should update")

	var copy := GameState.snapshot(state)
	copy["hero"]["hp"] = 1
	if int(state["hero"]["hp"]) != 12:
		failures.append("snapshot must be a deep copy")

	if not "Stealth" in GameState.allowed_skills(state):
		failures.append("Stealth should be an allowed skill")

	return failures
