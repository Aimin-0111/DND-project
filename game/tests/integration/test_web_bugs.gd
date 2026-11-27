extends RefCounted
## Bugs B1–B8 of docs/BETA-0.3-WEB-CHECK.md, on the real main scene
## (SPEC-main-screen: "Beta-0.3 web fixes"; SPEC-dm: a pasted prompt).
## - B1: opening the paste window doesn't touch the clipboard; Copy prompt
##   copies; Ctrl+V and Paste insert what the clipboard holds now (a fake
##   clipboard stands in for the browser's);
## - B2: a pasted prompt is refused like a failed turn;
## - B3: the paste window follows the language;
## - B4: Cancel shows "Turn cancelled." and "Ready", not "Error";
## - B5: the demo line waits for the first-launch language;
## - B6: Esc cancels the paste window;
## - B7: Load picks the newer save;
## - B8: starting with a save resumes it, in the device's language.
## The runner points the save folder at a test folder; settings are a test file.

const TEST_SETTINGS := "user://__test_web_bugs.cfg"
const REPLY := "The wheel turns slowly.\n\n<<STATE>>\n{\"commands\": [], \"state\": {}}"
const DEMO_KEY := "story.demo_line"

## Stands in for the system clipboard: records writes, answers reads.
class FakeClipboard:
	var text := ""
	var writes: Array = []
	## false = the browser refused the read.
	var allowed := true
	## What the game's own (maybe stale) copy holds when a read is refused.
	var cached := ""

	func write(value: String) -> void:
		writes.append(value)
		text = value
		cached = value

	func read(done: Callable) -> void:
		if allowed:
			done.call(text, true)
		else:
			done.call("", false)

	func read_cached() -> String:
		return cached


func run() -> Array:
	var failures: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["no SceneTree available"]
	var content = tree.root.get_node("Content")
	var real_settings: String = content.settings_path
	var start_language: String = content.language()
	content.settings_path = TEST_SETTINGS

	failures.append_array(_first_launch_checks(tree, content))
	content.set_language("en")
	content.remember_language()
	failures.append_array(_paste_window_checks(tree, content))
	failures.append_array(_load_checks(tree, content))
	failures.append_array(_resume_checks(tree, content))

	DirAccess.remove_absolute(TEST_SETTINGS)
	for slot in ["manual", "auto"]:
		SaveSystem.delete_save(slot)
	content.settings_path = real_settings
	content.set_language(start_language)
	Game.new_game(12345)
	return failures


func _open_main(tree: SceneTree):
	var main = load("res://main.tscn").instantiate()
	tree.root.add_child(main)
	return main


func _close_main(tree: SceneTree, main) -> void:
	tree.root.remove_child(main)
	main.free()


## B5: the first launch shows no demo line until the language is picked, then
## shows it in that language. With no save, it is a new game.
func _first_launch_checks(tree: SceneTree, content) -> Array:
	var failures: Array = []
	DirAccess.remove_absolute(TEST_SETTINGS)
	Game.new_game(12345)
	var main = _open_main(tree)
	var picker = main.get_node_or_null("DialogLayer/LanguagePicker")
	if picker == null:
		_close_main(tree, main)
		return ["B5: the first launch should ask for the language"]
	var before: String = main.story_log.get_parsed_text()
	for lang in Content.LANGUAGES:
		if before.contains(Content.t_in(DEMO_KEY, lang)):
			failures.append("B5: no demo line before the language is picked, got '%s'" % before.strip_edges())
	var other := "en" if content.language() == "fr" else "fr"
	picker.find_child(other, true, false).pressed.emit()
	main.story_log.skip_typing()
	var after: String = main.story_log.get_parsed_text()
	var demo := Content.t_in(DEMO_KEY, other)
	if not after.contains(demo):
		failures.append("B5: after picking %s the demo line should be '%s', got '%s'" % [other, demo, after.strip_edges()])
	var wrong := Content.t_in(DEMO_KEY, "en" if other == "fr" else "fr")
	if after.contains(wrong):
		failures.append("B5: the demo line should not be in the other language: '%s'" % after.strip_edges())
	if int(Game.state["gold"]) != 10 or int(Game.state["time_minutes"]) != 480:
		failures.append("B5: with no save the first launch is a new game")
	_close_main(tree, main)
	return failures


## B1, B2, B3, B4, B6: the copy-paste window during a real turn.
func _paste_window_checks(tree: SceneTree, content) -> Array:
	var failures: Array = []
	_write_settings(SettingsStore.MODE_COPY_PASTE)
	Game.new_game(12345)
	var main = _open_main(tree)
	var dialog = main.dialog
	var clipboard := FakeClipboard.new()
	clipboard.text = "something copied earlier"
	var hooked := true
	for property in ["clipboard_write", "clipboard_read", "clipboard_cached"]:
		if not property in dialog:
			failures.append("B1: the paste window should reach the clipboard through '%s'" % property)
			hooked = false
	if hooked:
		dialog.clipboard_write = clipboard.write
		dialog.clipboard_read = clipboard.read
		dialog.clipboard_cached = clipboard.read_cached
		failures.append_array(_clipboard_checks(main, dialog, clipboard))
	failures.append_array(_prompt_reply_checks(main, dialog, clipboard, hooked))
	for lang in Content.LANGUAGES:
		content.set_language(lang)
		failures.append_array(_language_checks(main, dialog, lang))
		failures.append_array(_cancel_checks(main, dialog, lang))
	content.set_language("en")
	failures.append_array(_escape_checks(main, dialog))
	_close_main(tree, main)
	return failures


## B1: the window copies only on Copy prompt; Ctrl+V, the box's own paste and
## the Paste button read the clipboard now; a refused read never pastes the
## game's own prompt.
func _clipboard_checks(main, dialog, clipboard: FakeClipboard) -> Array:
	var failures: Array = []
	main.action_input.text = "I listen to the mill wheel."
	main._on_act()
	if not dialog.visible:
		return ["B1: Act should open the paste window"]
	if not clipboard.writes.is_empty():
		failures.append("B1: opening the window should copy nothing (the browser needs a click)")
	var prompt: String = dialog.prompt_text.text
	if not prompt.contains("=== TURN INPUT ==="):
		failures.append("B1: the window should show the prompt")
	var copy_button: Button = dialog.get_node_or_null("VBox/Buttons/CopyButton")
	var paste_button: Button = dialog.get_node_or_null("VBox/Buttons/PasteButton")
	if copy_button == null or paste_button == null:
		failures.append("B1: the window needs Copy prompt and Paste buttons")
		dialog._on_cancel()
		return failures
	copy_button.pressed.emit()
	if clipboard.writes != [prompt]:
		failures.append("B1: Copy prompt should copy the prompt once, got %d write(s)" % clipboard.writes.size())
	if dialog.notice_label.text != Content.t("ui.prompt_copied"):
		failures.append("B1: Copy prompt should say '%s', got '%s'" % [Content.t("ui.prompt_copied"), dialog.notice_label.text])

	# The player copies the DM's reply in the Claude tab, comes back, Ctrl+V.
	clipboard.text = REPLY
	dialog.reply_text.text = ""
	dialog.reply_text.grab_focus()
	main.get_viewport().push_input(_key(KEY_V, true))
	if dialog.reply_text.text != REPLY:
		failures.append("B1: Ctrl+V should paste the copied reply, got '%s'" % dialog.reply_text.text.left(40))
	dialog.reply_text.text = ""
	dialog.reply_text.paste()
	if dialog.reply_text.text != REPLY:
		failures.append("B1: the reply box's own paste (right-click Paste) should read the clipboard now")
	dialog.reply_text.text = ""
	paste_button.pressed.emit()
	if dialog.reply_text.text != REPLY:
		failures.append("B1: the Paste button should paste the copied reply, got '%s'" % dialog.reply_text.text.left(40))

	# The browser refuses the read and the game's own copy is still the prompt.
	clipboard.allowed = false
	clipboard.cached = prompt
	dialog.reply_text.text = ""
	paste_button.pressed.emit()
	if not dialog.reply_text.text.is_empty():
		failures.append("B1: a refused read should never paste the game's own prompt")
	if dialog.notice_label.text != Content.t("ui.paste_blocked") or not dialog.notice_label.visible:
		failures.append("B1: a refused read should say '%s', got '%s'" % [Content.t("ui.paste_blocked"), dialog.notice_label.text])
	# Refused, but the browser's paste event gave the game the reply: use it.
	clipboard.cached = REPLY
	paste_button.pressed.emit()
	if dialog.reply_text.text != REPLY:
		failures.append("B1: a refused read should fall back to the game's copy when it isn't the prompt")
	clipboard.allowed = true

	# The pasted reply plays the turn.
	var before: String = main.story_log.get_parsed_text()
	dialog._on_submit()
	main.story_log.skip_typing()
	var added: String = main.story_log.get_parsed_text().substr(before.length())
	if not added.contains("The wheel turns slowly."):
		failures.append("B1: the pasted reply should play the turn, got '%s'" % added.strip_edges())
	if main._busy:
		failures.append("B1: the turn should end and unlock")
	return failures


## B2: the prompt pasted back as the reply is refused: nothing changes, the
## typed text comes back, the message is in the story and on the status line.
func _prompt_reply_checks(main, dialog, clipboard: FakeClipboard, hooked: bool) -> Array:
	var failures: Array = []
	if not _is_prompt("=== RULES ===\nYou are the DM.\n<<STATE>>\n{}"):
		failures.append("B2: text starting with === RULES === is the prompt")
	if not _is_prompt("Here:\n=== TURN INPUT ===\n{}"):
		failures.append("B2: text holding === TURN INPUT === is the prompt")
	if _is_prompt(REPLY):
		failures.append("B2: a DM reply is not the prompt")
	var snapshot := _snapshot()
	main.action_input.text = "I knock."
	main._on_act()
	var prompt: String = dialog.prompt_text.text
	var before: String = main.story_log.get_parsed_text()
	clipboard.text = prompt
	dialog.reply_text.text = ""
	if hooked:
		dialog.reply_text.paste()
		if dialog.notice_label.text != Content.t("ui.reply_is_prompt"):
			failures.append("B2: pasting the prompt should warn at once in the window, got '%s'" % dialog.notice_label.text)
	else:
		dialog.reply_text.text = prompt
	dialog._on_submit()
	var added: String = main.story_log.get_parsed_text().substr(before.length())
	var message := Content.t("ui.reply_is_prompt")
	if main.status_label.text != message:
		failures.append("B2: the status line should say '%s', got '%s'" % [message, main.status_label.text])
	if not added.contains(message) or added.contains("=== RULES ==="):
		failures.append("B2: the story should get the message, not the rules: '%s'" % added.strip_edges().left(80))
	if main._busy or main.action_input.text != "I knock.":
		failures.append("B2: a refused prompt should unlock and give the typed text back")
	if _snapshot() != snapshot:
		failures.append("B2: a refused prompt should change nothing")
	return failures


## B3: every label of the window is in the current language, also when the
## language changes while it is open.
func _language_checks(main, dialog, lang: String) -> Array:
	var failures: Array = []
	var expected := {
		"VBox/Title": "ui.paste_reply",
		"VBox/Help1": "ui.paste_help_1",
		"VBox/Help2": "ui.paste_help_2",
		"VBox/Buttons/CopyButton": "ui.copy_prompt",
		"VBox/Buttons/PasteButton": "ui.paste",
		"VBox/Buttons/CancelButton": "ui.cancel",
		"VBox/Buttons/SubmitButton": "ui.continue",
	}
	for path in expected:
		var node = dialog.get_node_or_null(path)
		var want := Content.t_in(expected[path], lang)
		if node == null:
			failures.append("B3: the paste window should have %s" % path)
		elif node.text != want:
			failures.append("B3 (%s): %s should say '%s', got '%s'" % [lang, path, want, node.text])
	return failures


## B4: Cancel is the player's choice: "Turn cancelled." and "Ready".
func _cancel_checks(main, dialog, lang: String) -> Array:
	var failures: Array = []
	main.action_input.text = "I wait."
	main._on_act()
	if not dialog.visible:
		return ["B4 (%s): Act should open the paste window" % lang]
	var before: String = main.story_log.get_parsed_text()
	dialog._on_cancel()
	var added: String = main.story_log.get_parsed_text().substr(before.length())
	var cancelled := Content.t_in("ui.turn_cancelled", lang)
	if not added.contains(cancelled):
		failures.append("B4 (%s): the story should say '%s', got '%s'" % [lang, cancelled, added.strip_edges()])
	if added.contains(Content.t_in("ui.error", lang)) or added.contains("Cancelled."):
		failures.append("B4 (%s): a cancel is not an error: '%s'" % [lang, added.strip_edges()])
	if main.status_label.text != Content.t_in("ui.ready", lang):
		failures.append("B4 (%s): the status should be '%s', got '%s'" % [lang, Content.t_in("ui.ready", lang), main.status_label.text])
	if main._busy or main.action_input.text != "I wait.":
		failures.append("B4 (%s): a cancel should unlock and give the typed text back" % lang)
	return failures


## B6: Esc in the paste window cancels the turn.
func _escape_checks(main, dialog) -> Array:
	var failures: Array = []
	main.action_input.text = "I whistle."
	main._on_act()
	var before: String = main.story_log.get_parsed_text()
	main.get_viewport().push_input(_key(KEY_ESCAPE, false))
	if dialog.visible:
		failures.append("B6: Esc should close the paste window")
	var added: String = main.story_log.get_parsed_text().substr(before.length())
	if main._busy or main.action_input.text != "I whistle." or not added.contains(Content.t("ui.turn_cancelled")):
		failures.append("B6: Esc should cancel the turn like Cancel: '%s'" % added.strip_edges())
	return failures


## B7: Load takes the newer of the manual save and the autosave.
func _load_checks(tree: SceneTree, _content) -> Array:
	var failures: Array = []
	for slot in ["manual", "auto"]:
		SaveSystem.delete_save(slot)
	Game.new_game(12345)
	var main = _open_main(tree)
	Game.state["time_minutes"] = 480
	main._on_save()
	# File times have one-second steps.
	OS.delay_msec(1100)
	Game.state["time_minutes"] = 490
	Game.save("auto")
	Game.state["time_minutes"] = 600
	main._on_load()
	if int(Game.state["time_minutes"]) != 490:
		failures.append("B7: Load should pick the newer autosave (490), got %d" % int(Game.state["time_minutes"]))
	OS.delay_msec(1100)
	Game.state["time_minutes"] = 500
	main._on_save()
	Game.state["time_minutes"] = 600
	main._on_load()
	if int(Game.state["time_minutes"]) != 500:
		failures.append("B7: Load should pick the newer manual save (500), got %d" % int(Game.state["time_minutes"]))
	_close_main(tree, main)
	return failures


## B8: with a save, the game resumes it at start, in the device's language,
## with "Game resumed" and no demo line. Also after a first-launch choice.
func _resume_checks(tree: SceneTree, content) -> Array:
	var failures: Array = []
	for slot in ["manual", "auto"]:
		SaveSystem.delete_save(slot)
	Game.new_game(12345)
	var saved: Dictionary = Game.state.duplicate(true)
	saved["gold"] = 55
	saved["time_minutes"] = 490
	saved["hero_cell"] = [20, 31]
	saved["language"] = "fr"
	SaveSystem.save_game(saved, "auto")
	content.set_language("en")
	content.remember_language()
	Game.new_game(12345)

	var main = _open_main(tree)
	failures.append_array(_resumed_checks(main, "B8"))
	_close_main(tree, main)

	# First launch with a save already there: resume after the choice.
	DirAccess.remove_absolute(TEST_SETTINGS)
	Game.new_game(12345)
	main = _open_main(tree)
	if int(Game.state["gold"]) == 55:
		failures.append("B8: the first launch should wait for the language before resuming")
	var picker = main.get_node_or_null("DialogLayer/LanguagePicker")
	if picker == null:
		failures.append("B8: the first launch should ask for the language")
	else:
		picker.find_child("en", true, false).pressed.emit()
		failures.append_array(_resumed_checks(main, "B8 (first launch)"))
	_close_main(tree, main)
	return failures


func _resumed_checks(main, label: String) -> Array:
	var failures: Array = []
	main.story_log.skip_typing()
	var story: String = main.story_log.get_parsed_text()
	if int(Game.state["gold"]) != 55 or int(Game.state["time_minutes"]) != 490:
		failures.append("%s: the game should resume the autosave (gold 55, 490 min), got %d, %d" % [label, int(Game.state["gold"]), int(Game.state["time_minutes"])])
	if main.world.hero_cell() != Vector2i(20, 31):
		failures.append("%s: the hero should stand on the saved tile, got %s" % [label, main.world.hero_cell()])
	if Content.language() != "en" or str(Game.state.get("language", "")) != "en":
		failures.append("%s: the device's language (en) should win over the save's (fr)" % label)
	if not story.contains(Content.t_in("ui.resumed", "en")):
		failures.append("%s: the story should say '%s', got '%s'" % [label, Content.t_in("ui.resumed", "en"), story.strip_edges()])
	for lang in Content.LANGUAGES:
		if story.contains(Content.t_in(DEMO_KEY, lang)):
			failures.append("%s: a resumed game shows no demo line" % label)
	return failures


## Called by name, so this file still loads (and fails) before the function exists.
func _is_prompt(text: String) -> bool:
	for info in (PromptBuilder as Script).get_script_method_list():
		if info["name"] == "is_prompt_text":
			return (PromptBuilder as Script).call("is_prompt_text", text)
	return false


func _key(keycode: Key, ctrl: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.ctrl_pressed = ctrl
	event.command_or_control_autoremap = ctrl
	event.pressed = true
	return event


func _write_settings(mode: String) -> void:
	var settings := SettingsStore.read(TEST_SETTINGS)
	settings.path = TEST_SETTINGS
	settings.mode = mode
	settings.api_key = ""
	settings.write()


func _snapshot() -> String:
	var state: Dictionary = Game.state
	return JSON.stringify([state["hero"], state["gold"], state["time_minutes"], state.get("square"), state.get("hero_cell"), state.get("turn")])
