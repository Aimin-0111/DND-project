extends Node
## Autoload: builds the prompt, asks the active adapter for a reply and parses
## it. It never changes the state or the scene; the shell does that after the
## narration is read.

signal prompt_ready(prompt_text: String)
signal status_changed(message: String)

var adapter: CopyPasteAdapter
var _busy := false


func _ready() -> void:
	adapter = CopyPasteAdapter.new()
	add_child(adapter)
	adapter.prompt_ready.connect(func(text: String) -> void: prompt_ready.emit(text))
	adapter.status_changed.connect(func(message: String) -> void: status_changed.emit(message))


## Returns {ok, narration, commands, changes, errors}. Only an empty reply
## is a failed turn. Otherwise bad commands and changes are dropped one by one
## and listed in errors (the debug log); the rest still applies.
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
	var reply: String = await adapter.generate_turn(prompt)
	_busy = false
	if reply.strip_edges().is_empty():
		return {"ok": false, "narration": "", "commands": [], "changes": {}, "errors": ["Cancelled."]}
	var parsed := DmReplyParser.parse(reply, Game.allowed_ids())
	for error in parsed["errors"]:
		push_warning("DM reply: %s" % str(error))
	return {
		"ok": true,
		"narration": parsed["narration"],
		"commands": parsed["commands"],
		"changes": parsed["state"],
		"errors": parsed["errors"],
	}


## Called by the paste dialog.
func submit_reply(text: String) -> void:
	adapter.dialog_closed.emit(text)


func cancel_reply() -> void:
	adapter.dialog_closed.emit("")
