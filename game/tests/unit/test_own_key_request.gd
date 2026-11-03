extends RefCounted
## Own-key request building, with no network and a fake key: headers, model,
## effort, cache markers and the RULES/CODEX split of the prompt text.

const FAKE_KEY := "FAKE-KEY-FOR-TESTS"


func run() -> Array:
	var failures: Array = []
	var state := GameState.new_game(7)
	var allowed := Content.allowed_ids()
	allowed["skills"] = GameState.allowed_skills(state)
	var prompt := PromptBuilder.build(state, "Je traverse le pont.", "RULES-MARKER", "CODEX-MARKER", allowed, "fr")

	var request := OwnKeyAdapter.build_request(prompt, FAKE_KEY, false)
	if request["url"] != "https://api.anthropic.com/v1/messages":
		failures.append("wrong URL: %s" % request["url"])

	var headers: PackedStringArray = request["headers"]
	for expected in [
		"content-type: application/json",
		"authorization: Bearer " + FAKE_KEY,
		"anthropic-version: 2026-10-21",
		"anthropic-beta: server-side-fallback-2026-07-01",
	]:
		if not expected in headers:
			failures.append("missing header '%s'" % expected.get_slice(":", 0))
	if _has_header(headers, "anthropic-dangerous-direct-browser-access"):
		failures.append("the browser-access header is for the web build only")
	if _has_header(headers, "x-api-key"):
		failures.append("the key goes in Authorization only, not also in x-api-key")
	var web_headers: PackedStringArray = OwnKeyAdapter.build_request(prompt, FAKE_KEY, true)["headers"]
	if not "anthropic-dangerous-direct-browser-access: true" in web_headers:
		failures.append("the web build needs the browser-access header")

	var body_text: String = request["body"]
	if FAKE_KEY in body_text:
		failures.append("the key must never be in the request body")
	if FAKE_KEY in JSON.stringify(prompt):
		failures.append("the key must never be in the prompt")
	var key_count := 0
	for header in headers:
		key_count += header.count(FAKE_KEY)
	if key_count != 1:
		failures.append("the key should appear once, in the Authorization header")

	var body: Variant = JSON.parse_string(body_text)
	if not (body is Dictionary):
		return failures + ["the body is not a JSON object"]
	if body.get("model") != "claude-sonnet-5-5":
		failures.append("model should be claude-sonnet-5-5, got %s" % str(body.get("model")))
	if int(body.get("max_tokens", 0)) != OwnKeyAdapter.MAX_TOKENS or not ('"max_tokens":%d' % OwnKeyAdapter.MAX_TOKENS) in body_text:
		failures.append("max_tokens should be the whole number %d" % OwnKeyAdapter.MAX_TOKENS)
	if not (body.get("output_config") is Dictionary) or body["output_config"].get("effort") != "low":
		failures.append("effort should be low")
	if body.get("fallbacks") != "default":
		failures.append("server-side fallback should be on (fallbacks: default)")
	for removed in ["temperature", "top_p", "top_k", "thinking"]:
		if body.has(removed):
			failures.append("'%s' should not be sent" % removed)

	var system: Variant = body.get("system")
	if not (system is Array) or system.size() != 2:
		return failures + ["system should be two blocks: rules, then Codex"]
	var expected_texts := ["=== RULES ===\nRULES-MARKER", "=== CODEX ===\nCODEX-MARKER"]
	for i in 2:
		var block: Dictionary = system[i]
		if block.get("type") != "text" or block.get("text") != expected_texts[i]:
			failures.append("system block %d should be '%s'" % [i, expected_texts[i].get_slice("\n", 0)])
		if not (block.get("cache_control") is Dictionary) or block["cache_control"].get("type") != "ephemeral":
			failures.append("system block %d should carry an ephemeral cache marker" % i)

	var messages: Variant = body.get("messages")
	if not (messages is Array) or messages.size() != 1 or messages[0].get("role") != "user":
		return failures + ["messages should be one user message"]
	var user: String = str(messages[0].get("content", ""))
	for part in ["=== RULES ===", "=== CODEX ===", "RULES-MARKER", "CODEX-MARKER"]:
		if part in user:
			failures.append("the user message should not repeat '%s'" % part)
	var previous := -1
	for header in ["=== STORY SO FAR ===", "=== STATE ===", "=== ALLOWED IDS ===", "=== LAST ROLL ===", "=== TURN INPUT ==="]:
		var at := user.find(header)
		if at <= previous:
			failures.append("the user message should hold '%s' in prompt order" % header)
		previous = at
	if not "Je traverse le pont." in user or not '"language": "fr"' in user:
		failures.append("the turn input (action, language) should be in the user message")
	var rebuilt: String = "\n\n".join([expected_texts[0], expected_texts[1], user])
	if rebuilt != PromptBuilder.to_single_text(prompt):
		failures.append("system blocks + user message should be exactly the copy-paste text")

	# Lore or rules that contain part headers must not confuse the split.
	var tricky := PromptBuilder.build(state, "Je regarde.", "Rules\n=== STATE ===\nnot a part", "Lore\n=== RULES ===\nstill lore", allowed, "en")
	var tricky_user := OwnKeyAdapter.user_text(tricky)
	var tricky_system := OwnKeyAdapter.system_blocks(tricky)
	if "not a part" in tricky_user or "still lore" in tricky_user:
		failures.append("rules or Codex text leaked into the user message")
	if "\n\n".join([tricky_system[0]["text"], tricky_system[1]["text"], tricky_user]) != PromptBuilder.to_single_text(tricky):
		failures.append("the split should stay exact when the texts contain part headers")

	var http := OwnKeyAdapter.new_http_request()
	if not is_equal_approx(http.timeout, 90.0):
		failures.append("the request should time out after 90 s, got %s" % str(http.timeout))
	if http.body_size_limit <= 0:
		failures.append("the reply size should be limited")
	http.free()
	return failures


func _has_header(headers: PackedStringArray, name: String) -> bool:
	for header in headers:
		if header.to_lower().begins_with(name + ":"):
			return true
	return false
