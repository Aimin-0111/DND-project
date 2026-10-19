extends RefCounted
## UI-level save/load, language toggle and responsive reparenting.


func run() -> Array:
	var failures: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["no SceneTree available"]

	var main = load("res://main.tscn").instantiate()
	tree.root.add_child(main)
	var game = tree.root.get_node("Game")
	var content = tree.root.get_node("Content")

	var language_before: String = content.language()
	main._on_language_requested()
	if content.language() == language_before:
		failures.append("language toggle did not change Content")
	main._on_language_requested()
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
	var stack: VSplitContainer = main.get_node("Stack")
	var split: HSplitContainer = main.get_node("Split")
	if not stack.visible or split.visible:
		failures.append("narrow window should use the stacked layout")
	if main.get_node("Stack/WorldView").get_parent() != stack:
		failures.append("world was not reparented into the stacked layout")

	main.size = Vector2(1280, 720)
	main._fit_layout()
	if not split.visible or stack.visible:
		failures.append("wide window should use the side-by-side layout")

	tree.root.remove_child(main)
	main.free()
	return failures
