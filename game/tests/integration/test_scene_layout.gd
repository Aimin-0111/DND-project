extends RefCounted
## Loads the real main scene and checks the shell, HUD, world and path-finding.


func run() -> Array:
	var failures: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["no SceneTree available"]

	var main = load("res://main.tscn").instantiate()
	tree.root.add_child(main)
	main._fit_layout()

	if main.size.x <= 0.0:
		failures.append("main scene has no width")

	var split: HSplitContainer = main.get_node("Split")
	# split_offset is measured from the centre: 60/40 means +10% of the width.
	var expected_offset := int(main.size.x * 0.1)
	if absi(split.split_offset - expected_offset) > 2:
		failures.append("split offset should be +10%% (%d), got %d" % [expected_offset, split.split_offset])

	var story_log: RichTextLabel = main.get_node("Split/StoryPanel/VBox/StoryLog")
	if story_log.get_total_character_count() == 0:
		failures.append("story panel has no narration text")

	var hp_label: Label = main.get_node("HUDLayer/Hud/VBox/HP")
	if not hp_label.text.begins_with(Content.t("ui.hp") + " "):
		failures.append("HUD HP label was not refreshed: %s" % hp_label.text)

	var world = main.get_node("Split/WorldView/SubViewport/World")
	var ground: TileMapLayer = world.get_node("Ground")
	if ground.get_used_rect().size != Vector2i(24, 22):
		failures.append("world tile map should be 24x22, got %s" % str(ground.get_used_rect().size))

	var hero = world.get_node("Hero")
	if hero.grid == null:
		failures.append("hero has no WalkGrid")
	else:
		var bridge: Marker2D = world.get_node("Locations/mill_bridge")
		var path: Array = hero.grid.cell_path(hero.global_position, bridge.global_position)
		if path.is_empty():
			failures.append("no path from mill_road to mill_bridge")

	tree.root.remove_child(main)
	main.free()
	return failures
