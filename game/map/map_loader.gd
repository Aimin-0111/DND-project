class_name MapLoader
extends RefCounted
## Reads the map files (content/maps/) into a WorldMap: kinds.csv, tiles.csv,
## world.png, squares.csv and the hand-made square PNGs, rooms.csv and the room
## PNGs (any size), doors.csv, creatures.csv, and the square/x/y of each place
## from locations.csv (a place's "square" may also be a room id). Problems are collected in plain words with
## the file and pixel position; nothing here stops the game.
##
## The PNGs are imported as Image so their pixels can be read in an exported
## build; a PNG imported as a texture works too (its image is read back).

const MAPS_DIR := "res://content/maps/"
## Unknown colours: positions listed per file before "and N more".
const MAX_REPORTED := 20


static func load_world(maps_dir: String = MAPS_DIR, locations: Array = []) -> WorldMap:
	var world := WorldMap.new()
	read_tiles(ContentLoader.load_csv(maps_dir + "tiles.csv"), world)
	read_kinds(ContentLoader.load_csv(maps_dir + "kinds.csv"), world)
	var image := load_image(maps_dir + "world.png")
	if image == null:
		world.problems.append("world.png: missing or not an image")
	else:
		read_grid(image, world)
	for row in ContentLoader.load_csv(maps_dir + "squares.csv"):
		_read_square_row(row, maps_dir, world)
	if FileAccess.file_exists(maps_dir + "rooms.csv"):
		for row in ContentLoader.load_csv(maps_dir + "rooms.csv"):
			_read_room_row(row, maps_dir, world)
	if FileAccess.file_exists(maps_dir + "doors.csv"):
		var line := 1
		for row in ContentLoader.load_csv(maps_dir + "doors.csv"):
			line += 1
			_read_door_row(row, line, world)
	if FileAccess.file_exists(maps_dir + "creatures.csv"):
		var line := 1
		for row in ContentLoader.load_csv(maps_dir + "creatures.csv"):
			line += 1
			_read_placed_row(row, line, world)
	for row in locations:
		_read_place_row(row, world)
	return world


## Any imported PNG as an RGB8 Image (a copy), or null.
static func load_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	var image: Image = null
	if resource is Image:
		image = (resource as Image).duplicate() as Image
	elif resource is Texture2D:
		image = (resource as Texture2D).get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGB8)
	return image


static func read_tiles(rows: Array, world: WorldMap) -> void:
	var line := 1
	for row in rows:
		line += 1
		var where := "tiles.csv line %d" % line
		var id := _text(row, "id")
		var colour := parse_colour(row.get("colour"))
		var walkable := parse_bool(row.get("walkable"))
		var layer := _text(row, "layer")
		var index: Variant = row.get("tileset_index")
		# "variants" is optional: an empty cell or a missing column means 1.
		var variants: Variant = row.get("variants")
		if variants == null:
			variants = 1
		if typeof(variants) != TYPE_INT or int(variants) < 1:
			world.problems.append("%s: variants must be a whole number of 1 or more" % where)
			variants = 1
		if id.is_empty() or colour == -1 or walkable == -1 or not layer in [TileTable.GROUND, TileTable.OBSTACLE] \
				or typeof(index) != TYPE_INT or int(index) < 0:
			world.problems.append("%s: needs an id, a #rrggbb colour, walkable true/false, layer ground/obstacle and a tileset_index" % where)
			continue
		if not world.tiles.add(id, colour, walkable == 1, layer, int(index), int(variants)):
			world.problems.append("%s: the id '%s' or the colour %s is already used" % [where, id, colour_text(colour)])


static func read_kinds(rows: Array, world: WorldMap) -> void:
	var line := 1
	for row in rows:
		line += 1
		var id := _text(row, "id")
		var colour := parse_colour(row.get("colour"))
		var passable := parse_bool(row.get("passable"))
		if id.is_empty() or colour == -1 or passable == -1:
			world.problems.append("kinds.csv line %d: needs an id, a #rrggbb colour and passable true/false" % line)
		elif not world.add_kind(id, colour, passable == 1):
			world.problems.append("kinds.csv line %d: the id '%s' or the colour %s is already used" % [line, id, colour_text(colour)])


## One pixel per square. Unknown colours make that square impossible to enter.
static func read_grid(image: Image, world: WorldMap) -> void:
	world.width = image.get_width()
	world.height = image.get_height()
	world.grid.resize(world.width * world.height)
	var unknown: Array = []
	var data := image.get_data()
	for i in world.width * world.height:
		var colour := (data[i * 3] << 16) | (data[i * 3 + 1] << 8) | data[i * 3 + 2]
		var kind: int = world.kind_colours.get(colour, WorldMap.UNKNOWN_KIND)
		world.grid[i] = kind
		if kind == WorldMap.UNKNOWN_KIND:
			unknown.append([Vector2i(i % world.width, i / world.width), colour])
	_report_unknown("world.png", unknown, "kinds.csv", world.problems)


## A hand-made square's tiles, one pixel per tile. Returns an empty array when
## the image can't be used (wrong size); unknown colours become blocking tiles.
static func read_square(image: Image, file: String, table: TileTable, problems: PackedStringArray) -> PackedByteArray:
	var size := WorldMap.SIZE
	if image.get_width() != size or image.get_height() != size:
		problems.append("squares/%s: the image is %d × %d pixels, it must be %d × %d" % [
			file, image.get_width(), image.get_height(), size, size])
		return PackedByteArray()
	return read_tiles_image(image, "squares/" + file, table, problems)


## A room's tiles: any size from 3 × 3 to MAX_ROOM_SIDE per side.
static func read_room(image: Image, file: String, table: TileTable, problems: PackedStringArray) -> PackedByteArray:
	var side := WorldMap.MAX_ROOM_SIDE
	if image.get_width() < 3 or image.get_height() < 3 or image.get_width() > side or image.get_height() > side:
		problems.append("rooms/%s: the image is %d × %d pixels, it must be from 3 × 3 to %d × %d" % [
			file, image.get_width(), image.get_height(), side, side])
		return PackedByteArray()
	return read_tiles_image(image, "rooms/" + file, table, problems)


## One tile per pixel, row by row; unknown colours become blocking tiles.
static func read_tiles_image(image: Image, where: String, table: TileTable, problems: PackedStringArray) -> PackedByteArray:
	var width := image.get_width()
	var count := width * image.get_height()
	var out := PackedByteArray()
	out.resize(count)
	var unknown: Array = []
	var data := image.get_data()
	for i in count:
		var colour := (data[i * 3] << 16) | (data[i * 3 + 1] << 8) | data[i * 3 + 2]
		var tile := table.index_of_colour(colour)
		out[i] = tile
		if tile == TileTable.UNKNOWN:
			unknown.append([Vector2i(i % width, i / width), colour])
	_report_unknown(where, unknown, "tiles.csv", problems)
	return out


## "#rrggbb" (or "rrggbb") -> 0xRRGGBB, or -1.
static func parse_colour(value: Variant) -> int:
	var text := ("" if value == null else str(value)).strip_edges().trim_prefix("#")
	if text.length() != 6 or not text.is_valid_hex_number(false):
		return -1
	return text.hex_to_int()


static func colour_text(colour: int) -> String:
	return "#%06x" % colour


## 1 for true/yes/1, 0 for false/no/0, -1 for anything else.
static func parse_bool(value: Variant) -> int:
	var text := ("" if value == null else str(value)).strip_edges().to_lower()
	if text in ["true", "yes", "1"]:
		return 1
	if text in ["false", "no", "0"]:
		return 0
	return -1


static func _read_square_row(row: Dictionary, maps_dir: String, world: WorldMap) -> void:
	var file := _text(row, "file")
	var x: Variant = row.get("x")
	var y: Variant = row.get("y")
	var kind := _text(row, "kind")
	if file.is_empty() or typeof(x) != TYPE_INT or typeof(y) != TYPE_INT or int(x) < 0 or int(y) < 0:
		world.problems.append("squares.csv: '%s' needs a file and whole x, y of 0 or more" % file)
		return
	var id := WorldMap.square_id(int(x), int(y))
	if not world.is_on_map(id):
		world.problems.append("squares.csv: %s is at (%d, %d), off the world map (%d × %d)" % [
			file, int(x), int(y), world.width, world.height])
		return
	if world.hand_made.has(id):
		world.problems.append("squares.csv: two hand-made squares at (%d, %d)" % [int(x), int(y)])
		return
	if not world.is_passable_kind(kind):
		world.problems.append("squares.csv: %s has kind '%s'; use a kind from kinds.csv that can be entered" % [file, kind])
	var tiles := PackedByteArray()
	var image := load_image(maps_dir + "squares/" + file)
	if image == null:
		world.problems.append("squares/%s: missing or not an image" % file)
	else:
		tiles = read_square(image, file, world.tiles, world.problems)
	world.hand_made[id] = {"file": file, "kind": kind, "tiles": tiles}


static func _read_place_row(row: Dictionary, world: WorldMap) -> void:
	var place_id := _text(row, "id")
	var square := _text(row, "square")
	if place_id.is_empty():
		return
	if square.is_empty():
		world.problems.append("locations.csv: '%s' has no square, so the hero can never reach it" % place_id)
		return
	var x: Variant = row.get("x")
	var y: Variant = row.get("y")
	var size := world.box_size(square)
	if typeof(x) != TYPE_INT or typeof(y) != TYPE_INT or int(x) < 0 or int(y) < 0 or int(x) >= size.x or int(y) >= size.y:
		world.problems.append("locations.csv: '%s' must have x from 0 to %d and y from 0 to %d" % [place_id, size.x - 1, size.y - 1])
		return
	var cell := Vector2i(int(x), int(y))
	if not world.is_hand_made(square):
		world.problems.append("locations.csv: '%s' is in %s, which is not a hand-made square or a room" % [place_id, square])
	else:
		var tiles := world.hand_made_tiles(square)
		if tiles.size() == size.x * size.y and not world.tiles.is_walkable(tiles[cell.y * size.x + cell.x]):
			world.problems.append("locations.csv: the marker of '%s' at (%d, %d) is on a blocked tile" % [place_id, cell.x, cell.y])
	world.add_place(place_id, square, cell)


static func _read_room_row(row: Dictionary, maps_dir: String, world: WorldMap) -> void:
	var id := _text(row, "id")
	var file := _text(row, "file")
	var kind := _text(row, "kind")
	if id.is_empty() or file.is_empty() or not kind in WorldMap.ROOM_KINDS:
		world.problems.append("rooms.csv: '%s' needs an id, a file and the kind indoor or outdoor" % id)
		return
	if WorldMap.coords(id) != Vector2i(-1, -1) or world.rooms.has(id):
		world.problems.append("rooms.csv: the id '%s' is a square id or already used" % id)
		return
	var tiles := PackedByteArray()
	var size := Vector2i.ZERO
	var image := load_image(maps_dir + "rooms/" + file)
	if image == null:
		world.problems.append("rooms/%s: missing or not an image" % file)
	else:
		tiles = read_room(image, file, world.tiles, world.problems)
		size = Vector2i(image.get_width(), image.get_height())
	world.rooms[id] = {"file": file, "kind": kind, "size": size, "tiles": tiles}


## from, x, y, to, to_x, to_y: one door link, used both ways. Both ends must
## be walkable tiles of boxes that exist.
static func _read_door_row(row: Dictionary, line: int, world: WorldMap) -> void:
	var where := "doors.csv line %d" % line
	var ends: Array = []
	for keys in [["from", "x", "y"], ["to", "to_x", "to_y"]]:
		var box := _text(row, keys[0])
		var cell := _cell(row, keys[1], keys[2])
		if not _box_cell_ok(world, box, cell):
			world.problems.append("%s: %s (%d, %d) is not a walkable tile of a square or room" % [where, box, cell.x, cell.y])
			return
		ends.append([box, cell])
	world.doors.append({"a": ends[0][0], "a_cell": ends[0][1], "b": ends[1][0], "b_cell": ends[1][1]})


## box, creature, x, y: a creature that stands there from the start.
static func _read_placed_row(row: Dictionary, line: int, world: WorldMap) -> void:
	var box := _text(row, "box")
	var creature := _text(row, "creature")
	var cell := _cell(row, "x", "y")
	if creature.is_empty() or not _box_cell_ok(world, box, cell):
		world.problems.append("creatures.csv line %d: '%s' needs a creature and a walkable x, y in a square or room" % [line, creature])
		return
	world.placed.append({"box": box, "creature": creature, "cell": cell})


static func _cell(row: Dictionary, x_key: String, y_key: String) -> Vector2i:
	var x: Variant = row.get(x_key)
	var y: Variant = row.get(y_key)
	if typeof(x) != TYPE_INT or typeof(y) != TYPE_INT:
		return Vector2i(-1, -1)
	return Vector2i(int(x), int(y))


## Is `cell` inside the box, and walkable when the box is hand-made (the
## tiles of a generated square aren't known before it is visited)?
static func _box_cell_ok(world: WorldMap, box: String, cell: Vector2i) -> bool:
	if not (world.is_room(box) or world.is_on_map(box)):
		return false
	var size := world.box_size(box)
	if not SquareGrid.is_inside(cell, size):
		return false
	if not world.is_hand_made(box):
		return true
	var tiles := world.hand_made_tiles(box)
	return tiles.size() == size.x * size.y and world.tiles.is_walkable(tiles[cell.y * size.x + cell.x])



## A cell as trimmed text ("" for an empty cell, which the CSV reader gives as null).
static func _text(row: Dictionary, key: String) -> String:
	var value: Variant = row.get(key)
	return "" if value == null else str(value).strip_edges()


static func _report_unknown(file: String, unknown: Array, table: String, problems: PackedStringArray) -> void:
	for i in mini(unknown.size(), MAX_REPORTED):
		problems.append("%s: unknown colour %s at (%d, %d); add it to %s or use a listed colour" % [
			file, colour_text(unknown[i][1]), unknown[i][0].x, unknown[i][0].y, table])
	if unknown.size() > MAX_REPORTED:
		problems.append("%s: and %d more pixels with unknown colours" % [file, unknown.size() - MAX_REPORTED])
