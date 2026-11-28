extends RefCounted
## Boxes of any size (SPEC-map.md, "Rooms and doors (Beta-0.5)"):
## - rooms.csv loads indoor and outdoor rooms with their own sizes;
## - doors.csv links work both ways; the mill's front door is on the Mill Road;
## - a room belongs to the square its doors lead to (for the minimap);
## - going through a door: the hero lands beside the far door, never on it;
##   the creatures placed in a box join the state on its first visit only;
## - travel never goes to a room (rooms are reached through doors);
## - SquareGrid works on any size; a save inside a room settles inside it;
## - bad rows in rooms.csv, doors.csv and creatures.csv are reported.

const LOCATIONS := "res://content/data/locations.csv"


func run() -> Array:
	var failures: Array = []
	var world := MapLoader.load_world(MapLoader.MAPS_DIR, ContentLoader.load_csv(LOCATIONS))
	for problem in world.problems:
		failures.append("map problem: %s" % problem)
	failures.append_array(_room_checks(world))
	failures.append_array(_door_checks(world))
	failures.append_array(_grid_checks())
	failures.append_array(_bad_rows())
	return failures


func _room_checks(world: WorldMap) -> Array:
	var failures: Array = []
	var sizes := {"mill_inside": Vector2i(18, 12), "mill_cellar": Vector2i(14, 10), "mill_yard": Vector2i(24, 16)}
	for id in sizes:
		if not world.is_room(id) or world.box_size(id) != sizes[id] or not world.can_enter(id):
			failures.append("rooms: %s should be an enterable %s room, got %s" % [id, sizes[id], world.box_size(id)])
	if not world.is_indoor("mill_inside") or world.is_indoor("mill_yard") or world.kind_of("mill_yard") != "outdoor":
		failures.append("rooms: the mill is indoor, the yard outdoor")
	if world.box_size("sq_24_24") != Vector2i(64, 64) or world.is_room("sq_24_24"):
		failures.append("rooms: a square stays 64 x 64 and is not a room")
	if world.outdoor_square("mill_cellar") != "sq_24_24" or world.outdoor_square("sq_24_24") != "sq_24_24":
		failures.append("rooms: the cellar belongs to the Mill Road square, got %s" % world.outdoor_square("mill_cellar"))
	if world.place_square("cellar") != "mill_cellar":
		failures.append("rooms: the place 'cellar' is in the cellar room")
	return failures


func _door_checks(world: WorldMap) -> Array:
	var failures: Array = []
	var front := world.door_at("sq_24_24", Vector2i(54, 27))
	if front.get("to") != "mill_inside" or front.get("cell") != Vector2i(8, 11):
		failures.append("doors: the mill's front door should lead to mill_inside (8, 11), got %s" % str(front))
	var back := world.door_at("mill_inside", Vector2i(8, 11))
	if back.get("to") != "sq_24_24" or back.get("cell") != Vector2i(54, 27):
		failures.append("doors: a door works both ways, got %s" % str(back))
	if not world.door_at("sq_24_24", Vector2i(10, 10)).is_empty():
		failures.append("doors: a plain tile is no door")

	var state := GameState.new_game(5)
	WorldState.settle(state, world)
	if not state["creatures"].is_empty():
		failures.append("doors: the start square has no placed creatures")
	var result := WorldState.use_door(state, world, Vector2i(54, 27))
	if not result["ok"] or state["square"] != "mill_inside":
		failures.append("doors: the front door should take the hero inside, got %s" % str(result))
	var cell := WorldState.hero_cell(state)
	if cell != Vector2i(8, 10):
		failures.append("doors: the hero lands just inside the front door at (8, 10), got %s" % cell)
	if not world.door_at("mill_inside", cell).is_empty():
		failures.append("doors: the hero never lands on a door")
	if GameState.creatures_in(state, "mill_inside") != 1 or str(state["creatures"][0]["id"]) != "brass_beetle":
		failures.append("doors: the beetle placed in the mill joins on the first visit, got %s" % str(state["creatures"]))
	if state["location"] != "mill_hall":
		failures.append("doors: inside, the hero is at the Mill Hall, got %s" % state["location"])
	# Out and back in: the placed beetle isn't added twice.
	WorldState.use_door(state, world, Vector2i(8, 11))
	if state["square"] != "sq_24_24" or WorldState.hero_cell(state) != Vector2i(54, 28):
		failures.append("doors: out of the front door, the hero stands in front of the mill (54, 28), got %s %s" % [state["square"], WorldState.hero_cell(state)])
	WorldState.use_door(state, world, Vector2i(54, 27))
	if GameState.creatures_in(state, "mill_inside") != 1:
		failures.append("doors: placed creatures come once, got %d" % GameState.creatures_in(state, "mill_inside"))
	# Down to the cellar: the boss waits there.
	WorldState.use_door(state, world, Vector2i(12, 9))
	if state["square"] != "mill_cellar" or GameState.creatures_in(state, "mill_cellar") != 1:
		failures.append("doors: the stairs lead to the cellar and its golem")
	# Rooms are never travel targets, and travel can't leave a room by direction.
	if WorldState.travel_targets(state, world).has("mill_inside"):
		failures.append("doors: a room is never a travel target")
	if WorldState.travel(state, world, "north")["ok"] or WorldState.travel(state, world, "mill_inside")["ok"]:
		failures.append("doors: travel can't go north from a room, nor to a room")
	var view := WorldState.view(state, world)
	if view["kind"] != "indoor" or not view["doors_to"].has("mill_inside"):
		failures.append("doors: the MAP view says indoor and lists the door to the mill, got %s" % str(view))
	# A save inside a room settles inside it.
	var saved := state.duplicate(true)
	if not WorldState.settle(saved, world).is_empty() or saved["square"] != "mill_cellar" or WorldState.hero_cell(saved) != WorldState.hero_cell(state):
		failures.append("doors: a save in the cellar loads in the cellar")
	return failures


func _grid_checks() -> Array:
	var failures: Array = []
	var size := Vector2i(5, 3)
	var mask := PackedByteArray([0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0])
	if not SquareGrid.is_walkable(mask, Vector2i(2, 2), size) or SquareGrid.is_walkable(mask, Vector2i(4, 1), size):
		failures.append("grid: is_walkable on a 5 x 3 box")
	if SquareGrid.is_inside(Vector2i(5, 0), size) or not SquareGrid.is_inside(Vector2i(4, 2), size):
		failures.append("grid: is_inside on a 5 x 3 box")
	if SquareGrid.closest_walkable(mask, Vector2i(4, 0), false, size) != Vector2i(3, 1):
		failures.append("grid: closest walkable tile on a 5 x 3 box")
	if SquareGrid.beside_door(mask, Vector2i(2, 2), size, [Vector2i(2, 2)]) != Vector2i(2, 1):
		failures.append("grid: beside a door at the bottom, the hero stands above it")
	var seen := SquareGrid.reachable(mask, Vector2i(1, 1), size)
	if seen.size() != 15 or seen[12] != 1:
		failures.append("grid: reachable on a 5 x 3 box")
	return failures


## Bad rows are reported, the good ones still load.
func _bad_rows() -> Array:
	var failures: Array = []
	var world := WorldMap.new()
	world.tiles.add("grass", 0x4c9a3c, true, TileTable.GROUND, 0)
	world.width = 4
	world.height = 4
	world.rooms["hut"] = {"file": "hut.png", "kind": "indoor", "size": Vector2i(4, 3), "tiles": PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])}
	MapLoader._read_door_row({"from": "hut", "x": 1, "y": 1, "to": "nowhere", "to_x": 0, "to_y": 0}, 2, world)
	MapLoader._read_door_row({"from": "hut", "x": 9, "y": 1, "to": "sq_1_1", "to_x": 0, "to_y": 0}, 3, world)
	MapLoader._read_door_row({"from": "hut", "x": 0, "y": 2, "to": "sq_1_1", "to_x": 5, "to_y": 6}, 4, world)
	MapLoader._read_placed_row({"box": "hut", "creature": "", "x": 1, "y": 1}, 2, world)
	MapLoader._read_placed_row({"box": "hut", "creature": "rust_wolf", "x": 1, "y": 1}, 3, world)
	if world.doors.size() != 1 or world.placed.size() != 1:
		failures.append("bad rows: one good door and one good creature should load, got %d and %d" % [world.doors.size(), world.placed.size()])
	var joined := "\n".join(world.problems)
	for part in ["doors.csv line 2", "doors.csv line 3", "creatures.csv line 2"]:
		if not part in joined:
			failures.append("bad rows: '%s' should be reported in %s" % [part, joined])
	if MapLoader.read_room(Image.create(2, 9, false, Image.FORMAT_RGB8), "tiny.png", world.tiles, world.problems).size() != 0:
		failures.append("bad rows: a room smaller than 3 x 3 is refused")
	return failures
