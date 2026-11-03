extends RefCounted
## State v2 and travel (core): settling a new game and a Beta-0.2 save,
## travelling by direction and by id, creatures staying in their square,
## stored tiles surviving save/load, and the MAP view for the prompt.

const START := "sq_24_24"
const NORTH := "sq_24_23"

var world: WorldMap


func run() -> Array:
	var failures: Array = []
	world = MapLoader.load_world(MapLoader.MAPS_DIR, ContentLoader.load_csv("res://content/data/locations.csv"))
	failures.append_array(_settle_checks())
	failures.append_array(_travel_checks())
	failures.append_array(_command_checks())
	failures.append_array(_creature_checks())
	failures.append_array(_stored_tile_checks())
	failures.append_array(_view_checks())
	return failures


func _new_state() -> Dictionary:
	var state := GameState.new_game(12345)
	WorldState.settle(state, world)
	return state


func _settle_checks() -> Array:
	var failures: Array = []
	var state := _new_state()
	if state["square"] != START or state["hero_cell"] != [16, 31] or state["location"] != "mill_road":
		failures.append("a new game starts in %s on the mill_road marker: %s %s %s" % [
			START, state["square"], state["hero_cell"], state["location"]])
	if not state["squares"].has(START) or state["squares"][START].has("tiles"):
		failures.append("the start square is visited, and hand-made squares are never stored")

	# A Beta-0.2 save: version 1, one zone, the hero at old_mill, a wolf at the bridge.
	var text := '{"version": 1, "seed": 5, "rng_state": 9, "turn": 3, "time_minutes": 500, "location": "old_mill", "weather": "fog", "language": "en", "hero": {"hp": 7, "hp_max": 12}, "gold": 4, "pack": [], "quests": {}, "creatures": [{"id": "rust_wolf", "near": "mill_bridge"}], "last_roll": null, "story_summary": "", "log": []}'
	var old := SaveSystem.import_save_text(text)
	var notes := WorldState.settle(old, world)
	if not notes.is_empty():
		failures.append("a Beta-0.2 save should settle without notes: %s" % str(notes))
	if old.get("square") != START or old.get("hero_cell") != [54, 29] or old.get("location") != "old_mill":
		failures.append("a Beta-0.2 save puts the hero on its place's marker: %s %s %s" % [
			old.get("square"), old.get("hero_cell"), old.get("location")])
	if old["creatures"][0].get("square") != START:
		failures.append("a Beta-0.2 creature goes to the square of its place")

	# A save whose square or tile can't be used any more.
	var broken := _new_state()
	broken["square"] = "sq_36_38"
	broken["hero_cell"] = [3, 3]
	notes = WorldState.settle(broken, world)
	if broken["square"] != START or notes.size() != 1:
		failures.append("a save in a square that can't be entered goes back to the start: %s %s" % [broken["square"], notes])
	var blocked := _new_state()
	blocked["hero_cell"] = [45, 10]
	WorldState.settle(blocked, world)
	var tiles := WorldState.square_tiles(blocked, world, START)
	var cell := WorldState.hero_cell(blocked)
	if not SquareGrid.is_walkable(SquareGrid.walkable_mask(tiles, world.tiles), cell):
		failures.append("a hero saved on a blocked tile is moved to a walkable one, got %s" % cell)
	return failures


func _travel_checks() -> Array:
	var failures: Array = []
	var state := _new_state()
	state["hero_cell"] = [31, 0]
	var dice := Dice.new(77)
	var before := dice.state()
	var commands := [{"type": "travel", "to": "north"}]
	var notes := GameState.apply_commands(state, commands, dice, world)
	if not notes.is_empty():
		failures.append("travel north from the start should work: %s" % str(notes))
	if state["square"] != NORTH or state["hero_cell"] != [31, 63] or state["location"] != "":
		failures.append("travel north arrives on the south edge of %s: %s %s '%s'" % [
			NORTH, state["square"], state["hero_cell"], state["location"]])
	if commands[0].get("square") != NORTH or commands[0].get("cell") != [31, 63]:
		failures.append("the travel command should carry the destination and arrival: %s" % str(commands[0]))
	if state["squares"][START].get("cell") != [31, 0]:
		failures.append("the start square should remember the tile the hero left")
	if not (state["squares"].get(NORTH, {}).get("tiles") is Dictionary):
		failures.append("the new generated square's tiles should be stored")
	if dice.state() != before:
		failures.append("travel and generation must not use the dice")

	GameState.apply_commands(state, [{"type": "travel", "to": START}], dice, world)
	if state["square"] != START or state["hero_cell"] != [31, 0]:
		failures.append("travelling back by id puts the hero where it left: %s %s" % [state["square"], state["hero_cell"]])
	if state["squares"][NORTH].get("cell") != [31, 63]:
		failures.append("the north square should remember where the hero stood")

	var unchanged := JSON.stringify(state)
	notes = GameState.apply_commands(state, [{"type": "travel", "to": "sq_3_3"}], dice, world)
	if notes.size() != 1 or JSON.stringify(state) != unchanged:
		failures.append("travel to a square never visited changes nothing and is noted: %s" % str(notes))
	notes = GameState.apply_commands(state, [{"type": "travel", "to": START}], dice, world)
	if notes.size() != 1 or JSON.stringify(state) != unchanged:
		failures.append("travel to the current square changes nothing and is noted")

	var edge := _new_state()
	edge["square"] = "sq_36_33"
	edge["hero_cell"] = [31, 31]
	WorldState.settle(edge, world)
	notes = GameState.apply_commands(edge, [{"type": "travel", "to": "south"}], dice, world)
	if notes.size() != 1 or edge["square"] != "sq_36_33":
		failures.append("travel into the lake is refused: %s %s" % [notes, edge["square"]])

	var twice := _new_state()
	commands = [{"type": "travel", "to": "east"}, {"type": "travel", "to": "west"}]
	notes = GameState.apply_commands(twice, commands, dice, world)
	if twice["square"] != "sq_25_24" or notes.size() != 1 or commands[1].has("square"):
		failures.append("only the first travel of a turn plays: %s %s" % [twice["square"], notes])
	var no_map := _new_state()
	notes = GameState.apply_commands(no_map, [{"type": "travel", "to": "east"}], dice)
	if no_map["square"] != START or notes.size() != 1:
		failures.append("travel without a map changes nothing and is noted")
	return failures


func _command_checks() -> Array:
	var failures: Array = []
	var dice := Dice.new(5)
	var state := _new_state()
	state["hero_cell"] = [31, 0]
	GameState.apply_commands(state, [{"type": "travel", "to": "north"}], dice, world)
	# Back to the start by id, then the other commands act there.
	GameState.apply_commands(state, [
		{"type": "travel", "to": START},
		{"type": "move_to", "target": "old_mill"},
		{"type": "spawn", "creature": "rust_wolf", "near": "hero"},
	], dice, world)
	if state["square"] != START or state["location"] != "old_mill" or state["hero_cell"] != [54, 29]:
		failures.append("move_to after a travel walks to the marker in the destination: %s %s" % [state["location"], state["hero_cell"]])
	var wolf: Dictionary = state["creatures"][-1]
	if wolf.get("square") != START or wolf.get("near") != "hero" or wolf.get("cell") != [54, 29]:
		failures.append("spawn near hero keeps the square and the hero's tile: %s" % str(wolf))

	var walker := _new_state()
	WorldState.set_hero_cell(walker, world, Vector2i(43, 30))
	if walker["location"] != "mill_bridge":
		failures.append("stopping 2 tiles from the bridge marker is at mill_bridge, got '%s'" % walker["location"])
	WorldState.set_hero_cell(walker, world, Vector2i(30, 45))
	if walker["location"] != "" or walker["hero_cell"] != [30, 45]:
		failures.append("stopping far from every marker is at no place")
	return failures


func _creature_checks() -> Array:
	var failures: Array = []
	var dice := Dice.new(9)
	var state := _new_state()
	GameState.apply_commands(state, [{"type": "spawn", "creature": "rust_wolf", "near": "mill_bridge"}], dice, world)
	state["hero_cell"] = [31, 0]
	GameState.apply_commands(state, [{"type": "travel", "to": "north"}], dice, world)
	if state["creatures"].size() != 1 or state["creatures"][0]["square"] != START:
		failures.append("the wolf stays behind in the start square")
	var spawns: Array = []
	for i in 7:
		spawns.append({"type": "spawn", "creature": "rust_wolf", "near": "hero"})
	var notes := GameState.apply_commands(state, spawns, dice, world)
	if GameState.creatures_in(state, NORTH) != 6 or notes.size() != 1:
		failures.append("6 creatures fit in the new square (the one left behind doesn't count), the 7th is refused")
	GameState.apply_commands(state, [{"type": "despawn", "creature": "rust_wolf"}], dice, world)
	if GameState.creatures_in(state, NORTH) != 5 or GameState.creatures_in(state, START) != 1:
		failures.append("despawn removes a creature of the hero's square only")
	GameState.apply_commands(state, [{"type": "travel", "to": START}], dice, world)
	if GameState.creatures_in(state, START) != 1:
		failures.append("coming back finds the wolf left behind")
	return failures


func _stored_tile_checks() -> Array:
	var failures: Array = []
	var state := _new_state()
	state["hero_cell"] = [31, 0]
	GameState.apply_commands(state, [{"type": "travel", "to": "north"}], Dice.new(1), world)
	var tiles := WorldState.square_tiles(state, world, NORTH)
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(state))
	var reloaded := WorldState.square_tiles(loaded, world, NORTH)
	if reloaded != tiles:
		failures.append("stored tiles survive a JSON save and load")
	var stored: Dictionary = state["squares"][NORTH]["tiles"]
	if stored["rows"].size() != 64 or stored["rows"][0].length() != 64:
		failures.append("tiles are stored as 64 rows of 64 characters")

	# Another tile order in tiles.csv: the stored ids still mean the same tiles.
	var reordered := TileTable.new()
	for i in range(world.tiles.size() - 1, -1, -1):
		reordered.add(world.tiles.ids[i], world.tiles.colours[i], world.tiles.walkable[i], world.tiles.layers[i], world.tiles.tileset_index[i])
	var decoded := WorldState.decode_tiles(stored, reordered)
	for i in [0, 100, 2000, 4095]:
		if reordered.id_of(decoded[i]) != world.tiles.id_of(tiles[i]):
			failures.append("stored tiles keep their ids when tiles.csv is reordered")
			break

	# A stored id that no longer exists: the first walkable ground tile. The
	# legend starts with the tile of corner (0, 0), symbol "0".
	var renamed := stored.duplicate(true)
	renamed["legend"][0] = "no_such_tile"
	var fallback := WorldState.decode_tiles(renamed, world.tiles)
	if fallback.size() != 64 * 64 or fallback[0] != world.tiles.first_walkable_ground():
		failures.append("an unknown stored tile id becomes the first walkable ground tile")

	# Broken stored tiles are generated again, identically.
	state["squares"][NORTH]["tiles"] = {"legend": ["grass"], "rows": ["x"]}
	if WorldState.square_tiles(state, world, NORTH) != tiles:
		failures.append("broken stored tiles are generated again, the same as before")
	for bad in [null, "text", {"legend": [], "rows": []}, {"legend": ["grass"], "rows": ["0".repeat(64)]}]:
		if not WorldState.decode_tiles(bad, world.tiles).is_empty():
			failures.append("malformed stored tiles decode to nothing: %s" % str(bad))
	return failures


func _view_checks() -> Array:
	var failures: Array = []
	var state := _new_state()
	var view := WorldState.view(state, world)
	if view.get("square") != START or view.get("made") != "by_hand" or view.get("kind") != "road":
		failures.append("the MAP view describes the current square: %s" % str(view))
	if view.get("places") != ["mill_road", "mill_bridge", "old_mill"]:
		failures.append("the MAP view lists the square's places")
	var north: Dictionary = view["neighbours"]["north"]
	if north.get("square") != NORTH or north.get("kind") != "meadow" or not north.get("can_enter") or north.get("visited"):
		failures.append("the north neighbour is an unvisited meadow the hero can enter: %s" % str(north))
	if WorldState.travel_targets(state, world) != ["north", "east", "south", "west"]:
		failures.append("from the start, the 4 directions are the travel targets")
	state["hero_cell"] = [31, 0]
	GameState.apply_commands(state, [{"type": "travel", "to": "north"}], Dice.new(2), world)
	view = WorldState.view(state, world)
	if view.get("made") != "generated" or view.get("places") != [] or view["neighbours"]["south"].get("visited") != true:
		failures.append("after travelling north: a generated square with no places, the start visited below")
	if not START in WorldState.travel_targets(state, world):
		failures.append("a visited square is a travel target")
	var text := JSON.stringify(view)
	for secret in ["legend", "rows", "hero_cell", "\"cell\""]:
		if secret in text:
			failures.append("the MAP view must not contain %s" % secret)
	var corner := WorldState.view({"square": "sq_0_0", "squares": {}}, world)
	if corner["neighbours"]["north"].get("kind") != "outside" or corner["neighbours"]["north"].get("can_enter"):
		failures.append("a neighbour off the map is 'outside' and can't be entered")
	return failures
