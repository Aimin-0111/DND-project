class_name ProxyAdapter
extends AIAdapter
## Calls OUR Cloudflare Worker (examples/proxy/worker.ts). The Worker holds
## the API key, adds the DM rules, and talks to Claude, so the key is never
## inside the game files (anyone can unpack a game and read them).
##
## The game sends only game data (codex, summary, state, action), never the
## rules or a model name: the Worker decides those, so nobody can use our
## key as a free general-purpose chatbot.

@export var proxy_url := "https://brasswake-dm.YOUR-NAME.workers.dev/turn"
@export var timeout_seconds := 60.0
## Shared with the Worker. It only stops casual abuse: a determined person
## can find it in the game files. Real protection = rate limits on the Worker.
@export var game_token := "change-me"


func generate_turn(prompt: Dictionary) -> String:
	var http := HTTPRequest.new()
	http.timeout = timeout_seconds
	add_child(http)

	var body := JSON.stringify({
		"codex": prompt["codex"],
		"summary": prompt["summary"],
		"state": prompt["state"],
		"allowed": prompt["allowed"],
		"action": prompt["action"],
	})
	var headers := PackedStringArray(["Content-Type: application/json", "X-Game-Token: " + game_token])
	status_changed.emit("The DM is thinking…")
	var err := http.request(proxy_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		status_changed.emit("Could not reach the DM server.")
		return ""

	# request_completed gives: [result, response_code, headers, body]
	var response: Array = await http.request_completed
	http.queue_free()
	var result: int = response[0]
	var code: int = response[1]
	var data = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())

	if result != HTTPRequest.RESULT_SUCCESS:
		status_changed.emit("Network problem (%d). Try again or use copy-paste mode." % result)
		return ""
	if code == 422 and data is Dictionary:
		# The Worker uses 422 when Claude declined this action.
		status_changed.emit(data.get("message", "The DM can't narrate that. Try another action."))
		return ""
	if code != 200 or not (data is Dictionary):
		status_changed.emit("The DM server answered with error %d." % code)
		return ""
	status_changed.emit("")
	return String(data.get("text", ""))
