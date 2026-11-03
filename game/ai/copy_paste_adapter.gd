class_name CopyPasteAdapter
extends AIAdapter
## Free mode: no API key, no server. The player copies the prompt into a Claude
## chat, then pastes the reply back into the game.

## The UI emits this when the dialog closes: the pasted reply, or "" on cancel.
signal dialog_closed(reply_text: String)
## The UI shows this text in a selectable box if the clipboard is unavailable.
signal prompt_ready(prompt_text: String)


func generate_turn(prompt: Dictionary) -> String:
	var text := PromptBuilder.to_single_text(prompt)
	DisplayServer.clipboard_set(text)
	status_changed.emit("Prompt copied. Paste it into Claude, then paste the reply here.")
	prompt_ready.emit(text)
	var reply: String = await dialog_closed
	return reply.strip_edges()
