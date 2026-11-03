extends RefCounted
## Tests for the CSV/Markdown loader.


func run() -> Array:
	var failures: Array = []

	var monsters: Array = ContentLoader.load_csv("res://content/data/monsters.csv")
	if monsters.size() != 1:
		failures.append("monsters.csv: expected 1 row, got %d" % monsters.size())
	var wolf: Dictionary = ContentLoader.by_id(monsters).get("rust_wolf", {})
	if int(wolf.get("hp", 0)) != 11:
		failures.append("rust_wolf.hp: expected 11, got %s" % str(wolf.get("hp")))
	if str(wolf.get("damage", "")) != "2d4+2":
		failures.append("rust_wolf.damage: unexpected %s" % str(wolf.get("damage")))

	var strings: Dictionary = ContentLoader.load_strings("res://content/i18n/strings.csv")
	var act: Dictionary = strings.get("ui.act", {})
	if str(act.get("fr", "")) != "Agir" or str(act.get("en", "")) != "Act":
		failures.append("ui.act: FR/EN values are wrong")

	var entries: Array = ContentLoader.load_codex("res://content/writing/fr/oda.md")
	if entries.is_empty():
		failures.append("oda.md: no codex entry parsed")
	elif not str(entries[0].get("title", "")).begins_with("Oda"):
		failures.append("oda.md: first entry is not Oda")

	return failures
