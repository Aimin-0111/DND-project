class_name AIAdapter
extends Node
## One interface, several ways to reach the AI Dungeon Master.
## The rest of the game only calls generate_turn(prompt) and awaits a String.
## An empty string means cancelled, failed or refused.

signal status_changed(message: String)


## Override in each adapter. Must be a coroutine when it awaits a signal.
func generate_turn(_prompt: Dictionary) -> String:
	push_error("AIAdapter.generate_turn is not implemented")
	return ""
