class_name MapLoader
extends RefCounted
## Reads the map files (content/maps/) into a WorldMap: kinds.csv, tiles.csv,
## world.png, squares.csv, the hand-made square PNGs, and the square/x/y of
## each place from locations.csv. Problems are collected in plain words with
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
		if id.is_empty() or colour == -1 or walkable == -1 or not layer in [TileTable.GROUND, TileTable.OBSTACLE] \
				or typeof(index) != TYPE_INT or int(index) < 0:
			world.problems.append("%s: needs an id, a #rrggbb colour, walkable true/false, layer ground/obstacle and a tileset_index" % where)
			continue
		if not world.tiles.add(id, colour, walkable == 1, layer, int(index)):
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
	var out := PackedByteArray()
	out.resize(size * size)
	var unknown: Array = []
	var data := image.get_data()
	for i in size * size:
		var colour := (data[i * 3] << 16) | (data[i * 3 + 1] << 8) | data[i * 3 + 2]
		var tile := table.index_of_colour(colour)
		out[i] = tile
		if tile == TileTable.UNKNOWN:
			unknown.append([Vector2i(i % size, i / size), colour])
	_report_unknown("squares/" + file, unknown, "tiles.csv", problems)
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
	var size := WorldMap.SIZE
	if typeof(x) != TYPE_INT or typeof(y) != TYPE_INT or int(x) < 0 or int(y) < 0 or int(x) >= size or int(y) >= size:
		world.problems.append("locations.csv: '%s' must have x and y from 0 to %d" % [place_id, size - 1])
		return
	var cell := Vector2i(int(x), int(y))
	if not world.hand_made.has(square):
		world.problems.append("locations.csv: '%s' is in %s, which is not a hand-made square" % [place_id, square])
	else:
		var tiles: PackedByteArray = world.hand_made[square]["tiles"]
		if tiles.size() == size * size and not world.tiles.is_walkable(tiles[cell.y * size + cell.x]):
			world.problems.append("locations.csv: the marker of '%s' at (%d, %d) is on a blocked tile" % [place_id, cell.x, cell.y])
	world.add_place(place_id, square, cell)


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
