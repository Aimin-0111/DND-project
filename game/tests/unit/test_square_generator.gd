extends RefCounted
## Square generator and square geometry: the same inputs give the same tiles,
## every open exit reaches every other one, closed edges are closed, corners
## are blocked, roads join their road and hand-made neighbours; arrival,
## stepping back and exits.

const SIZE := WorldMap.SIZE
const KINDS := ["meadow", "forest", "hills", "road", "marsh"]
const SEEDS := [1, 7, 12345, 99991]

var table: TileTable


func run() -> Array:
	var failures: Array = []
	var world := WorldMap.new()
	MapLoader.read_tiles(ContentLoader.load_csv("res://content/maps/tiles.csv"), world)
	table = world.tiles
	failures.append_array(_determinism_checks())
	failures.append_array(_property_checks())
	failures.append_array(_edge_tile_checks())
	failures.append_array(_geometry_checks())
	return failures


func _determinism_checks() -> Array:
	var failures: Array = []
	var around := _neighbours({"north": "meadow", "east": "road", "south": "forest", "west": "lake"})
	var first := SquareGenerator.generate(12345, Vector2i(5, 9), "road", around, table)
	var again := SquareGenerator.generate(12345, Vector2i(5, 9), "road", around, table)
	if first != again:
		failures.append("the same inputs should give the same tiles")
	if first == SquareGenerator.generate(12346, Vector2i(5, 9), "road", around, table):
		failures.append("another seed should give other tiles")
	if first == SquareGenerator.generate(12345, Vector2i(6, 9), "road", around, table):
		failures.append("other coordinates should give other tiles")
	if first == SquareGenerator.generate(12345, Vector2i(5, 9), "meadow", around, table):
		failures.append("another kind should give other tiles")

	# Generation has its own random generator: the game's dice and Godot's
	# global random numbers are untouched.
	var dice := Dice.new(42)
	var dice_before := dice.state()
	seed(99)
	var expected := randi()
	seed(99)
	SquareGenerator.generate(1, Vector2i(2, 3), "forest", around, table)
	if randi() != expected or dice.state() != dice_before:
		failures.append("generation must not use the dice or the global random numbers")
	return failures


## Many seeds, every kind, several neighbour layouts.
func _property_checks() -> Array:
	var failures: Array = []
	var layouts := [
		_neighbours({"north": "meadow", "east": "meadow", "south": "meadow", "west": "meadow"}),
		_neighbours({"north": "lake", "east": "mountain", "south": "", "west": "road"}),
		_neighbours({"north": "road", "east": "", "south": "handmade_road", "west": ""}),
		_neighbours({"north": "hills", "east": "forest", "south": "lake", "west": "marsh"}),
		_neighbours({"north": "road", "east": "road", "south": "road", "west": "road"}),
		_neighbours({"north": "", "east": "", "south": "", "west": ""}),
	]
	var checked := 0
	for seed_value in SEEDS:
		for kind in KINDS:
			for around in layouts:
				var tiles := SquareGenerator.generate(seed_value, Vector2i(seed_value % 40, 3), kind, around, table)
				var label := "%s seed %d %s" % [kind, seed_value, _layout_name(around)]
				failures.append_array(_check_square(tiles, kind, around, label))
				checked += 1
				if failures.size() > 10:
					return failures
	if checked != SEEDS.size() * KINDS.size() * layouts.size():
		failures.append("not every square was checked")
	return failures


func _check_square(tiles: PackedByteArray, kind: String, around: Dictionary, label: String) -> Array:
	var failures: Array = []
	if tiles.size() != SIZE * SIZE:
		return ["%s: should have 64 x 64 tiles" % label]
	var mask := SquareGrid.walkable_mask(tiles, table)
	for corner in [Vector2i(0, 0), Vector2i(SIZE - 1, 0), Vector2i(0, SIZE - 1), Vector2i(SIZE - 1, SIZE - 1)]:
		if SquareGrid.is_walkable(mask, corner):
			failures.append("%s: corner %s should be blocked" % [label, corner])
	var openings: Array[Vector2i] = []
	for direction in WorldMap.DIRECTIONS:
		var open: bool = around[direction]["can_enter"]
		var walkable: Array[int] = []
		for cell in SquareGrid.edge_cells(direction):
			if SquareGrid.is_walkable(mask, cell):
				walkable.append(cell.x if direction in ["north", "south"] else cell.y)
		if open and walkable != [30, 31, 32, 33]:
			failures.append("%s: the %s edge should be open exactly on 30-33, got %s" % [label, direction, walkable])
		elif not open and not walkable.is_empty():
			failures.append("%s: the %s edge should be closed, open at %s" % [label, direction, walkable])
		if open:
			openings.append(SquareGrid.edge_cells(direction)[29])
	if not openings.is_empty():
		var seen := SquareGrid.reachable(mask, openings[0])
		for cell in openings:
			if seen[cell.y * SIZE + cell.x] != 1:
				failures.append("%s: exit %s can't be reached from exit %s" % [label, cell, openings[0]])
	if kind == "road":
		failures.append_array(_check_road(tiles, around, label))
	return failures


## Each edge facing a road or hand-made square has the path, and the path
## alone leads from there to the centre.
func _check_road(tiles: PackedByteArray, around: Dictionary, label: String) -> Array:
	var failures: Array = []
	var path := table.index_of("path")
	var path_mask := PackedByteArray()
	path_mask.resize(SIZE * SIZE)
	for i in tiles.size():
		path_mask[i] = 1 if tiles[i] == path else 0
	var centre := Vector2i(31, 31)
	if path_mask[centre.y * SIZE + centre.x] != 1:
		failures.append("%s: a road square should have path in the middle" % label)
		return failures
	var seen := SquareGrid.reachable(path_mask, centre)
	for direction in WorldMap.DIRECTIONS:
		var info: Dictionary = around[direction]
		var links: bool = info["can_enter"] and (info["kind"] == "road" or info["hand_made"])
		var cell: Vector2i = SquareGrid.edge_cells(direction)[30]
		if links and seen[cell.y * SIZE + cell.x] != 1:
			failures.append("%s: the path should join the %s edge" % [label, direction])
		if not links and tiles[cell.y * SIZE + cell.x] == path:
			failures.append("%s: no path should lead %s" % [label, direction])
	return failures


func _edge_tile_checks() -> Array:
	var failures: Array = []
	var around := _neighbours({"north": "lake", "east": "mountain", "south": "", "west": "meadow"})
	var tiles := SquareGenerator.generate(3, Vector2i(1, 1), "meadow", around, table)
	var water := table.index_of("water")
	var rock := table.index_of("rock")
	var tree := table.index_of("tree")
	for cell in SquareGrid.edge_cells("north"):
		if tiles[cell.y * SIZE + cell.x] != water:
			failures.append("an edge facing a lake should be water")
			break
	for cell in SquareGrid.edge_cells("east"):
		if tiles[cell.y * SIZE + cell.x] != rock:
			failures.append("an edge facing a mountain should be rock")
			break
	for cell in SquareGrid.edge_cells("south"):
		if tiles[cell.y * SIZE + cell.x] != tree:
			failures.append("an edge facing the outside should be the meadow's border (trees)")
			break
	return failures


func _geometry_checks() -> Array:
	var failures: Array = []
	var cases := [
		[Vector2i(0, 0), ""], [Vector2i(63, 0), ""], [Vector2i(0, 63), ""], [Vector2i(63, 63), ""],
		[Vector2i(31, 0), "north"], [Vector2i(1, 0), "north"], [Vector2i(31, 63), "south"],
		[Vector2i(0, 31), "west"], [Vector2i(0, 62), "west"], [Vector2i(63, 31), "east"],
		[Vector2i(31, 31), ""], [Vector2i(1, 1), ""], [Vector2i(64, 3), ""], [Vector2i(-1, 3), ""],
	]
	for entry in cases:
		if SquareGrid.exit_direction(entry[0]) != entry[1]:
			failures.append("exit_direction(%s) should be '%s'" % [entry[0], entry[1]])

	# Arrival: the entry edge's walkable tile closest to the mirrored position.
	var mask := _mask([])
	for x in range(20, 26):
		mask[63 * SIZE + x] = 1
	var arrivals := [
		[Vector2i(12, 0), Vector2i(20, 63)],
		[Vector2i(23, 0), Vector2i(23, 63)],
		[Vector2i(40, 5), Vector2i(25, 63)],
	]
	for entry in arrivals:
		var got := SquareGrid.arrival_cell(mask, "north", entry[0])
		if got != entry[1]:
			failures.append("travelling north from %s should arrive at %s, got %s" % [entry[0], entry[1], got])
	var east_mask := _mask([Vector2i(0, 40), Vector2i(0, 10)])
	if SquareGrid.arrival_cell(east_mask, "east", Vector2i(63, 33)) != Vector2i(0, 40):
		failures.append("travelling east arrives on the west edge, closest to the row left")
	var closed := _mask([Vector2i(40, 5), Vector2i(10, 10)])
	if SquareGrid.arrival_cell(closed, "south", Vector2i(37, 63)) != Vector2i(40, 5):
		failures.append("a closed entry edge arrives on the closest walkable tile")
	if SquareGrid.arrival_cell(_mask([]), "west", Vector2i(0, 5)) != SquareGrid.NO_CELL:
		failures.append("a square with no walkable tile has no arrival")
	if SquareGrid.arrival_cell(mask, "up", Vector2i(3, 3)) != SquareGrid.NO_CELL:
		failures.append("an unknown direction has no arrival")
	var corner_mask := _mask([Vector2i(0, 63), Vector2i(5, 63)])
	if SquareGrid.arrival_cell(corner_mask, "north", Vector2i(0, 0)) != Vector2i(5, 63):
		failures.append("the hero never arrives on a corner of the entry edge")

	# Stepping back from an exit.
	var open := _mask([Vector2i(31, 0), Vector2i(31, 1), Vector2i(32, 1), Vector2i(32, 2)])
	if SquareGrid.step_back_cell(open, Vector2i(31, 0)) != Vector2i(31, 1):
		failures.append("stepping back from a north exit goes one tile south")
	var blocked := _mask([Vector2i(31, 0), Vector2i(33, 1), Vector2i(34, 2)])
	if SquareGrid.step_back_cell(blocked, Vector2i(31, 0)) != Vector2i(33, 1):
		failures.append("when the tile inwards blocks, step back to the closest walkable tile off the border")
	if SquareGrid.step_back_cell(open, Vector2i(32, 2)) != Vector2i(32, 2):
		failures.append("a tile that isn't an exit doesn't move")

	var seen := SquareGrid.reachable(open, Vector2i(31, 0))
	if seen.count(1) != 4:
		failures.append("reachable should find the 4 connected tiles, found %d" % seen.count(1))
	if SquareGrid.reachable(open, Vector2i(5, 5)).count(1) != 0:
		failures.append("nothing is reachable from a blocked tile")
	return failures


## direction -> kind ("" = outside the map, "handmade_road" = a hand-made road square).
func _neighbours(kinds: Dictionary) -> Dictionary:
	var out := {}
	for direction in kinds:
		var kind: String = kinds[direction]
		var hand_made := kind == "handmade_road"
		if hand_made:
			kind = "road"
		out[direction] = {
			"kind": kind,
			"can_enter": kind in KINDS,
			"hand_made": hand_made,
		}
	return out


func _layout_name(around: Dictionary) -> String:
	var parts: Array[String] = []
	for direction in around:
		parts.append("%s=%s" % [direction.left(1), around[direction]["kind"] if around[direction]["kind"] != "" else "out"])
	return ",".join(parts)


func _mask(walkable: Array) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(SIZE * SIZE)
	for cell in walkable:
		mask[cell.y * SIZE + cell.x] = 1
	return mask
