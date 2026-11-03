extends RefCounted
## Tests for the Content autoload and runtime language switch.


func run() -> Array:
	var failures: Array = []
	var previous: String = Content.language()

	Content.set_language("fr")
	if Content.t("ui.act") != "Agir":
		failures.append("FR ui.act: got '%s'" % Content.t("ui.act"))
	Content.set_language("en")
	if Content.t("ui.act") != "Act":
		failures.append("EN ui.act: got '%s'" % Content.t("ui.act"))

	var ids: Dictionary = Content.allowed_ids()
	for id in ["mill_road", "mill_bridge", "old_mill"]:
		if not id in ids.get("locations", []):
			failures.append("allowed locations missing '%s'" % id)
	if not "rust_wolf" in ids.get("creatures", []):
		failures.append("allowed creatures missing rust_wolf")
	if not "rusty_sword" in ids.get("items", []):
		failures.append("allowed items missing rusty_sword")
	if not "the_silent_mill" in ids.get("quests", []):
		failures.append("allowed quests missing the_silent_mill")
	if ids.get("npcs", []) != ["oda"]:
		failures.append("allowed npcs should be [oda], got %s" % str(ids.get("npcs")))
	if Content.t_in("ui.act", "fr") != "Agir" or Content.t_in("ui.act", "en") != "Act":
		failures.append("t_in should read the given language")

	if Content.codex_text().is_empty():
		failures.append("codex is empty")
	if Content.rules().is_empty():
		failures.append("dm-rules.md is empty")
	if Content.keywords().is_empty():
		failures.append("keywords are empty")
	if Content.t("missing.key") != "missing.key":
		failures.append("missing key should return the key")

	Content.set_language(previous)
	return failures
