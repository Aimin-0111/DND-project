extends RefCounted
## Loads the real main scene and checks the shell, the bars, the world and
## path-finding.
## A test settings file with a language already picked: the intro line only
## shows once the language is known (SPEC-main-screen, bug B5).

const TEST_SETTINGS := "user://__test_scene_layout.cfg"


func run() -> Array:
	var failures: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["no SceneTree available"]
	var content = tree.root.get_node("Content")
	var real_settings: String = content.settings_path
	content.settings_path = TEST_SETTINGS
	content.remember_language()

	var main = load("res://main.tscn").instantiate()
	tree.root.add_child(main)
	main._fit_layout()

	if main.size.x <= 0.0:
		failures.append("main scene has no width")

	var split: HSplitContainer = main.get_node("Layout/Split")
	# split_offset is measured from the centre: story 40 / world 60 means -10% of the width.
	var expected_offset := int(main.size.x * -0.1)
	if absi(split.split_offset - expected_offset) > 2:
		failures.append("split offset should be -10%% (%d), got %d" % [expected_offset, split.split_offset])

	var story_log: RichTextLabel = main.get_node("Layout/Split/StoryPanel/VBox/StoryLog")
	if story_log.get_total_character_count() == 0:
		failures.append("story panel has no narration text")

	# The bottom bar's HP bar: "HP" and the hero's numbers.
	var hp_bar = main.get_node("Layout/BottomBar/HBox/HP")
	var hero_state: Dictionary = Game.state["hero"]
	if hp_bar.get_node("Name").text != Content.t("ui.hp") or hp_bar.get_node("Value").text != "%d/%d" % [int(hero_state["hp"]), int(hero_state["hp_max"])]:
		failures.append("the HP bar was not refreshed: %s %s" % [hp_bar.get_node("Name").text, hp_bar.get_node("Value").text])

	var world = main.get_node("Layout/Split/WorldPanel/WorldView/SubViewport/World")
	var ground: TileMapLayer = world.get_node("Ground")
	if ground.get_used_rect().size != Vector2i(64, 64):
		failures.append("world tile map should be one 64x64 square, got %s" % str(ground.get_used_rect().size))

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
	DirAccess.remove_absolute(TEST_SETTINGS)
	content.settings_path = real_settings
	return failures
