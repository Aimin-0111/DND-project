extends SceneTree
## Runs saved AI DM replies through the game's real checker (DmReplyParser).
##
## Put each reply in replies/<model>/S1.txt, S2.txt... then, from a Godot
## project that contains the examples' godot/ scripts:
##   Godot_console.exe --headless --path <project> --script res://ai-tests/check_replies.gd -- haiku
##
## Prints, per reply: whether the format is OK, which commands/changes were
## kept, what was rejected, and how many effect tags were used.

const REPLIES_ROOT := "res://ai-tests/replies/"
const EFFECT_TAG := "\\[(burn|freeze|shock|poison|whisper|holy)\\]"

const ALLOWED := {
	"locations": ["mill_road", "old_mill", "mill_bridge", "mill_bridge_east", "copper_river"],
	"creatures": ["rust_wolf", "bog_ghoul", "cinder_imp", "brass_sentinel", "river_troll"],
	"items": ["rusty_sword", "hunting_bow", "leather_coat", "healing_draught", "tallow_candle", "brass_key"],
	"skills": ["Athletics", "Acrobatics", "Stealth", "Perception", "Investigation", "Persuasion", "Insight", "Survival"],
	"quests": ["the_silent_mill"],
}


func _init() -> void:
	var tag_re := RegEx.new()
	tag_re.compile(EFFECT_TAG)
	var any_tag := RegEx.new()
	any_tag.compile("\\[/?([a-z_]+)[^\\]]*\\]")

	var args := OS.get_cmdline_user_args()
	var folder := REPLIES_ROOT + (args[0] if args.size() > 0 else "haiku") + "/"
	var files := Array(DirAccess.get_files_at(folder))
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".txt"):
			continue
		var reply := FileAccess.get_file_as_string(folder + file_name)
		var r := DmReplyParser.parse(reply, ALLOWED)
		var tags := tag_re.search_all(r["narration"]).size()
		var unknown_tags := []
		for m in any_tag.search_all(r["narration"]):
			if not m.get_string(1) in ["burn", "freeze", "shock", "poison", "whisper", "holy"]:
				unknown_tags.append(m.get_string())
		print("===== %s" % file_name.get_basename())
		print("  format ok : %s" % (reply.contains(DmReplyParser.MARKER) and not _has_format_error(r["errors"])))
		print("  kept      : %s" % JSON.stringify({"commands": r["commands"], "state": r["state"]}))
		print("  rejected  : %s" % ("none" if r["errors"].is_empty() else JSON.stringify(r["errors"])))
		print("  effect tags: %d%s%s" % [tags, " (over the limit of 4)" if tags > 4 else "",
			"  unknown: %s" % str(unknown_tags) if not unknown_tags.is_empty() else ""])
	quit()


func _has_format_error(errors: Array) -> bool:
	for e in errors:
		if e.begins_with("No ") or e.begins_with("The state block"):
			return true
	return false
