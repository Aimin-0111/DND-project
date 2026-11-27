extends RefCounted
## The real main scene with the grid of squares: drawing the start square and
## a generated one, Oda, camera limits, the top bar's place, an exit sending
## the automatic travel turn (cancelled: the hero steps back, the typed text
## comes back), an exit facing a square that can't be entered, and a load
## restoring the square and the hero's tile.

const TEST_SETTINGS := "user://__test_squares_settings.cfg"
const SLOT := "__test_squares"
const START := "sq_24_24"
const NORTH := "sq_24_23"


func run() -> Array:
	var failures: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["no SceneTree available"]
	var content = tree.root.get_node("Content")
	var real_settings: String = content.settings_path
	content.settings_path = TEST_SETTINGS
	content.remember_language()
	Game.new_game(12345)
	var main = load("res://main.tscn").instantiate()
	tree.root.add_child(main)
	var world = main.get_node("Layout/Split/WorldPanel/WorldView/SubViewport/World")

	failures.append_array(_start_square_checks(main, world))
	failures.append_array(_exit_turn_checks(main, world))
	failures.append_array(_blocked_exit_checks(main, world))
	failures.append_array(_generated_square_checks(main, world))
	failures.append_array(_load_checks(main, world))

	tree.root.remove_child(main)
	main.free()
	SaveSystem.delete_save(SLOT)
	DirAccess.remove_absolute(TEST_SETTINGS)
	content.settings_path = real_settings
	Game.new_game(12345)
	return failures


func _start_square_checks(main, world) -> Array:
	var failures: Array = []
	var ground: TileMapLayer = world.get_node("Ground")
	if world.square != START or ground.get_used_rect() != Rect2i(0, 0, 64, 64):
		failures.append("the start square should be drawn 64 x 64, got %s %s" % [world.square, ground.get_used_rect()])
	var camera: Camera2D = world.get_node("Hero/Camera2D")
	if camera.limit_left != 0 or camera.limit_top != 0 or camera.limit_right != 2048 or camera.limit_bottom != 2048:
		failures.append("the camera should stay inside the 2048 px square")
	if world.hero_cell() != Vector2i(16, 31):
		failures.append("the hero starts on the mill_road marker, got %s" % world.hero_cell())
	for place in ["mill_road", "mill_bridge", "old_mill"]:
		if world.get_node_or_null("Locations/" + place) == null:
			failures.append("the start square should have a marker for %s" % place)
	if not world.get_node("Oda").visible:
		failures.append("Oda is in the square of the old mill")
	var hero = world.get_node("Hero")
	for place in ["mill_bridge", "old_mill"]:
		var marker: Marker2D = world.get_node("Locations/" + place)
		if hero.grid.cell_path(hero.global_position, marker.global_position).back() != hero.grid.cell_of(marker.global_position):
			failures.append("the hero should be able to walk from mill_road to %s" % place)
	var water := ground.local_to_map(Vector2(45 * 32 + 16, 10 * 32 + 16))
	if hero.grid.is_walkable(water) or not hero.grid.is_walkable(Vector2i(45, 31)):
		failures.append("the river blocks and the bridge doesn't")
	if abs(hero.speed - 5.0 * 32.0) > 0.01:
		failures.append("the hero walks at 5 tiles per second")
	var place_label: Label = main.get_node("Layout/TopBar/HBox/Info/Place")
	if place_label.text != Content.t("location.mill_road.name"):
		failures.append("the top bar shows the place, got '%s'" % place_label.text)
	return failures


func _exit_turn_checks(main, world) -> Array:
	var failures: Array = []
	world.place_hero(Vector2i(31, 0))
	main.action_input.text = "carefully"
	var lines_before: String = main.story_log.get_parsed_text()
	main._on_walk_ended(Vector2i(31, 0))
	var expected: String = main.exit_action("north", "meadow") + " carefully"
	if not main._busy or not world.get_node("Hero").locked:
		failures.append("an exit sends a turn at once, and the hero is locked during it")
	if not main.story_log.get_parsed_text().substr(lines_before.length()).contains("> " + expected):
		failures.append("the story should show the automatic action '%s'" % expected)
	if not main.dialog.visible or not main.dialog.prompt_text.text.contains(expected):
		failures.append("copy-paste mode opens the paste window with the automatic action in the prompt")
	if not main.dialog.prompt_text.text.contains("=== MAP ==="):
		failures.append("the prompt should have the MAP part")
	main.dialog._on_cancel()
	if main._busy or world.get_node("Hero").locked:
		failures.append("a cancelled turn unlocks")
	if Game.state["hero_cell"] != [31, 1] or Game.state["square"] != START:
		failures.append("a cancelled exit turn steps the hero back one tile: %s" % str(Game.state["hero_cell"]))
	if main.action_input.text != "carefully":
		failures.append("a cancelled turn gives the typed text back, got '%s'" % main.action_input.text)

	world.place_hero(Vector2i(20, 20))
	main._on_walk_ended(Vector2i(20, 20))
	if main._busy:
		failures.append("a walk ending inside the square sends no turn")
	return failures


## The north neighbour turned into a lake: the start square's north exit
## now faces a square that can't be entered.
func _blocked_exit_checks(main, world) -> Array:
	var failures: Array = []
	var map: WorldMap = Game.world_map
	var at := WorldMap.coords(NORTH)
	var index := at.y * map.width + at.x
	var kind_before := map.grid[index]
	map.grid[index] = map.kind_index("lake")
	world.place_hero(Vector2i(32, 0))
	main._on_walk_ended(Vector2i(32, 0))
	if main._busy:
		failures.append("an exit facing a lake sends no turn")
	if main.status_label.text != Content.t("ui.way_blocked"):
		failures.append("an exit facing a lake says the way is blocked")
	if Game.state["hero_cell"] != [32, 1]:
		failures.append("the hero steps back from a blocked exit: %s" % str(Game.state["hero_cell"]))
	map.grid[index] = kind_before
	return failures


## A travel the state applied (as after a reply), then the world drawn from it.
func _generated_square_checks(main, world) -> Array:
	var failures: Array = []
	Game.set_hero_cell(Vector2i(31, 0))
	var notes: Array = Game.apply_turn({}, [{"type": "travel", "to": "north"}])
	if not notes.is_empty() or Game.state["square"] != NORTH:
		failures.append("travel north should apply: %s" % str(notes))
		return failures
	world.show_state(Game.state)
	var ground: TileMapLayer = world.get_node("Ground")
	if world.square != NORTH or ground.get_used_rect() != Rect2i(0, 0, 64, 64):
		failures.append("the generated square should be drawn 64 x 64")
	if world.hero_cell() != Vector2i(31, 63):
		failures.append("the hero stands on the arrival tile (31, 63), got %s" % world.hero_cell())
	if world.get_node("Oda").visible or world.get_node("Locations").get_child_count() != 0:
		failures.append("a generated square has no Oda and no markers")
	var hero = world.get_node("Hero")
	var tiles: PackedByteArray = Game.square_tiles()
	var mismatches := 0
	for y in 64:
		for x in 64:
			if hero.grid.is_walkable(Vector2i(x, y)) != Game.world_map.tiles.is_walkable(tiles[y * 64 + x]):
				mismatches += 1
	if mismatches != 0:
		failures.append("walkable tiles on screen should match tiles.csv, %d differ" % mismatches)
	var place_label: Label = main.get_node("Layout/TopBar/HBox/Info/Place")
	if place_label.text != Content.t("kind.meadow.name"):
		failures.append("in a generated square the top bar shows its kind, got '%s'" % place_label.text)
	if world.exit_at(Vector2i(0, 0)) != "" or world.exit_at(Vector2i(31, 63)) != "south" or world.exit_at(Vector2i(10, 0)) != "":
		failures.append("exits: corners and blocked border tiles aren't exits, the open south edge is")
	return failures


func _load_checks(main, world) -> Array:
	var failures: Array = []
	Game.set_hero_cell(Vector2i(31, 62))
	Game.save(SLOT)
	var saved_square := str(Game.state["square"])
	Game.apply_turn({}, [{"type": "travel", "to": START}])
	world.show_state(Game.state)
	if not Game.load(SLOT):
		failures.append("the test save should load")
		return failures
	main._after_load(Content.t("ui.loaded"))
	if world.square != saved_square or world.hero_cell() != Vector2i(31, 62):
		failures.append("loading puts the hero back in %s on (31, 62), got %s %s" % [saved_square, world.square, world.hero_cell()])
	return failures
