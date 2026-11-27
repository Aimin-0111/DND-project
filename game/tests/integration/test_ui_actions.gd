extends RefCounted
## UI-level save/load, first-launch language, the language switch (Menu →
## Language) and responsive reparenting.

const TEST_SETTINGS := "user://__test_settings.cfg"


func run() -> Array:
	var failures: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["no SceneTree available"]

	var game = tree.root.get_node("Game")
	var content = tree.root.get_node("Content")
	var real_settings: String = content.settings_path
	content.settings_path = TEST_SETTINGS
	DirAccess.remove_absolute(TEST_SETTINGS)
	var main = load("res://main.tscn").instantiate()
	tree.root.add_child(main)

	var picker = main.get_node_or_null("DialogLayer/LanguagePicker")
	if picker == null:
		failures.append("first launch should ask for the language")
	else:
		var start_language: String = content.language()
		var other := "en" if start_language == "fr" else "fr"
		picker.find_child(other, true, false).pressed.emit()
		if content.language() != other or not content.has_language_choice():
			failures.append("picking a language should apply and remember it")
		_switch_language(main, content)
		if content.language() != start_language:
			failures.append("toggling back should restore the start language")

	var language_before: String = content.language()
	_switch_language(main, content)
	if content.language() == language_before:
		failures.append("language toggle did not change Content")
	_switch_language(main, content)
	if content.language() != language_before:
		failures.append("second language toggle did not restore Content")

	game.state["gold"] = 77
	main._on_save()
	game.state["gold"] = 1
	main._on_load()
	if int(game.state["gold"]) != 77:
		failures.append("save/load UI did not restore gold")
	SaveSystem.delete_save("manual")

	main.size = Vector2(800, 720)
	main._fit_layout()
	var stack: VSplitContainer = main.get_node("Layout/Stack")
	var split: HSplitContainer = main.get_node("Layout/Split")
	if not stack.visible or split.visible:
		failures.append("narrow window should use the stacked layout")
	var world_view = main.get_node_or_null("Layout/Stack/WorldPanel/WorldView")
	if world_view == null or world_view.get_parent().get_parent() != stack or main.story_panel.get_parent() != stack:
		failures.append("world was not reparented into the stacked layout")

	main.size = Vector2(1280, 720)
	main._fit_layout()
	if not split.visible or stack.visible:
		failures.append("wide window should use the side-by-side layout")
	if split.get_child(0) != main.story_panel or split.get_child(1) != main.world_panel:
		failures.append("side by side, the story is on the left and the world on the right")

	tree.root.remove_child(main)
	main.free()
	DirAccess.remove_absolute(TEST_SETTINGS)
	content.settings_path = real_settings
	return failures


## Menu → the other language's entry.
func _switch_language(main, content) -> void:
	var other := "en" if content.language() == "fr" else "fr"
	main.menu.get_node("Panel/Margin/VBox/Languages/" + other).pressed.emit()
