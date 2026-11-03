extends RefCounted
## Own-key reply handling from canned answers (no network, fake key): text,
## refusal, cut-off, 401, 500, timeout, network errors, the usage log line,
## the player messages in both languages, and a no-key turn through the DM.

const FAKE_KEY := "FAKE-KEY-FOR-TESTS"
const TEST_SETTINGS := "user://__test_own_key_turn.cfg"
const REPLY := "The planks groan.\n<<STATE>>\n{\"commands\": [], \"state\": {}}"


func run() -> Array:
	var failures: Array = []
	failures.append_array(_check_replies())
	failures.append_array(_check_errors())
	failures.append_array(_check_messages())
	failures.append_array(_check_turns())
	return failures


func _check_replies() -> Array:
	var failures: Array = []
	var usage := {"input_tokens": 1200, "cache_read_input_tokens": 3400, "cache_creation_input_tokens": 0, "output_tokens": 250}
	var ok := _read(200, {
		"model": "claude-sonnet-5-5",
		"content": [
			{"type": "thinking", "thinking": "", "signature": "sig"},
			{"type": "text", "text": REPLY},
		],
		"stop_reason": "end_turn",
		"usage": usage,
	})
	if ok["text"] != REPLY or ok["status"] != "" or ok["truncated"]:
		failures.append("a normal reply should give its text blocks only and no status")
	if int(ok["usage"].get("output_tokens", 0)) != 250 or ok["model"] != "claude-sonnet-5-5":
		failures.append("usage and model should be read for the cost log")
	var line := OwnKeyAdapter.usage_line(ok["model"], ok["usage"])
	for part in ["claude-sonnet-5-5", "input 1200", "cache read 3400", "cache write 0", "output 250"]:
		if not part in line:
			failures.append("usage line should contain '%s': %s" % [part, line])
	if not "input 0" in OwnKeyAdapter.usage_line("", {"input_tokens": null}):
		failures.append("missing usage numbers should print as 0")

	var refusal := _read(200, {
		"content": [{"type": "text", "text": "Half a sentence"}],
		"stop_reason": "refusal",
		"stop_details": {"type": "refusal", "category": "general_harms", "explanation": "..."},
	})
	if refusal["status"] != OwnKeyAdapter.STATUS_REFUSAL or refusal["text"] != "":
		failures.append("a refusal should give the refusal status and drop any partial text")
	if not "general_harms" in str(refusal["log"]):
		failures.append("the refusal category should reach the debug log")

	var cut := _read(200, {"content": [{"type": "text", "text": "The planks gro"}], "stop_reason": "max_tokens"})
	if cut["status"] != OwnKeyAdapter.STATUS_CUT_OFF or cut["text"] != "The planks gro" or not cut["truncated"]:
		failures.append("a cut-off reply should keep its text and give the cut-off status")
	if cut["log"].is_empty():
		failures.append("a cut-off reply should log a warning")
	var window := _read(200, {"content": [{"type": "text", "text": "x"}], "stop_reason": "model_context_window_exceeded"})
	if window["status"] != OwnKeyAdapter.STATUS_CUT_OFF or window["text"] != "x":
		failures.append("a full context window counts as cut off")

	var fallback := _read(200, {
		"model": "claude-sonnet-5",
		"content": [
			{"type": "fallback", "from": {"model": "claude-sonnet-5-5"}, "to": {"model": "claude-sonnet-5"}},
			{"type": "text", "text": REPLY},
		],
		"stop_reason": "end_turn",
	})
	if fallback["text"] != REPLY or fallback["model"] != "claude-sonnet-5":
		failures.append("a fallback reply should give its text and the model that served it")

	var empty := _read(200, {"content": [{"type": "thinking", "thinking": ""}], "stop_reason": "end_turn"})
	if empty["status"] != OwnKeyAdapter.STATUS_SERVICE_ERROR or empty["text"] != "":
		failures.append("a reply with no text should be a service error")
	return failures


func _check_errors() -> Array:
	var failures: Array = []
	var refused := _read(401, {"type": "error", "error": {"type": "authentication_error", "message": "invalid key"}})
	if refused["status"] != OwnKeyAdapter.STATUS_KEY_REFUSED or refused["text"] != "":
		failures.append("401 should give 'key refused'")

	var broken := OwnKeyAdapter.read_response(
		HTTPRequest.RESULT_SUCCESS, 500, PackedStringArray(["request-id: req_test_500"]),
		JSON.stringify({"type": "error", "error": {"type": "api_error", "message": "boom"}}).to_utf8_buffer(),
	)
	if broken["status"] != OwnKeyAdapter.STATUS_SERVICE_ERROR or broken["error_code"] != 500:
		failures.append("500 should give a service error with its code")
	if not "api_error" in str(broken["log"]) or not "req_test_500" in str(broken["log"]):
		failures.append("the error type and request id should reach the debug log")
	for code in [400, 403, 404, 429, 529]:
		var other := _read(code, {"type": "error", "error": {"type": "x", "message": "y"}})
		if other["status"] != OwnKeyAdapter.STATUS_SERVICE_ERROR or other["error_code"] != code:
			failures.append("%d should give a service error" % code)

	var html := OwnKeyAdapter.read_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "<html>proxy</html>".to_utf8_buffer())
	if html["status"] != OwnKeyAdapter.STATUS_SERVICE_ERROR:
		failures.append("a 200 that isn't JSON should be a service error")

	var timeout := OwnKeyAdapter.read_response(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray())
	if timeout["status"] != OwnKeyAdapter.STATUS_TIMEOUT or timeout["text"] != "":
		failures.append("a timeout should give the 'no answer after 90 s' status")
	for result in [HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR]:
		if OwnKeyAdapter.read_response(result, 0, PackedStringArray(), PackedByteArray())["status"] != OwnKeyAdapter.STATUS_NETWORK_ERROR:
			failures.append("HTTPRequest result %d should give the network status" % result)
	var huge := OwnKeyAdapter.read_response(HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED, 0, PackedStringArray(), PackedByteArray())
	if huge["status"] != OwnKeyAdapter.STATUS_SERVICE_ERROR:
		failures.append("an oversized reply should be a service error")
	return failures


func _check_messages() -> Array:
	var failures: Array = []
	for key in OwnKeyAdapter.STATUSES:
		for lang in ["en", "fr"]:
			var text := Content.t_in(key, lang)
			if text == key or text.is_empty():
				failures.append("missing %s text for %s" % [lang, key])
	var adapter := OwnKeyAdapter.new()
	if not adapter.status_message(OwnKeyAdapter.STATUS_SERVICE_ERROR, 529).ends_with("(529)"):
		failures.append("a service error should show its HTTP code")
	if adapter.status_message("") != "":
		failures.append("no status should mean no message")
	adapter.api_key = FAKE_KEY
	if FAKE_KEY in adapter._scrub("server said: " + FAKE_KEY):
		failures.append("log lines must never show the key")
	adapter.free()
	return failures


## No key set: the turn fails at once with the "no key" message, without
## touching the network. Then copy-paste mode, read from the same settings
## file on the next turn, still opens the paste dialog.
func _check_turns() -> Array:
	var failures: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	var dm = tree.root.get_node("DM")
	var content = tree.root.get_node("Content")
	var real_settings: String = content.settings_path
	content.settings_path = TEST_SETTINGS
	DirAccess.remove_absolute(TEST_SETTINGS)

	var adapter := OwnKeyAdapter.new()
	var reply: Variant = adapter.call("generate_turn", {})
	if reply != "" or adapter.last_status != Content.t(OwnKeyAdapter.STATUS_NO_KEY):
		failures.append("no key should give '' and the no-key message")
	adapter.free()

	var settings := SettingsStore.new()
	settings.path = TEST_SETTINGS
	settings.mode = SettingsStore.MODE_OWN_KEY
	settings.write()
	var notices: Array = []
	var on_notice := func(message: String) -> void: notices.append(message)
	dm.connection_notice.connect(on_notice)
	var result: Variant = dm.call("play_turn", "I cross the bridge.")
	var no_key := Content.t(OwnKeyAdapter.STATUS_NO_KEY)
	if not (result is Dictionary) or result.get("ok") != false:
		failures.append("own key without a key should be a failed turn")
	elif result.get("status") != no_key or result.get("errors") != [no_key]:
		failures.append("the failed turn should carry the no-key message: %s" % str(result))
	if notices != ["", no_key]:
		failures.append("the DM should clear, then send the no-key notice: %s" % str(notices))

	settings.mode = SettingsStore.MODE_COPY_PASTE
	settings.write()
	var prompts: Array = []
	var on_prompt := func(text: String) -> void: prompts.append(text)
	dm.prompt_ready.connect(on_prompt)
	dm.call("play_turn", "I cross the bridge.")
	if prompts.size() != 1 or not "=== RULES ===" in str(prompts[0]):
		failures.append("copy-paste mode should still send the prompt to the paste dialog")
	dm.cancel_reply()
	if dm._busy:
		failures.append("cancelling the paste dialog should end the copy-paste turn")

	dm.prompt_ready.disconnect(on_prompt)
	dm.connection_notice.disconnect(on_notice)
	DirAccess.remove_absolute(TEST_SETTINGS)
	content.settings_path = real_settings
	return failures


func _read(code: int, data: Dictionary) -> Dictionary:
	return OwnKeyAdapter.read_response(HTTPRequest.RESULT_SUCCESS, code, PackedStringArray(), JSON.stringify(data).to_utf8_buffer())
