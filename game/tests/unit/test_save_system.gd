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

	SaveSystem.delete_save(SLOT)
	return failures
