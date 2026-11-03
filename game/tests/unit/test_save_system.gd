extends RefCounted
## Save/load round-trip, invalid input and slot safety.

const SLOT := "__test_save_roundtrip"


func run() -> Array:
	var failures: Array = []
	SaveSystem.delete_save(SLOT)

	var state := GameState.new_game(1234)
	state["gold"] = 37
	state["language"] = "en"
	state["hero"]["hp"] = 5

	if SaveSystem.save_game(state, SLOT) != OK:
		failures.append("save_game should succeed")
	else:
		var loaded := SaveSystem.load_game(SLOT)
		if loaded.is_empty():
			failures.append("load_game returned an empty save")
		else:
			if int(loaded.get("gold", 0)) != 37:
				failures.append("gold did not survive the round-trip")
			if int(loaded["hero"]["hp"]) != 5:
				failures.append("HP did not survive the round-trip")
			if loaded.get("language") != "en":
				failures.append("language did not survive the round-trip")

	if not SaveSystem.import_save_text("not json").is_empty():
		failures.append("invalid JSON should be rejected")
	if not SaveSystem.import_save_text('{"version": 99}').is_empty():
		failures.append("future save version should be rejected")
	if not SaveSystem.import_save_text('{"version": 0}').is_empty():
		failures.append("version 0 should be rejected")

	if SaveSystem.save_game(state, "../evil") != ERR_INVALID_PARAMETER:
		failures.append("path traversal slot should be rejected")

	# A Beta-0.1 save (version 1, before weather/creatures/last_roll) still loads.
	var old := GameState.new_game(1234)
	old["version"] = 1
	for key in ["weather", "creatures", "last_roll", "square", "hero_cell", "squares"]:
		old.erase(key)
	var migrated := SaveSystem.import_save_text(JSON.stringify(old))
	if migrated.get("weather") != "clear" or migrated.get("creatures") != [] or not migrated.has("last_roll"):
		failures.append("a Beta-0.1 save should get the new fields: %s" % str(migrated.keys()))

	# A Beta-0.2 save (version 1, one zone) becomes version 2. The square and
	# the hero's tile are filled by WorldState.settle (test_world_state.gd).
	var beta_02 := '{"version": 1, "seed": 5, "rng_state": 9, "turn": 3, "time_minutes": 500, "location": "old_mill", "weather": "fog", "language": "en", "hero": {"hp": 7, "hp_max": 12}, "gold": 4, "pack": [], "quests": {}, "creatures": [{"id": "rust_wolf", "near": "mill_bridge"}], "last_roll": null, "story_summary": "", "log": []}'
	var v2 := SaveSystem.import_save_text(beta_02)
	if int(v2.get("version", 0)) != 2:
		failures.append("a version 1 save should migrate to version 2, got %s" % str(v2.get("version")))
	elif v2.get("square") != "" or v2.get("hero_cell") != [] or v2.get("squares") != {}:
		failures.append("the v1 -> v2 migration should add an empty square, hero_cell and squares: %s" % str(v2))
	elif v2["creatures"][0].get("square") != "" or v2.get("location") != "old_mill" or v2.get("weather") != "fog":
		failures.append("the migration should keep the v1 data and give creatures a square field: %s" % str(v2))

	state["creatures"] = [{"id": "rust_wolf", "near": "mill_bridge"}]
	state["weather"] = "rain"
	if SaveSystem.save_game(state, SLOT) == OK:
		var loaded := SaveSystem.load_game(SLOT)
		if loaded.get("creatures", []).size() != 1 or loaded.get("weather") != "rain":
			failures.append("creatures and weather should survive save/load")

	SaveSystem.delete_save(SLOT)
	return failures
