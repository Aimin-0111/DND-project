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

	failures.append_array(_rules_checks())
	failures.append_array(_command_checks())
	failures.append_array(_story_checks())
	return failures


func _rules_checks() -> Array:
	var failures: Array = []
	var state := GameState.new_game(42)
	for key in ["weather", "creatures", "last_roll"]:
		if not state.has(key):
			failures.append("state v1 is missing '%s'" % key)

	GameState.apply_changes(state, {"quest_updates": [{"id": "the_silent_mill", "stage": 2, "done": true}]})
	GameState.apply_changes(state, {"quest_updates": [{"id": "the_silent_mill", "stage": 1, "done": false}]})
	var quest: Dictionary = state["quests"]["the_silent_mill"]
	if int(quest["stage"]) != 2 or not quest["done"]:
		failures.append("a quest must never go back: %s" % str(quest))

	state["pack"][0]["qty"] = 99
	GameState.apply_changes(state, {"add_items": ["rusty_sword"]})
	if int(state["pack"][0]["qty"]) != 99:
		failures.append("qty should never exceed 99")

	var before := int(state["time_minutes"])
	GameState.apply_changes(state, {"time_advance_minutes": 2000})
	GameState.apply_changes(state, {"time_advance_minutes": -50})
	if int(state["time_minutes"]) != before + 1440:
		failures.append("time should clamp to 0..1440 per turn")

	var notes := GameState.apply_changes(state, {"xp_delta": 50})
	if notes.size() != 1:
		failures.append("unknown change keys should be reported")

	if GameState.skill_modifier(state["hero"], "Stealth") != 5:
		failures.append("a listed skill uses the hero's value")
	if GameState.skill_modifier(state["hero"], "Athletics") != 1:
		failures.append("Athletics should fall back to the STR modifier (+1)")
	if GameState.skill_modifier(state["hero"], "Persuasion") != -1:
		failures.append("Persuasion should fall back to the CHA modifier (-1)")
	return failures


func _command_checks() -> Array:
	var failures: Array = []
	var state := GameState.new_game(42)
	var dice := Dice.new(42)
	var notes := GameState.apply_commands(state, [
		{"type": "move_to", "target": "old_mill"},
		{"type": "weather", "kind": "fog"},
		{"type": "request_roll", "skill": "Stealth", "dc": 13},
	], dice)
	if not notes.is_empty():
		failures.append("valid commands should not be noted: %s" % str(notes))
	if state["location"] != "old_mill":
		failures.append("move_to should set the location")
	if state["weather"] != "fog":
		failures.append("weather should be stored")
	var roll: Variant = state["last_roll"]
	if not (roll is Dictionary):
		failures.append("request_roll should fill last_roll")
	else:
		for key in ["skill", "dc", "d20", "modifier", "total", "success"]:
			if not roll.has(key):
				failures.append("last_roll is missing '%s'" % key)
		if roll.get("modifier") != 5 or roll.get("total") != int(roll.get("d20", 0)) + 5:
			failures.append("Stealth roll should add the +5 skill: %s" % str(roll))
		var same := Dice.new(42).check(5, 13)
		if roll.get("d20") != same["d20"]:
			failures.append("the same seed should give the same roll")

	GameState.apply_commands(state, [], dice)
	if state["last_roll"] != null:
		failures.append("last_roll should clear on the next turn")

	var spawns: Array = []
	for i in 7:
		spawns.append({"type": "spawn", "creature": "rust_wolf", "near": "mill_bridge"})
	notes = GameState.apply_commands(state, spawns, dice)
	if state["creatures"].size() != 6 or notes.size() != 1:
		failures.append("a 7th creature should be refused and noted")

	state["creatures"][5]["near"] = "old_mill"
	GameState.apply_commands(state, [{"type": "despawn", "creature": "rust_wolf"}], dice)
	if state["creatures"].size() != 5 or state["creatures"][-1]["near"] != "mill_bridge":
		failures.append("despawn should remove the most recent creature with that id")
	state["creatures"].clear()
	notes = GameState.apply_commands(state, [{"type": "despawn", "creature": "rust_wolf"}], dice)
	if notes.size() != 1:
		failures.append("despawn with no creature present should be noted")
	return failures


func _story_checks() -> Array:
	var failures: Array = []
	var state := GameState.new_game(42)
	for i in 4:
		GameState.remember_narration(state, "Turn %d. " % i + "x".repeat(700))
	var summary := str(state["story_summary"])
	if "Turn 0." in summary or not "Turn 3." in summary:
		failures.append("story so far should keep only the last 3 narrations")
	if summary.length() > 3 * 600 + 2 * GameState.STORY_SEPARATOR.length():
		failures.append("each narration should be cut to 600 characters")
	return failures
