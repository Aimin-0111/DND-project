extends RefCounted
## Beta-0.5 on the real main scene:
## - the new art is in use (tiles.png with variants, the edge overlays, hero.png);
## - Menu → Controls opens the Controls window; a choice turns clicks off and
##   is kept in the settings file;
## - the movement keys walk the hero one tile, and wait while the action box
##   has focus;
## - stepping on the mill's door goes inside (a smaller, indoor box, centred),
##   with the beetle placed there;
## - touching a creature opens the fight window, which can't be closed with
##   Esc; a fight played to its end writes into the state and the story.

const TEST_SETTINGS := "user://__test_beta05.cfg"


func run() -> Array:
	var failures: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["no SceneTree available"]
	var content = tree.root.get_node("Content")
	var real_settings: String = content.settings_path
	var start_language: String = content.language()
	content.settings_path = TEST_SETTINGS
	DirAccess.remove_absolute(TEST_SETTINGS)
	content.set_language("en")
	content.remember_language()
	Game.new_game(12345)
	var main = load("res://main.tscn").instantiate()
	tree.root.add_child(main)

	failures.append_array(_art_checks(main))
	failures.append_array(_controls_checks(main))
	failures.append_array(_key_checks(main))
	failures.append_array(await _door_checks(main))
	failures.append_array(await _fight_checks(main))

	tree.root.remove_child(main)
	main.free()
	for slot in ["manual", "auto"]:
		SaveSystem.delete_save(slot)
	DirAccess.remove_absolute(TEST_SETTINGS)
	content.settings_path = real_settings
	content.set_language(start_language)
	Game.new_game(12345)
	return failures


func _art_checks(main) -> Array:
	var failures: Array = []
	var world = main.world
	var source := world.ground.tile_set.get_source(0) as TileSetAtlasSource
	if source == null or not source.texture.resource_path.ends_with("tiles.png"):
		failures.append("art: the world should draw with tiles.png")
	# Grass has 4 looks: a big field uses more than one.
	var looks := {}
	for x in range(0, 12):
		var cell := Vector2i(x, 2)
		looks[world.ground.get_cell_atlas_coords(cell)] = true
	if looks.size() < 2:
		failures.append("art: a field of grass should mix its variants, got %s" % str(looks.keys()))
	var edges = world.get_node_or_null("Edges")
	if edges == null or edges._pieces.is_empty():
		failures.append("art: the Mill Road should have soft edges (path and water)")
	return failures


func _controls_checks(main) -> Array:
	var failures: Array = []
	main.menu.open()
	var button: Button = main.menu.get_node("Panel/Margin/VBox/ControlsButton")
	if button == null or button.text != "Controls":
		failures.append("controls: the menu should have a Controls entry")
		return failures
	button.pressed.emit()
	if not main.controls_window.visible or main.menu.visible:
		failures.append("controls: Menu → Controls opens the Controls window and closes the menu")
	var window: ControlsWindow = main.controls_window
	window.layout_buttons["zqsd"].pressed.emit()
	window.click_box.toggled.emit(false)
	if main.controls.layout != "zqsd" or main.world.hero.click_enabled:
		failures.append("controls: choosing Z Q S D and no clicks applies at once")
	if ControlsStore.read(TEST_SETTINGS).layout != "zqsd":
		failures.append("controls: the choice is saved in the settings file")
	window.layout_buttons["wasd"].pressed.emit()
	window.click_box.toggled.emit(true)
	window.close()
	if not main.world.hero.click_enabled:
		failures.append("controls: clicks come back on")
	return failures


func _key_checks(main) -> Array:
	var failures: Array = []
	var held := {KEY_D: true}
	var real_reader: Callable = main.key_pressed
	main.key_pressed = func(keycode: int) -> bool: return held.has(keycode)
	main.controls.layout = "wasd"
	main.action_input.grab_focus()
	if main.movement_direction() != Vector2i.ZERO:
		failures.append("keys: D doesn't move the hero while the action box has focus")
	main.action_input.release_focus()
	if main.movement_direction() != Vector2i(1, 0):
		failures.append("keys: D moves the hero right once the action box lost focus, got %s" % main.movement_direction())
	main._physics_process(0.016)
	if main.world.hero.held_direction != Vector2i(1, 0):
		failures.append("keys: main hands the direction to the hero")
	main.world_map_window.open()
	if main.movement_direction() != Vector2i(1, 0):
		failures.append("keys: the world map window doesn't stop walking")
	main.world_map_window.close()
	main.menu.open()
	if main.movement_direction() != Vector2i.ZERO:
		failures.append("keys: the hero waits while the menu is open")
	main.menu.close()
	held.clear()
	main._physics_process(0.016)
	if main.world.hero.held_direction != Vector2i.ZERO:
		failures.append("keys: letting go of D stops the hero")
	main.key_pressed = real_reader
	return failures



func _door_checks(main) -> Array:
	var failures: Array = []
	var world = main.world
	Game.state["hero_cell"] = [54, 28]
	world.place_hero(Vector2i(54, 28))
	main._on_walk_ended(Vector2i(54, 27))
	var waited := 0
	while main._busy and waited < 600:
		await Engine.get_main_loop().process_frame
		waited += 1
	if Game.state["square"] != "mill_inside" or world.square != "mill_inside":
		failures.append("door: stepping on the mill's door goes inside, got %s" % Game.state["square"])
		return failures
	if world.box_size != Vector2i(18, 12) or world.hero_cell() != Vector2i(8, 10):
		failures.append("door: inside is 18 x 12 and the hero stands at (8, 10), got %s %s" % [world.box_size, world.hero_cell()])
	if world.exit_at(Vector2i(0, 5)) != "":
		failures.append("door: a room has no edge exits")
	var camera: Camera2D = world.hero.get_node("Camera2D")
	if camera.limit_left > 0 or camera.limit_right < 18 * 32:
		failures.append("door: the camera frames the whole small room")
	var beetles: Array = world.get_node("Creatures").get_children().filter(
		func(node: Node) -> bool: return node.get_meta("creature_id", "") == "brass_beetle")
	if beetles.size() != 1:
		failures.append("door: the beetle placed in the mill is drawn")
	if not "Mill Hall" in main.story_log.get_parsed_text():
		failures.append("door: the story says where the hero went")
	return failures


func _fight_checks(main) -> Array:
	var failures: Array = []
	var world = main.world
	var beetle: Node2D = null
	for node in world.get_node("Creatures").get_children():
		if node.get_meta("creature_id", "") == "brass_beetle":
			beetle = node
	if beetle == null:
		return ["fight: no beetle to fight"]
	world.hero.global_position = beetle.global_position + Vector2(8, 0)
	world._physics_process(0.016)
	var window: FightWindow = main.fight_window
	if not window.visible or window.fight == null or window.fight.monster_id != "brass_beetle":
		failures.append("fight: touching the beetle opens the fight window")
		return failures
	if not main._busy or not world.hero.locked:
		failures.append("fight: the world and the action box wait during a fight")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	window._input(escape)
	if not window.visible:
		failures.append("fight: Esc doesn't close a fight")
	Game.state["hero"]["hp"] = 200
	Game.state["hero"]["hp_max"] = 200
	var rounds := 0
	while not window.fight.is_over() and rounds < 60:
		await window.choose("attack")
		rounds += 1
	if window.fight.result != Fight.WON:
		failures.append("fight: a 200 HP hero beats the beetle, got %s" % window.fight.result)
	if not window.continue_button.visible:
		failures.append("fight: Continue shows once the fight is over")
	var gold_before := int(Game.state["gold"])
	window.continue_button.pressed.emit()
	if window.visible or main._busy:
		failures.append("fight: Continue closes the window and frees the screen")
	if int(Game.state["gold"]) != gold_before + 6:
		failures.append("fight: the beetle's 6 gold go to the hero")
	if GameState.creatures_in(Game.state, "mill_inside") != 0:
		failures.append("fight: the defeated beetle leaves the state")
	if not "defeated Brass Beetle" in str(Game.state.get("story_summary", "")):
		failures.append("fight: the DM hears about the fight in the story so far")
	return failures
