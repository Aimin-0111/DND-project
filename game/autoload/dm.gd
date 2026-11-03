extends Node
## Autoload: builds the prompt, asks the connection chosen in the settings for
## a reply and parses it. It never changes the state or the scene; the shell
## does that after the narration is read.

signal prompt_ready(prompt_text: String)
signal status_changed(message: String)
## Own-key mode's message for the player after a turn, already in their
## language: why the turn failed, or that the reply was cut off. "" clears it.
## Copy-paste mode never sends one.
signal connection_notice(message: String)

## The copy-paste connection: the free default (the paste dialog talks to it).
var adapter: CopyPasteAdapter
## The own-key connection: the player's own API key, from the settings file.
var own_key: OwnKeyAdapter
var _busy := false


func _ready() -> void:
	adapter = CopyPasteAdapter.new()
	add_child(adapter)
	adapter.prompt_ready.connect(func(text: String) -> void: prompt_ready.emit(text))
	adapter.status_changed.connect(func(message: String) -> void: status_changed.emit(message))
	own_key = OwnKeyAdapter.new()
	add_child(own_key)
	own_key.status_changed.connect(func(message: String) -> void: status_changed.emit(message))


## Returns {ok, narration, commands, changes, errors}, plus "status" (the
## message for the player) when the own-key connection has one. Only an empty
## reply is a failed turn. Otherwise bad commands and changes are dropped one by
## one and listed in errors (the debug log); the rest still applies.
func play_turn(action: String) -> Dictionary:
	if _busy:
		return {"ok": false, "narration": "", "commands": [], "changes": {}, "errors": ["A turn is already running."]}
	_busy = true
	Game.ensure_started()
	var prompt := PromptBuilder.build(
		Game.state,
		action,
		Content.rules(),
		Content.codex_text(),
		Game.allowed_ids(),
		Content.language(),
	)
	# Read at every turn, so a change in the settings dialog applies to the
	# next turn. The key goes to the own-key connection only for this turn.
	var settings := SettingsStore.read(Content.settings_path)
	connection_notice.emit("")
	var reply := ""
	var status := ""
	if connection_for(settings) == own_key:
		own_key.api_key = settings.api_key
		reply = await own_key.generate_turn(prompt)
		own_key.api_key = ""
		status = own_key.last_status
		connection_notice.emit(status)
	else:
		reply = await adapter.generate_turn(prompt)
	_busy = false
	if reply.strip_edges().is_empty():
		if status.is_empty():
			return {"ok": false, "narration": "", "commands": [], "changes": {}, "errors": ["Cancelled."]}
		return {"ok": false, "narration": "", "commands": [], "changes": {}, "errors": [status], "status": status}
	var parsed := DmReplyParser.parse(reply, Game.allowed_ids())
	for error in parsed["errors"]:
		push_warning("DM reply: %s" % str(error))
	var result := {
		"ok": true,
		"narration": parsed["narration"],
		"commands": parsed["commands"],
		"changes": parsed["state"],
		"errors": parsed["errors"],
	}
	if not status.is_empty():
		result["status"] = status
	return result


## The connection the settings ask for. Copy-paste is the default, and the
## answer for anything that isn't a valid own-key choice.
func connection_for(settings: SettingsStore) -> AIAdapter:
	if settings.uses_own_key():
		return own_key
	return adapter


## Called by the paste dialog.
func submit_reply(text: String) -> void:
	adapter.dialog_closed.emit(text)


func cancel_reply() -> void:
	adapter.dialog_closed.emit("")
