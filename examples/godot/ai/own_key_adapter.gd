class_name OwnKeyAdapter
extends AIAdapter
## The player pastes THEIR OWN Claude API key in Settings. It is saved only
## on their device (user://settings.cfg; in the browser version that is the
## browser's storage). We pay nothing, and no server is needed.
## Never ship the game with a key filled in.
##
## There is no official Claude SDK for GDScript, so this calls the
## Messages API directly over HTTPS.

const API_URL := "https://api.anthropic.com/v1/messages"
const SETTINGS_PATH := "user://settings.cfg"
## From the AI cost study: Sonnet 5.5 at effort "low", with prompt caching.
const MODEL := "claude-sonnet-5-5"

@export var timeout_seconds := 90.0


static func save_key(api_key: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # keep other settings; fails harmlessly the first time
	cfg.set_value("ai", "api_key", api_key.strip_edges())
	cfg.save(SETTINGS_PATH)


static func load_key() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return ""
	return cfg.get_value("ai", "api_key", "")


func generate_turn(prompt: Dictionary) -> String:
	var api_key := load_key()
	if api_key == "":
		status_changed.emit("Add your API key in Settings, or use copy-paste mode.")
		return ""

	var headers := PackedStringArray([
		"content-type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01",
		# Server-side fallback: if Claude declines, the API retries on another model.
		"anthropic-beta: server-side-fallback-2026-07-01",
	])
	if OS.has_feature("web"):
		# Browsers need this to call the API directly from a web page.
		headers.append("anthropic-dangerous-direct-browser-access: true")

	var body := {
		"model": MODEL,
		"max_tokens": 8000,
		"fallbacks": "default",
		"output_config": {"effort": "low"},
		# Stable parts first, each marked for caching (see PromptBuilder).
		"system": [
			{"type": "text", "text": prompt["rules"], "cache_control": {"type": "ephemeral"}},
			{"type": "text", "text": "=== CODEX ===\n" + prompt["codex"], "cache_control": {"type": "ephemeral"}},
		],
		"messages": [{"role": "user", "content": "\n\n".join([
			"=== STORY SO FAR ===\n" + prompt["summary"],
			"=== STATE ===\n" + JSON.stringify(prompt["state"]),
			"=== ALLOWED IDS ===\n" + JSON.stringify(prompt["allowed"]),
			"=== PLAYER ACTION ===\n" + prompt["action"],
		])}],
	}

	var http := HTTPRequest.new()
	http.timeout = timeout_seconds
	add_child(http)
	status_changed.emit("The DM is thinking…")
	if http.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
		http.queue_free()
		status_changed.emit("Could not start the request.")
		return ""
	var response: Array = await http.request_completed
	http.queue_free()

	var code: int = response[1]
	var data = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if code == 401:
		status_changed.emit("The API key was refused. Check it in Settings.")
		return ""
	if code != 200 or not (data is Dictionary):
		status_changed.emit("The AI service answered with error %d." % code)
		return ""
	# Always check why the reply stopped BEFORE reading it.
	if data.get("stop_reason") == "refusal":
		status_changed.emit("The DM can't narrate that. Try another action.")
		return ""
	if data.get("stop_reason") == "max_tokens":
		push_warning("Reply was cut off: raise max_tokens or ask for shorter replies.")

	# The reply is a list of blocks; keep only the text ones.
	var text := ""
	for block in data.get("content", []):
		if block.get("type") == "text":
			text += block.get("text", "")
	status_changed.emit("")
	return text
