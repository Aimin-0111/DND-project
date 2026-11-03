extends RefCounted
## Map files: the real world map, start square, tile and kind tables, place
## markers, and crafted images with unknown colours or a wrong size.

const START := "sq_24_24"


func run() -> Array:
	var failures: Array = []
	failures.append_array(_real_world_checks())
	failures.append_array(_id_checks())
	failures.append_array(_crafted_image_checks())
	failures.append_array(_parse_checks())
	return failures


func _real_world_checks() -> Array:
	var failures: Array = []
	var world := MapLoader.load_world(MapLoader.MAPS_DIR, ContentLoader.load_csv("res://content/data/locations.csv"))
	if not world.problems.is_empty():
		failures.append("the real map files should load cleanly: %s" % str(world.problems))
	if world.width != 48 or world.height != 48:
		failures.append("world.png should be 48 x 48, got %d x %d" % [world.width, world.height])
	for kind in ["meadow", "forest", "hills", "road", "marsh", "lake", "mountain", "handmade"]:
		if world.kind_index(kind) == -1:
			failures.append("kinds.csv is missing '%s'" % kind)
	var seen := {}
	for index in world.grid:
		seen[index] = true
	if seen.has(WorldMap.UNKNOWN_KIND):
		failures.append("world.png has pixels of unknown colours")
	if seen.size() != world.kind_ids.size():
		failures.append("world.png should use every kind, uses %d of %d" % [seen.size(), world.kind_ids.size()])

	if not world.is_hand_made(START) or not world.can_enter(START):
		failures.append("the start square %s should be a hand-made square the hero can enter" % START)
	if world.kind_of(START) != "road":
		failures.append("the start square counts as a road, got '%s'" % world.kind_of(START))
	if world.places_in(START) != ["mill_road", "mill_bridge", "old_mill"]:
		failures.append("the start square should hold the 3 places, got %s" % str(world.places_in(START)))
	if world.place_cell("mill_road") != Vector2i(16, 31) or world.place_square("old_mill") != START:
		failures.append("place markers come from locations.csv")
	if world.place_at(START, Vector2i(18, 33)) != "mill_road":
		failures.append("a tile 2 steps from mill_road is in its area")
	if world.place_at(START, Vector2i(30, 10)) != "":
		failures.append("a tile far from every marker is at no place")

	var tiles := world.hand_made_tiles(START)
	if tiles.size() != WorldMap.SIZE * WorldMap.SIZE:
		failures.append("the start square should have 64 x 64 tiles")
	else:
		for place in world.places_in(START):
			var cell := world.place_cell(place)
			if not world.tiles.is_walkable(tiles[cell.y * WorldMap.SIZE + cell.x]):
				failures.append("the marker of %s should be on a walkable tile" % place)
		var walkable_exits := 0
		for i in range(30, 34):
			for cell in [Vector2i(i, 0), Vector2i(i, 63), Vector2i(0, i), Vector2i(63, i)]:
				if world.tiles.is_walkable(tiles[cell.y * WorldMap.SIZE + cell.x]):
					walkable_exits += 1
		if walkable_exits != 16:
			failures.append("the start square should have exits on cells 30-33 of all 4 edges, found %d tiles" % walkable_exits)

	for direction in WorldMap.DIRECTIONS:
		var next := world.neighbour(START, direction)
		if not world.can_enter(next):
			failures.append("the start square's %s neighbour %s should be enterable" % [direction, next])
	if world.kind_of(world.neighbour(START, "west")) != "road" or world.kind_of(world.neighbour(START, "east")) != "road":
		failures.append("the road should run west and east of the start square")
	if world.can_enter("sq_36_38") or world.kind_of("sq_36_38") != "lake":
		failures.append("the lake square sq_36_38 should not be enterable")
	if world.can_enter("sq_40_5") or world.kind_of("sq_40_5") != "mountain":
		failures.append("the mountain square sq_40_5 should not be enterable")
	if world.can_enter("sq_48_10") or world.neighbour("sq_47_10", "east") != "" or world.neighbour("sq_0_10", "west") != "":
		failures.append("squares off the map don't exist")

	var water := world.tiles.index_of("water")
	var tree := world.tiles.index_of("tree")
	var bridge := world.tiles.index_of("bridge")
	if world.tiles.is_walkable(water) or world.tiles.is_walkable(tree) or not world.tiles.is_walkable(bridge):
		failures.append("water and trees block, the bridge doesn't")
	if not world.tiles.is_obstacle(tree) or world.tiles.is_obstacle(water):
		failures.append("trees are on the obstacle layer, water on the ground layer")
	return failures


func _id_checks() -> Array:
	var failures: Array = []
	if WorldMap.square_id(3, 40) != "sq_3_40" or WorldMap.coords("sq_3_40") != Vector2i(3, 40):
		failures.append("square ids should round-trip")
	for bad in ["sq_-1_2", "sq_01_2", "square_1_2", "sq_1", "sq_1_2_3", "SQ_1_2", ""]:
		if WorldMap.coords(bad) != Vector2i(-1, -1):
			failures.append("'%s' should be refused as a square id" % bad)
	return failures


func _crafted_image_checks() -> Array:
	var failures: Array = []
	var world := WorldMap.new()
	MapLoader.read_kinds([
		{"id": "meadow", "colour": "#8fd16a", "passable": "true"},
		{"id": "lake", "colour": "#3a7bd5", "passable": "false"},
		{"id": "meadow", "colour": "#000001", "passable": "true"},
	], world)
	if world.problems.size() != 1:
		failures.append("a repeated kind id should be reported once: %s" % str(world.problems))
	var image := Image.create(3, 2, false, Image.FORMAT_RGB8)
	image.fill(Color.html("#8fd16a"))
	image.set_pixel(2, 1, Color.html("#123456"))
	image.set_pixel(0, 1, Color.html("#3a7bd5"))
	MapLoader.read_grid(image, world)
	var found := false
	for problem in world.problems:
		if "world.png" in problem and "#123456" in problem and "(2, 1)" in problem:
			found = true
	if not found:
		failures.append("an unknown colour should be reported with its position: %s" % str(world.problems))
	if world.can_enter("sq_2_1") or not world.can_enter("sq_1_1") or world.can_enter("sq_0_1"):
		failures.append("unknown colours and lakes can't be entered, meadows can")

	var table := TileTable.new()
	table.add("grass", 0x4c9a3c, true, TileTable.GROUND, 0)
	var problems := PackedStringArray()
	var square := Image.create(64, 64, false, Image.FORMAT_RGB8)
	square.fill(Color.html("#4c9a3c"))
	square.set_pixel(5, 7, Color.html("#ff0000"))
	var tiles := MapLoader.read_square(square, "test.png", table, problems)
	if problems.size() != 1 or not "(5, 7)" in problems[0] or not "#ff0000" in problems[0]:
		failures.append("an unknown tile colour should be reported with its position: %s" % str(problems))
	if tiles.size() != 64 * 64 or table.is_walkable(tiles[7 * 64 + 5]) or not table.is_walkable(tiles[0]):
		failures.append("a tile of unknown colour should block, the others not")

	problems.clear()
	var many := Image.create(64, 64, false, Image.FORMAT_RGB8)
	many.fill(Color.html("#ff0000"))
	MapLoader.read_square(many, "red.png", table, problems)
	if problems.size() != MapLoader.MAX_REPORTED + 1 or not "4076 more" in problems[-1]:
		failures.append("unknown colours should be listed 20 times, then counted: %s" % str(problems[-1] if not problems.is_empty() else ""))

	problems.clear()
	var small := Image.create(32, 32, false, Image.FORMAT_RGB8)
	if not MapLoader.read_square(small, "small.png", table, problems).is_empty() or problems.size() != 1:
		failures.append("a square image that isn't 64 x 64 should be refused and reported")
	return failures


func _parse_checks() -> Array:
	var failures: Array = []
	if MapLoader.parse_colour("#4C9A3C") != 0x4c9a3c or MapLoader.parse_colour("4c9a3c") != 0x4c9a3c:
		failures.append("colours read as #rrggbb, any case")
	for bad in ["#4c9a3", "green", "", null, "#4c9a3cff"]:
		if MapLoader.parse_colour(bad) != -1:
			failures.append("'%s' is not a colour" % str(bad))
	if MapLoader.colour_text(0x0a0b0c) != "#0a0b0c":
		failures.append("colour_text should give #rrggbb")
	if MapLoader.parse_bool("TRUE") != 1 or MapLoader.parse_bool(0) != 0 or MapLoader.parse_bool("maybe") != -1:
		failures.append("true/false cells are read as yes, no or invalid")
	var table := TileTable.new()
	if not table.add("wall", 0x4a3f3a, true, TileTable.OBSTACLE, 6) or table.is_walkable(0):
		failures.append("an obstacle tile always blocks")
	if table.add("wall", 0x111111, true, TileTable.GROUND, 1) or table.add("floor", 0x4a3f3a, true, TileTable.GROUND, 1):
		failures.append("a repeated tile id or colour should be refused")
	return failures
