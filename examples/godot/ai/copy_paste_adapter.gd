class_name CopyPasteAdapter
extends AIAdapter
## Free mode: no API key, no server. The player pastes the prompt into their
## own Claude chat and pastes the reply back (see the dialog in mockups.html).
## Keep this mode working forever: it is the fallback when everything else fails.

## The dialog emits this when it closes: the pasted reply, or "" for Cancel.
signal dialog_closed(reply_text: String)


func generate_turn(prompt: Dictionary) -> String:
	# On the web, the browser only allows clipboard access right after a
	# click, so this must start from the Act button's pressed signal.
	DisplayServer.clipboard_set(PromptBuilder.to_single_text(prompt))
	status_changed.emit("Prompt copied. Paste it into Claude, then paste the reply here.")
	# "await" on a signal pauses here until the dialog emits it,
	# and gives back the value it was emitted with.
	var reply: String = await dialog_closed
	return reply.strip_edges()
