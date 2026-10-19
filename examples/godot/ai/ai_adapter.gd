class_name AIAdapter
extends Node
## One interface, several ways to reach the AI Dungeon Master.
## The rest of the game only ever calls:
##
##   var reply: String = await adapter.generate_turn(prompt)
##
## and doesn't know (or care) which mode is active:
##   CopyPasteAdapter - free: the player copies the prompt into a Claude chat
##   ProxyAdapter     - our Cloudflare Worker holds our API key
##   OwnKeyAdapter    - the player's own API key, stored on their device
##
## An empty string means "no reply" (cancelled, network error, refusal);
## status_changed tells the UI what to show.
## (Extends Node, not RefCounted, because HTTPRequest must be in the scene tree.)

signal status_changed(message: String)


## Override in each adapter. Must be a coroutine (use await inside).
func generate_turn(_prompt: Dictionary) -> String:
	push_error("generate_turn() is not implemented in %s" % get_script().resource_path)
	return ""
