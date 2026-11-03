class_name SquareGenerator
extends RefCounted
## Builds the tiles of a square nobody drew, from the save's seed, the
## square's coordinates, its kind and its neighbours' kinds. The same inputs
## always give the same tiles: it has its own random generator seeded from
## those inputs and never touches the game's dice. The result is stored in
## the save, so a later change here never alters a square already visited.
## Rules: SPEC-map.md.

const SIZE := WorldMap.SIZE
## Cells of an edge that open when the square beyond can be entered.
const OPEN_FROM := 30
const OPEN_TO := 33
## A road's path is 2 tiles wide, in the middle of the openings.
const PATH_FROM := 31
const PATH_TO := 32
const CENTRE := Vector2i(31, 31)
## Edges facing these kinds are drawn with this tile instead of the border.
const EDGE_TILES := {"lake": "water", "mountain": "rock"}
## Tiles the recipes use that block; a missing one falls back to a blocking tile.
const BLOCKING := ["tree", "rock", "reeds", "water"]
const DEFAULT_RECIPE := "meadow"
## How each kind looks. Blobs are [tile, how many, smallest radius, largest
## radius], drawn in order; scatter is [tile, chance per 1000 tiles];
## clearings are open blobs of the ground tile.
const RECIPES := {
	"meadow": {
		"ground": "grass", "border": "tree",
		"blobs": [["flowers", 10, 2, 4], ["tree", 5, 1, 3]],
		"scatter": [["tree", 12], ["rock", 4]],
		"clearings": 0,
	},
	"forest": {
		"ground": "forest_floor", "border": "tree",
		"blobs": [["grass", 6, 2, 4]],
		"scatter": [["tree", 330]],
		"clearings": 6,
	},
	"hills": {
		"ground": "grass", "border": "rock",
		"blobs": [["dirt", 14, 2, 6], ["rock", 8, 1, 3]],
		"scatter": [["rock", 40], ["tree", 8]],
		"clearings": 0,
	},
	"road": {
		"ground": "grass", "border": "tree",
		"blobs": [["flowers", 5, 2, 3], ["tree", 3, 1, 2]],
		"scatter": [["tree", 15], ["rock", 3]],
		"clearings": 0,
	},
	"marsh": {
		"ground": "mud", "border": "reeds",
		"blobs": [["grass", 8, 2, 4], ["water", 10, 2, 4], ["reeds", 6, 1, 2]],
		"scatter": [["reeds", 70]],
		"clearings": 0,
	},
}


## The tiles of square `id` of `world` (generated, never stored here).
static func generate_square(world: WorldMap, seed_value: int, id: String) -> PackedByteArray:
	return generate(seed_value, WorldMap.coords(id), world.kind_of(id), world.neighbour_info(id), world.tiles)


## `neighbours`: direction -> {"kind": String, "can_enter": bool, "hand_made": bool}.
## A missing direction counts as the outside of the map.
static func generate(seed_value: int, coords: Vector2i, kind: String, neighbours: Dictionary,
		table: TileTable) -> PackedByteArray:
	var recipe: Dictionary = RECIPES.get(kind, RECIPES[DEFAULT_RECIPE])
	var rng := RandomNumberGenerator.new()
	rng.seed = mix(seed_value, coords, kind)
	var ground := _tile(table, recipe["ground"])
	var tiles := PackedByteArray()
	tiles.resize(SIZE * SIZE)
	tiles.fill(ground)

	for blob in recipe["blobs"]:
		var tile := _tile(table, blob[0])
		for i in int(blob[1]):
			_blob(tiles, rng, tile, rng.randi_range(int(blob[2]), int(blob[3])))
	for entry in recipe["scatter"]:
		var tile := _tile(table, entry[0])
		for i in SIZE * SIZE:
			if rng.randi_range(0, 999) < int(entry[1]):
				tiles[i] = tile
	for i in int(recipe["clearings"]):
		_blob(tiles, rng, ground, rng.randi_range(3, 6))

	var open := {}
	var edge := {}
	var links: Array[String] = []
	for direction in WorldMap.DIRECTIONS:
		var info: Dictionary = neighbours.get(direction, {})
		open[direction] = bool(info.get("can_enter", false))
		edge[direction] = _tile(table, EDGE_TILES.get(str(info.get("kind", "")), recipe["border"]))
		var joins_road := str(info.get("kind", "")) == "road" or bool(info.get("hand_made", false))
		if kind == "road" and open[direction] and joins_road:
			links.append(direction)
	_rough_edges(tiles, rng, edge)
	_carve_area(tiles, table, CENTRE, 2, ground)
	for direction in open:
		if open[direction] and not direction in links:
			_carve_trail(tiles, rng, table, direction, ground)
	var path := _tile(table, "path")
	for direction in links:
		_draw_road(tiles, table, direction, path, ground)
	if kind == "road" and links.is_empty():
		for x in range(CENTRE.x - 3, CENTRE.x + 5):
			for y in range(PATH_FROM, PATH_TO + 1):
				tiles[y * SIZE + x] = path
	_close_border(tiles, edge, open, links, ground, path, _tile(table, recipe["border"]))
	_join_openings(tiles, table, open, ground)
	return tiles


## A 32-bit hash of the inputs (FNV-1a), the seed of this square's generator.
static func mix(seed_value: int, coords: Vector2i, kind: String) -> int:
	var bytes := PackedByteArray()
	for value in [seed_value, coords.x, coords.y]:
		for i in 8:
			bytes.append((value >> (i * 8)) & 0xFF)
	bytes.append_array(kind.to_utf8_buffer())
	var result := 2166136261
	for byte in bytes:
		result = ((result ^ byte) * 16777619) & 0xFFFFFFFF
	return result


## The index of a tile id; a missing id falls back to the first tile that
## walks (or blocks) the same way, so a short tiles.csv can't break generation.
static func _tile(table: TileTable, id: String) -> int:
	var index := table.index_of(id)
	if index != -1:
		return index
	var want_walkable := not id in BLOCKING
	for i in table.size():
		if table.walkable[i] == want_walkable:
			return i
	return 0


static func _blob(tiles: PackedByteArray, rng: RandomNumberGenerator, tile: int, radius: int) -> void:
	var centre := Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1))
	for y in range(centre.y - radius, centre.y + radius + 1):
		for x in range(centre.x - radius, centre.x + radius + 1):
			var cell := Vector2i(x, y)
			if SquareGrid.is_inside(cell) and (cell - centre).length_squared() <= radius * radius:
				tiles[y * SIZE + x] = tile


## A ragged second row of the edge tiles inside the border, for a natural
## edge. The tiles next to the openings are left alone.
static func _rough_edges(tiles: PackedByteArray, rng: RandomNumberGenerator, edge: Dictionary) -> void:
	for direction in WorldMap.DIRECTIONS:
		var inward: Vector2i = -WorldMap.DIRECTIONS[direction]
		for cell in SquareGrid.edge_cells(direction):
			var inner: Vector2i = cell + inward
			if rng.randi_range(0, 99) < 40 and not _in_opening(direction, inner):
				tiles[inner.y * SIZE + inner.x] = edge[direction]


static func _in_opening(direction: String, cell: Vector2i) -> bool:
	var along := cell.x if direction in ["north", "south"] else cell.y
	return along >= OPEN_FROM and along <= OPEN_TO


## Makes every tile within `radius` of `cell` walkable (blocking ones become `ground`).
static func _carve_area(tiles: PackedByteArray, table: TileTable, cell: Vector2i, radius: int, ground: int) -> void:
	if not table.is_walkable(ground):
		return
	for y in range(cell.y - radius, cell.y + radius + 1):
		for x in range(cell.x - radius, cell.x + radius + 1):
			if SquareGrid.is_inside(Vector2i(x, y)) and not table.is_walkable(tiles[y * SIZE + x]):
				tiles[y * SIZE + x] = ground


## A wandering 3-tile-wide trail from an opening to the centre.
static func _carve_trail(tiles: PackedByteArray, rng: RandomNumberGenerator, table: TileTable,
		direction: String, ground: int) -> void:
	var inward: Vector2i = -WorldMap.DIRECTIONS[direction]
	var cell := _opening_middle(direction) + inward
	for i in 2:
		_carve_area(tiles, table, cell, 1, ground)
		cell += inward
	var guard := 0
	while cell != CENTRE and guard < 1000:
		guard += 1
		_carve_area(tiles, table, cell, 1, ground)
		var delta := CENTRE - cell
		var moves: Array[Vector2i] = []
		if delta.x != 0:
			moves.append(Vector2i(signi(delta.x), 0))
		if delta.y != 0:
			moves.append(Vector2i(0, signi(delta.y)))
		var move: Vector2i = moves[rng.randi_range(0, moves.size() - 1)]
		if rng.randi_range(0, 99) < 25:
			var side := Vector2i(move.y, move.x) * (1 if rng.randi_range(0, 1) == 0 else -1)
			var drifted := cell + side
			if drifted.x >= 3 and drifted.y >= 3 and drifted.x <= SIZE - 4 and drifted.y <= SIZE - 4:
				move = side
		cell += move
	_carve_area(tiles, table, CENTRE, 1, ground)


## A straight 2-tile path from an edge to the centre, with clear shoulders.
static func _draw_road(tiles: PackedByteArray, table: TileTable, direction: String, path: int, ground: int) -> void:
	var start := _opening_middle(direction)
	var step: Vector2i = -WorldMap.DIRECTIONS[direction]
	var across := Vector2i(absi(step.y), absi(step.x))
	var cell := start
	while true:
		for offset in range(OPEN_FROM - PATH_FROM, OPEN_TO - PATH_FROM + 1):
			var at := cell + across * offset
			var index := at.y * SIZE + at.x
			if offset >= 0 and offset <= PATH_TO - PATH_FROM:
				tiles[index] = path
			elif not table.is_walkable(tiles[index]):
				tiles[index] = ground
		if (step.x != 0 and cell.x == CENTRE.x) or (step.y != 0 and cell.y == CENTRE.y):
			break
		cell += step
	# The centre block, so every road meets the others.
	for y in range(PATH_FROM, PATH_TO + 1):
		for x in range(PATH_FROM, PATH_TO + 1):
			tiles[y * SIZE + x] = path


## The first opening cell on an edge (cell PATH_FROM of the edge).
static func _opening_middle(direction: String) -> Vector2i:
	var last := SIZE - 1
	match direction:
		"north":
			return Vector2i(PATH_FROM, 0)
		"south":
			return Vector2i(PATH_FROM, last)
		"west":
			return Vector2i(0, PATH_FROM)
		_:
			return Vector2i(last, PATH_FROM)


## The border: blocked everywhere (corners included) except cells 30-33 of each
## edge facing a square the hero can enter.
static func _close_border(tiles: PackedByteArray, edge: Dictionary, open: Dictionary, links: Array[String],
		ground: int, path: int, border: int) -> void:
	for direction in WorldMap.DIRECTIONS:
		for cell in SquareGrid.edge_cells(direction):
			var along := cell.x if direction in ["north", "south"] else cell.y
			var tile: int = edge[direction]
			if open[direction] and along >= OPEN_FROM and along <= OPEN_TO:
				var on_path: bool = direction in links and along >= PATH_FROM and along <= PATH_TO
				tile = path if on_path else ground
			tiles[cell.y * SIZE + cell.x] = tile
	var last := SIZE - 1
	for corner in [Vector2i(0, 0), Vector2i(last, 0), Vector2i(0, last), Vector2i(last, last)]:
		tiles[corner.y * SIZE + corner.x] = border


## Safety net: an opening the centre can't reach gets a straight corridor.
static func _join_openings(tiles: PackedByteArray, table: TileTable, open: Dictionary, ground: int) -> void:
	var seen := SquareGrid.reachable(SquareGrid.walkable_mask(tiles, table), CENTRE)
	for direction in open:
		var start := _opening_middle(direction)
		if not open[direction] or seen[start.y * SIZE + start.x] == 1:
			continue
		var step: Vector2i = -WorldMap.DIRECTIONS[direction]
		var across := Vector2i(absi(step.y), absi(step.x))
		var cell := start + step
		while (step.x != 0 and cell.x != CENTRE.x) or (step.y != 0 and cell.y != CENTRE.y):
			_carve_area(tiles, table, cell, 0, ground)
			_carve_area(tiles, table, cell + across, 0, ground)
			cell += step
		_carve_area(tiles, table, CENTRE, 1, ground)
