class_name OwnKeyAdapter
extends AIAdapter
## Own-key mode: the player's own Claude API key calls the Claude Messages API
## straight from the game, with no server of ours in between. The DM autoload
## hands the key over from the device settings file for each turn. The key is
## only ever sent to the Claude API, in the Authorization header; it is never
## logged, printed or saved by this script.
##
## The prompt is split for prompt caching: the rules and the Codex change
## rarely, so they go in two cached system blocks; the rest is the user message.
## Both are cut from PromptBuilder.to_single_text(), so this mode sends exactly
## the text that copy-paste mode copies.
##
## The request and the reply handling are static functions, so tests can check
## them without a network or a real key.

const API_URL := "https://api.anthropic.com/v1/messages"
## The Claude API version, sent in the anthropic-version header.
const API_VERSION := "2026-10-21"
## From the AI cost study: Sonnet 5.5 at effort "low", with prompt caching.
const MODEL := "claude-sonnet-5-5"
const EFFORT := "low"
## Room for a short think plus a long reply, small enough that a maxed-out
## reply still arrives before the timeout: the player then sees "cut off"
## with the text kept, instead of no reply at all.
const MAX_TOKENS := 4096
## SPEC-dm: "no answer after 90 s".
const TIMEOUT_SECONDS := 90.0
## A normal reply is a few kilobytes; this stops a runaway download.
const BODY_LIMIT_BYTES := 1048576
## Server-side fallback (beta, Claude API only): when a safety classifier
## declines in a category that has a recommended fallback model, the API reruns
## the request on that model. Set to false to send the plain request.
const SERVER_FALLBACK := true
const FALLBACK_BETA := "server-side-fallback-2026-07-01"

## The part headers and separator of PromptBuilder.to_single_text().
const RULES_HEADER := "=== RULES ===\n"
const CODEX_HEADER := "=== CODEX ===\n"
const PART_SEPARATOR := "\n\n"

## Player messages: keys in content/i18n/strings.csv.
const STATUS_NO_KEY := "ui.ai_no_key"
const STATUS_KEY_REFUSED := "ui.ai_key_refused"
const STATUS_SERVICE_ERROR := "ui.ai_service_error"
const STATUS_NETWORK_ERROR := "ui.ai_network_error"
const STATUS_TIMEOUT := "ui.ai_timeout"
const STATUS_REFUSAL := "ui.ai_refusal"
const STATUS_CUT_OFF := "ui.ai_cut_off"
const STATUSES := [
	STATUS_NO_KEY, STATUS_KEY_REFUSED, STATUS_SERVICE_ERROR, STATUS_NETWORK_ERROR,
	STATUS_TIMEOUT, STATUS_REFUSAL, STATUS_CUT_OFF,
]

## Set by the DM autoload for each turn, from the settings file.
var api_key := ""
## The player message from the last turn, in their language ("" = all fine).
var last_status := ""


func generate_turn(prompt: Dictionary) -> String:
	last_status = ""
	if api_key.is_empty():
		return _finish("", STATUS_NO_KEY)
	var request := build_request(prompt, api_key, OS.has_feature("web"))
	var http := new_http_request()
	add_child(http)
	status_changed.emit(_translate("ui.waiting"))
	var error := http.request(request["url"], request["headers"], HTTPClient.METHOD_POST, request["body"])
	if error != OK:
		http.queue_free()
		push_warning("Own key: the request could not start (error %d)." % error)
		return _finish("", STATUS_NETWORK_ERROR)
	# HTTPRequest always answers: with the reply, a network error, or
	# RESULT_TIMEOUT after TIMEOUT_SECONDS. The game keeps running meanwhile.
	var response: Array = await http.request_completed
	http.queue_free()
	var outcome := read_response(int(response[0]), int(response[1]), response[2], response[3])
	for line in outcome["log"]:
		push_warning("Own key: %s" % _scrub(str(line)))
	if not (outcome["usage"] as Dictionary).is_empty():
		print(usage_line(str(outcome["model"]), outcome["usage"]))
	return _finish(str(outcome["text"]), str(outcome["status"]), int(outcome["error_code"]))


## The HTTP request for one turn: {url, headers, body}.
static func build_request(prompt: Dictionary, key: String, for_web: bool) -> Dictionary:
	var headers := PackedStringArray([
		"content-type: application/json",
		"accept: application/json",
		"authorization: Bearer " + key,
		"anthropic-version: " + API_VERSION,
	])
	if SERVER_FALLBACK:
		headers.append("anthropic-beta: " + FALLBACK_BETA)
	if for_web:
		# Browsers block a direct call to the API unless the page opts in
		# (CORS). Meant for "bring your own key" pages like this one.
		headers.append("anthropic-dangerous-direct-browser-access: true")
	var body := {
		"model": MODEL,
		"max_tokens": MAX_TOKENS,
		"output_config": {"effort": EFFORT},
		"system": system_blocks(prompt),
		"messages": [{"role": "user", "content": user_text(prompt)}],
	}
	if SERVER_FALLBACK:
		body["fallbacks"] = "default"
	return {"url": API_URL, "headers": headers, "body": JSON.stringify(body)}


## The rules, then the Codex: the most stable parts, each with a cache
## breakpoint. Same text as their parts in PromptBuilder.to_single_text().
static func system_blocks(prompt: Dictionary) -> Array:
	return [
		{"type": "text", "text": RULES_HEADER + str(prompt.get("rules", "")), "cache_control": {"type": "ephemeral"}},
		{"type": "text", "text": CODEX_HEADER + str(prompt.get("codex", "")), "cache_control": {"type": "ephemeral"}},
	]


## The copy-paste text without its RULES and CODEX parts, which travel in the
## system blocks. Any other part PromptBuilder adds reaches this mode as well.
static func user_text(prompt: Dictionary) -> String:
	var text := PromptBuilder.to_single_text(prompt)
	for block in system_blocks(prompt):
		var part := str(block["text"]) + PART_SEPARATOR
		var at := text.find(part)
		if at == -1:
			push_warning("Own key: '%s' was not found in the prompt text, so it is sent twice." % part.get_slice("\n", 0))
			continue
		text = text.substr(0, at) + text.substr(at + part.length())
	return text


## A request node that gives up after TIMEOUT_SECONDS with RESULT_TIMEOUT.
static func new_http_request() -> HTTPRequest:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SECONDS
	http.body_size_limit = BODY_LIMIT_BYTES
	return http


## Turns one HTTPRequest answer into:
##   text: the reply text ("" when there is no usable reply)
##   status: "" when all is fine, else one of the STATUS_* keys
##   error_code: the HTTP code to show with a service error, else 0
##   truncated: the reply was cut off (its text is kept)
##   model, usage: from the reply, for the cost log
##   log: lines for the debug log
static func read_response(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> Dictionary:
	var outcome := {
		"text": "", "status": "", "error_code": 0, "truncated": false,
		"model": "", "usage": {}, "log": [],
	}
	if result == HTTPRequest.RESULT_TIMEOUT:
		outcome["status"] = STATUS_TIMEOUT
		outcome["log"].append("no answer after %d s" % int(TIMEOUT_SECONDS))
		return outcome
	if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		outcome["status"] = STATUS_SERVICE_ERROR
		outcome["log"].append("the reply was larger than %d bytes" % BODY_LIMIT_BYTES)
		return outcome
	if result != HTTPRequest.RESULT_SUCCESS:
		outcome["status"] = STATUS_NETWORK_ERROR
		outcome["log"].append("network error (HTTPRequest result %d)" % result)
		return outcome

	var json := JSON.new()
	var data: Variant = json.data if json.parse(body.get_string_from_utf8()) == OK else null
	if code != 200:
		outcome["status"] = STATUS_KEY_REFUSED if code == 401 else STATUS_SERVICE_ERROR
		outcome["error_code"] = code
		outcome["log"].append(_error_line(code, data, headers))
		return outcome
	if not (data is Dictionary):
		outcome["status"] = STATUS_SERVICE_ERROR
		outcome["log"].append("HTTP 200 without a JSON message")
		return outcome

	outcome["model"] = str(data.get("model", ""))
	if data.get("usage") is Dictionary:
		outcome["usage"] = data["usage"]
	var stop_reason := str(data.get("stop_reason", ""))
	# Why the reply stopped comes first: a refusal's partial text is dropped.
	if stop_reason == "refusal":
		outcome["status"] = STATUS_REFUSAL
		outcome["log"].append("the model declined (category: %s)" % _refusal_category(data))
		return outcome
	outcome["text"] = _text_of(data.get("content"))
	if stop_reason == "max_tokens" or stop_reason == "model_context_window_exceeded":
		outcome["truncated"] = true
		outcome["status"] = STATUS_CUT_OFF
		outcome["log"].append("the reply was cut off (%s); its text is kept" % stop_reason)
	elif str(outcome["text"]).strip_edges().is_empty():
		outcome["status"] = STATUS_SERVICE_ERROR
		outcome["log"].append("the reply had no text (stop_reason: %s)" % stop_reason)
	return outcome


## One debug-log line for the AI cost study. It never contains the key.
static func usage_line(model: String, usage: Dictionary) -> String:
	return "DM usage (%s): input %d, cache read %d, cache write %d, output %d" % [
		model if not model.is_empty() else MODEL,
		_count(usage.get("input_tokens")),
		_count(usage.get("cache_read_input_tokens")),
		_count(usage.get("cache_creation_input_tokens")),
		_count(usage.get("output_tokens")),
	]


## The player message for a status key, in the current language. A service
## error shows its HTTP code, which reads the same in every language.
func status_message(status_key: String, error_code: int = 0) -> String:
	if status_key.is_empty():
		return ""
	var message := _translate(status_key)
	if status_key == STATUS_SERVICE_ERROR and error_code > 0:
		message += " (%d)" % error_code
	return message


## Content.t(), looked up at run time rather than by the autoload's name, so
## this class also compiles in tools that load it before the autoloads exist.
static func _translate(key: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var content: Node = tree.root.get_node_or_null("Content") if tree != null else null
	if content == null:
		return key
	return content.t(key)


func _finish(text: String, status_key: String, error_code: int = 0) -> String:
	last_status = status_message(status_key, error_code)
	status_changed.emit(last_status)
	return text


## Defence in depth: no log line shows the key, even if a server echoed it.
func _scrub(line: String) -> String:
	if api_key.length() < 8:
		return line
	return line.replace(api_key, "[key]")


## Joins the text blocks only: thinking blocks and fallback markers are skipped.
static func _text_of(content: Variant) -> String:
	if not (content is Array):
		return ""
	var parts := PackedStringArray()
	for block in content:
		if block is Dictionary and str(block.get("type", "")) == "text":
			parts.append(str(block.get("text", "")))
	return "".join(parts)


static func _refusal_category(data: Dictionary) -> String:
	var details: Variant = data.get("stop_details")
	if details is Dictionary and details.get("category") != null:
		return str(details["category"])
	return "none"


static func _error_line(code: int, data: Variant, headers: PackedStringArray) -> String:
	var line := "HTTP %d" % code
	if data is Dictionary and data.get("error") is Dictionary:
		var error: Dictionary = data["error"]
		line += " %s: %s" % [str(error.get("type", "")), str(error.get("message", ""))]
	for header in headers:
		if header.to_lower().begins_with("request-id:"):
			line += " (%s)" % header.strip_edges()
	return line


static func _count(value: Variant) -> int:
	return int(value) if (value is int or value is float) else 0
