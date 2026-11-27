extends RefCounted
## The story panel's status line follows DM.status_changed (SPEC-main-screen):
## - copy-paste still shows "Waiting for the AI DM"; Cancel then shows "Turn
##   cancelled." and "Ready", not an error (bug B4);
## - an own-key turn with no key shows "No API key set…" on the status line and
##   in the story (not "Error: …"), in both languages, gives the typed text back
##   and changes nothing; at an exit the hero also steps back;
## - a fake own-key connection shows "Waiting for the AI DM" while it runs, and
##   its cut-off warning stays under the narration.
## No network: the fake key, a test settings file, and the autosave restored.

const TEST_SETTINGS := "user://__test_status_line.cfg"
const FAKE_KEY := "FAKE-KEY-FOR-TESTS"
const START := "sq_24_24"
const REPLY := "The planks creak but hold.\n\n<<STATE>>\n{\"commands\": [], \"state\": {}}"


## Own-key stand-in with no network: says it is waiting, waits for released,
## then answers with a reply that was cut off.
class FakeOwnKey:
	extends OwnKeyAdapter
	signal released
	var reply := ""
	var started := false

	func generate_turn(_prompt: Dictionary) -> String:
		last_status = ""
		started = true
		status_changed.emit(_translate("ui.waiting"))
		await released
		return _finish(reply, STATUS_CUT_OFF)


func run() -> Array:
	var failures: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["no SceneTree available"]
	var content = tree.root.get_node("Content")
	var dm = tree.root.get_node("DM")
	var real_settings: String = content.settings_path
	var start_language: String = content.language()
	content.settings_path = TEST_SETTINGS
	DirAccess.remove_absolute(TEST_SETTINGS)
	content.remember_language()
	var autosave: Variant = _backup("auto")
	Game.new_game(12345)
	var main = load("res://main.tscn").instantiate()
	tree.root.add_child(main)
	var statuses: Array = []
	var on_status := func(message: String) -> void: statuses.append(message)
	dm.status_changed.connect(on_status)

	failures.append_array(_copy_paste_checks(main))
	for lang in Content.LANGUAGES:
		content.set_language(lang)
		failures.append_array(_no_key_checks(main, statuses, lang))
	content.set_language(start_language)
	failures.append_array(_exit_failure_checks(main))
	failures.append_array(_fake_connection_checks(main, dm, statuses))
	if main.find_child("AiNotice", true, false) != null:
		failures.append("the bars should have no own-key message line any more")

	dm.status_changed.disconnect(on_status)
	tree.root.remove_child(main)
	main.free()
	_restore("auto", autosave)
	DirAccess.remove_absolute(TEST_SETTINGS)
	content.settings_path = real_settings
	Game.new_game(12345)
	return failures


## Copy-paste mode: "Waiting for the AI DM" (translated) while the paste
## window is open, then "Turn cancelled." and "Ready" on Cancel (bug B4).
func _copy_paste_checks(main) -> Array:
	var failures: Array = []
	_write_settings(SettingsStore.MODE_COPY_PASTE, "")
	main.action_input.text = "I knock."
	main._on_act()
	if not main.dialog.visible:
		failures.append("copy-paste mode should open the paste window")
	if main.status_label.text != Content.t("ui.waiting"):
		failures.append("copy-paste: the status line should say '%s', got '%s'" % [Content.t("ui.waiting"), main.status_label.text])
	var before: String = main.story_log.get_parsed_text()
	main.dialog._on_cancel()
	var added: String = main.story_log.get_parsed_text().substr(before.length())
	if main.status_label.text != Content.t("ui.ready") or not added.contains(Content.t("ui.turn_cancelled")) or added.contains(Content.t("ui.error")):
		failures.append("copy-paste Cancel should show 'Turn cancelled.' and 'Ready', got '%s' / '%s'" % [main.status_label.text, added.strip_edges()])
	if main._busy or main.action_input.text != "I knock.":
		failures.append("copy-paste Cancel should unlock and give the typed text back")
	return failures


## Own key, no key saved: the turn fails at once (no network) with the no-key
## message in the player's language.
func _no_key_checks(main, statuses: Array, lang: String) -> Array:
	var failures: Array = []
	_write_settings(SettingsStore.MODE_OWN_KEY, "")
	statuses.clear()
	var before_state := _snapshot()
	var before: String = main.story_log.get_parsed_text()
	main.action_input.text = "I cross the bridge."
	main._on_act()
	var no_key: String = Content.t_in(OwnKeyAdapter.STATUS_NO_KEY, lang)
	var added: String = main.story_log.get_parsed_text().substr(before.length())
	if main._busy:
		failures.append("%s: a turn with no key should end at once and unlock" % lang)
	if not statuses.has(no_key):
		failures.append("%s: DM.status_changed should carry the no-key message: %s" % [lang, str(statuses)])
	if main.status_label.text != no_key:
		failures.append("%s: the status line should show '%s', got '%s'" % [lang, no_key, main.status_label.text])
	if not added.contains("> I cross the bridge.") or not added.contains(no_key):
		failures.append("%s: the story should show the action, then the no-key message: '%s'" % [lang, added.strip_edges()])
	if added.contains(Content.t_in("ui.error", lang) + ":"):
		failures.append("%s: an own-key failure should not show the generic 'Error: …'" % lang)
	if main.action_input.text != "I cross the bridge.":
		failures.append("%s: a failed turn should give the typed text back" % lang)
	if _snapshot() != before_state:
		failures.append("%s: a failed turn should change nothing" % lang)
	if main.status_label.get_minimum_size().x > 200.0:
		failures.append("%s: the status line should wrap, not widen the story panel (min width %d)" % [lang, int(main.status_label.get_minimum_size().x)])
	return failures


## The same failure on the automatic travel turn: the hero steps back one tile
## and the typed text comes back.
func _exit_failure_checks(main) -> Array:
	var failures: Array = []
	_write_settings(SettingsStore.MODE_OWN_KEY, "")
	main.world.place_hero(Vector2i(31, 0))
	main.action_input.text = "carefully"
	main._on_walk_ended(Vector2i(31, 0))
	if main._busy:
		failures.append("a failed exit turn should unlock")
	if Game.state["hero_cell"] != [31, 1] or Game.state["square"] != START:
		failures.append("a failed exit turn steps the hero back one tile: %s" % str(Game.state["hero_cell"]))
	if main.action_input.text != "carefully":
		failures.append("a failed exit turn gives the typed text back, got '%s'" % main.action_input.text)
	if main.status_label.text != Content.t(OwnKeyAdapter.STATUS_NO_KEY):
		failures.append("a failed exit turn shows its message, got '%s'" % main.status_label.text)
	return failures


## A fake own-key connection: "Waiting…" while the request runs, then a reply
## that was cut off. The warning shows while the text types and stays in the
## story under the narration.
func _fake_connection_checks(main, dm, statuses: Array) -> Array:
	var failures: Array = []
	_write_settings(SettingsStore.MODE_OWN_KEY, FAKE_KEY)
	var real_own_key = dm.own_key
	var fake := FakeOwnKey.new()
	fake.reply = REPLY
	dm.add_child(fake)
	fake.status_changed.connect(func(message: String) -> void: dm.status_changed.emit(message))
	dm.own_key = fake
	statuses.clear()

	var before: String = main.story_log.get_parsed_text()
	main.action_input.text = "I cross the bridge."
	main._on_act()
	if not fake.started or not main._busy:
		failures.append("own-key mode should use the connection and lock the turn")
	if main.dialog.visible:
		failures.append("own-key mode should not open the paste window")
	if main.status_label.text != Content.t("ui.waiting"):
		failures.append("while the request runs the status line should say '%s', got '%s'" % [Content.t("ui.waiting"), main.status_label.text])

	fake.released.emit()
	var cut_off := Content.t(OwnKeyAdapter.STATUS_CUT_OFF)
	if main.status_label.text != cut_off:
		failures.append("while the cut reply types, the status line should show '%s', got '%s'" % [cut_off, main.status_label.text])
	main.story_log.skip_typing()
	var added: String = main.story_log.get_parsed_text().substr(before.length())
	var narration_at := added.find("The planks creak but hold.")
	if narration_at < 0 or added.find(cut_off) < narration_at:
		failures.append("the cut-off warning should stay in the story under the narration: '%s'" % added.strip_edges())
	if main._busy:
		failures.append("the turn should end and unlock")
	if main.status_label.text != Content.t("ui.saved"):
		failures.append("the turn should end with '%s' as before, got '%s'" % [Content.t("ui.saved"), main.status_label.text])
	if statuses != [Content.t("ui.waiting"), cut_off]:
		failures.append("DM.status_changed should carry 'waiting' then 'cut off': %s" % str(statuses))

	dm.own_key = real_own_key
	dm.remove_child(fake)
	fake.free()
	return failures


func _write_settings(mode: String, key: String) -> void:
	var settings := SettingsStore.read(TEST_SETTINGS)
	settings.path = TEST_SETTINGS
	settings.mode = mode
	settings.api_key = key
	settings.write()


func _snapshot() -> String:
	var state: Dictionary = Game.state
	return JSON.stringify([state["hero"], state["gold"], state["time_minutes"], state.get("square"), state.get("turn")])


## The test turn autosaves: keep the player's own autosave as it was.
func _backup(slot: String) -> Variant:
	var path := SaveSystem._path(slot)
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_bytes(path)


func _restore(slot: String, data: Variant) -> void:
	var path := SaveSystem._path(slot)
	if data == null:
		DirAccess.remove_absolute(path)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()
