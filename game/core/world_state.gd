class_name WorldState
extends RefCounted
## The state side of the world map (state v2): where the hero is, travel
## between squares, the squares visited and the stored tiles of the generated
## ones. Static functions on the state Dictionary; the loaded WorldMap comes in
## as data, so nothing here reads files or touches nodes.
## Rules: SPEC-core.md (state) and SPEC-map.md (geography).

const SIZE := WorldMap.SIZE
## One character per tile in a stored row; it indexes the square's legend.
const SYMBOLS := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
## Where a game starts, and where a save whose square is gone falls back to.
const START_PLACE := "mill_road"
const MIDDLE := Vector2i(32, 32)

static var _symbol_index := {}


## The tiles of a square: a hand-made square's PNG, or a generated square's
## stored tiles. A generated square without (valid) stored tiles is generated;
## with `store` it is then stored in the save, which marks it visited, so only
## the current square or a travel destination should be stored.
static func square_tiles(state: Dictionary, world: WorldMap, id: String, store: bool = true) -> PackedByteArray:
	if world.is_hand_made(id):
		return world.hand_made_tiles(id)
	var entry: Dictionary = _visited(state).get(id, {})
	var stored := decode_tiles(entry.get("tiles"), world.tiles)
	if stored.size() == SIZE * SIZE:
		return stored
	if not world.can_enter(id):
		return PackedByteArray()
	var tiles := SquareGenerator.generate_square(world, int(state.get("seed", 0)), id)
	if store:
		_remember(state, id)["tiles"] = encode_tiles(tiles, world.tiles)
	return tiles


## Stored form of a square's tiles: a legend of tile ids and 64 rows of 64
## characters. Ids, not table positions, so reordering tiles.csv is harmless.
static func encode_tiles(tiles: PackedByteArray, table: TileTable) -> Dictionary:
	var legend: Array = []
	var symbol_of := {}
	var rows: Array = []
	for y in SIZE:
		var row := PackedStringArray()
		for x in SIZE:
			var tile := tiles[y * SIZE + x]
			if not symbol_of.has(tile):
				if legend.size() == SYMBOLS.length():
					return {}
				symbol_of[tile] = SYMBOLS[legend.size()]
				legend.append(table.id_of(tile))
			row.append(symbol_of[tile])
		rows.append("".join(row))
	return {"legend": legend, "rows": rows}


## Back from the stored form. Anything malformed gives an empty array (the
## square is then generated again, identically). A tile id that no longer
## exists becomes the first walkable ground tile.
static func decode_tiles(data: Variant, table: TileTable) -> PackedByteArray:
	if not (data is Dictionary):
		return PackedByteArray()
	var legend: Variant = data.get("legend")
	var rows: Variant = data.get("rows")
	if not (legend is Array) or not (rows is Array) or rows.size() != SIZE or legend.size() > SYMBOLS.length():
		return PackedByteArray()
	if _symbol_index.is_empty():
		for i in SYMBOLS.length():
			_symbol_index[SYMBOLS[i]] = i
	var lookup := PackedInt32Array()
	for id in legend:
		var index := table.index_of(str(id))
		lookup.append(index if index != -1 else table.first_walkable_ground())
	var out := PackedByteArray()
	out.resize(SIZE * SIZE)
	for y in SIZE:
		var row: Variant = rows[y]
		if not (row is String) or row.length() != SIZE:
			return PackedByteArray()
		for x in SIZE:
			var symbol: int = _symbol_index.get(row[x], -1)
			if symbol == -1 or symbol >= lookup.size():
				return PackedByteArray()
			out[y * SIZE + x] = lookup[symbol]
	return out


## Applies a checked travel (`to` is a direction or a visited square id).
## Returns {"ok", "square", "cell", "note"}; a refused travel changes nothing.
static func travel(state: Dictionary, world: WorldMap, to: String) -> Dictionary:
	var current := str(state.get("square", ""))
	var from_cell := hero_cell(state)
	var destination := to
	var direction := ""
	if WorldMap.DIRECTIONS.has(to):
		direction = to
		destination = world.neighbour(current, to)
		if destination.is_empty() or not world.can_enter(destination):
			return _refused("travel %s: there is no square the hero can enter that way." % to)
	elif destination == current or not _visited(state).has(destination):
		return _refused("travel: '%s' is not another square the hero has visited." % to)
	var tiles := square_tiles(state, world, destination, false)
	if tiles.size() != SIZE * SIZE:
		return _refused("travel: %s can't be entered." % destination)
	var mask := SquareGrid.walkable_mask(tiles, world.tiles)
	var arrival := SquareGrid.NO_CELL
	if direction.is_empty():
		arrival = _cell_from(_visited(state)[destination].get("cell"))
		if not SquareGrid.is_walkable(mask, arrival):
			var target := arrival if SquareGrid.is_inside(arrival) else MIDDLE
			arrival = SquareGrid.closest_walkable(mask, target)
	else:
		arrival = SquareGrid.arrival_cell(mask, direction, from_cell)
	if arrival == SquareGrid.NO_CELL:
		return _refused("travel: %s has no tile to stand on." % destination)
	if not current.is_empty():
		_remember(state, current)["cell"] = [from_cell.x, from_cell.y]
	square_tiles(state, world, destination)
	_remember(state, destination)
	state["square"] = destination
	set_hero_cell(state, world, arrival)
	return {"ok": true, "square": destination, "cell": arrival, "note": ""}


## The hero stopped on `cell`: store it, and the place whose area holds it.
static func set_hero_cell(state: Dictionary, world: WorldMap, cell: Vector2i) -> void:
	state["hero_cell"] = [cell.x, cell.y]
	if world != null:
		state["location"] = world.place_at(str(state.get("square", "")), cell)


## The hero's tile, or (-1, -1) when the state has none yet.
static func hero_cell(state: Dictionary) -> Vector2i:
	return _cell_from(state.get("hero_cell"))


## After a new game or a load: makes `square` and `hero_cell` usable (from
## `location` for a new game or a version 1 save), records the current square
## as visited, and gives creatures without a square the square of their
## place. Returns notes about anything it had to fix.
static func settle(state: Dictionary, world: WorldMap) -> Array:
	var notes: Array = []
	if not (state.get("squares") is Dictionary):
		state["squares"] = {}
	var square := str(state.get("square", ""))
	var location := str(state.get("location", ""))
	if square.is_empty() or square_tiles(state, world, square, false).size() != SIZE * SIZE:
		var fallback := world.place_square(location)
		if fallback.is_empty() or not world.can_enter(fallback):
			fallback = world.place_square(START_PLACE)
		if not square.is_empty():
			notes.append("The saved square '%s' can't be used any more: back to %s." % [square, fallback])
			state["hero_cell"] = []
		square = fallback
	if square.is_empty() or square_tiles(state, world, square, false).size() != SIZE * SIZE:
		notes.append("No start square: check locations.csv and squares.csv.")
		return notes
	state["square"] = square
	var mask := SquareGrid.walkable_mask(square_tiles(state, world, square), world.tiles)
	var cell := hero_cell(state)
	if not SquareGrid.is_walkable(mask, cell):
		var target := cell
		if world.place_square(location) == square:
			target = world.place_cell(location)
		elif not SquareGrid.is_inside(cell):
			target = MIDDLE
		cell = target if SquareGrid.is_walkable(mask, target) else SquareGrid.closest_walkable(mask, target)
	_remember(state, square)
	set_hero_cell(state, world, cell)
	var creatures: Variant = state.get("creatures")
	if creatures is Array:
		for creature in creatures:
			if creature is Dictionary and str(creature.get("square", "")).is_empty():
				var home := world.place_square(str(creature.get("near", "")))
				creature["square"] = home if not home.is_empty() else square
	return notes


## The valid `to` values of a travel this turn: the directions leading to a
## square the hero can enter, then every other visited square.
static func travel_targets(state: Dictionary, world: WorldMap) -> Array:
	var out: Array = []
	var square := str(state.get("square", ""))
	for direction in WorldMap.DIRECTIONS:
		if world.can_enter(world.neighbour(square, direction)):
			out.append(direction)
	for id in _visited(state):
		if id != square:
			out.append(id)
	return out


## The MAP part of the prompt: the current square, its four neighbours and
## the visited squares. Never the stored tiles or the hero's tile.
static func view(state: Dictionary, world: WorldMap) -> Dictionary:
	var square := str(state.get("square", ""))
	var visited := _visited(state)
	var neighbours := {}
	for direction in WorldMap.DIRECTIONS:
		var next := world.neighbour(square, direction)
		neighbours[direction] = {
			"square": next,
			"kind": world.kind_of(next) if not next.is_empty() else "outside",
			"can_enter": world.can_enter(next),
			"visited": visited.has(next),
			"places": world.places_in(next),
		}
	var visited_view: Array = []
	for id in visited:
		visited_view.append({"square": id, "kind": world.kind_of(id), "places": world.places_in(id)})
	return {
		"square": square,
		"kind": world.kind_of(square),
		"made": "by_hand" if world.is_hand_made(square) else "generated",
		"places": world.places_in(square),
		"neighbours": neighbours,
		"visited": visited_view,
	}


static func _visited(state: Dictionary) -> Dictionary:
	var squares: Variant = state.get("squares")
	return squares if squares is Dictionary else {}


## The visited entry of a square, created when missing.
static func _remember(state: Dictionary, id: String) -> Dictionary:
	if not (state.get("squares") is Dictionary):
		state["squares"] = {}
	var squares: Dictionary = state["squares"]
	if not (squares.get(id) is Dictionary):
		squares[id] = {}
	return squares[id]


## [x, y] from JSON (numbers may be floats) -> Vector2i, or (-1, -1).
static func _cell_from(value: Variant) -> Vector2i:
	if not (value is Array) or value.size() != 2:
		return SquareGrid.NO_CELL
	if typeof(value[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(value[1]) not in [TYPE_INT, TYPE_FLOAT]:
		return SquareGrid.NO_CELL
	return Vector2i(int(value[0]), int(value[1]))


static func _refused(note: String) -> Dictionary:
	return {"ok": false, "square": "", "cell": SquareGrid.NO_CELL, "note": note}
