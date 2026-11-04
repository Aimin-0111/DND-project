class_name CopyPasteAdapter
extends AIAdapter
## Free mode: no API key, no server. The player copies the prompt into a Claude
## chat, then pastes the reply back into the game (ui/paste_dialog.gd).

## The UI emits this when the dialog closes: the pasted reply, or "" on cancel.
signal dialog_closed(reply_text: String)
## The UI opens the paste window with this text. It copies the prompt only
## when the player clicks Copy prompt: browsers want a click before a copy, and
## on the web a copy made here also replaced the game's own copy of the
## clipboard, so the next Ctrl+V pasted the prompt back (bug B1).
signal prompt_ready(prompt_text: String)


func generate_turn(prompt: Dictionary) -> String:
	var text := PromptBuilder.to_single_text(prompt)
	prompt_ready.emit(text)
	var reply: String = await dialog_closed
	return reply.strip_edges()
