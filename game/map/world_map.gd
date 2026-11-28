class_name WorldMap
extends RefCounted
## The loaded world: the kind of every square (one pixel of world.png each),
## the hand-made squares, the rooms, the doors between them, the creatures
## placed in them, the named places and the tile table.
## A "box" is any area the hero can stand in: a square of the world grid
## (always SIZE x SIZE tiles) or a room (any size, indoor or outdoor, off the
## grid, reached only through doors). Pure data and
## questions about it; MapLoader reads the files, so tests can build small
## worlds in code. Rules: SPEC-map.md.

## Tiles per side of a square.
const SIZE := 64
## Kind index of a world.png pixel whose colour isn't in kinds.csv.
const UNKNOWN_KIND := 255
## The reserved kind that marks hand-made squares on world.png (magenta).
const HANDMADE := "handmade"
## A place's area: tiles within this many steps of its marker, diagonals included.
const PLACE_RADIUS := 3
const DIRECTIONS := {
	"north": Vector2i(0, -1),
	"east": Vector2i(1, 0),
	"south": Vector2i(0, 1),
	"west": Vector2i(-1, 0),
}
const ID_PATTERN := "^sq_(0|[1-9][0-9]*)_(0|[1-9][0-9]*)$"
## The kinds a room can have (rooms.csv).
const ROOM_KINDS := ["indoor", "outdoor"]
## The largest room side, in tiles.
const MAX_ROOM_SIDE := 128

var width := 0
var height := 0
var tiles := TileTable.new()
var kind_ids: PackedStringArray = []
var kind_passable: Array[bool] = []
## 0xRRGGBB -> kind index.
var kind_colours := {}
## Kind index of every square, row by row (UNKNOWN_KIND for unknown colours).
var grid := PackedByteArray()
## Square id -> {"file": String, "kind": String, "tiles": PackedByteArray}.
## "tiles" is empty when the image couldn't be used.
var hand_made := {}
## Room id -> {"file": String, "kind": "indoor"/"outdoor", "size": Vector2i,
## "tiles": PackedByteArray}. "tiles" is empty when the image couldn't be used.
var rooms := {}
## Door links, both ways: {"a": box, "a_cell": Vector2i, "b": box, "b_cell": Vector2i}.
var doors: Array = []
## Creatures that stand in a box from the start: {"box", "creature", "cell"}.
var placed: Array = []
## Place id -> {"square": String, "cell": Vector2i}, in locations.csv order.
var places := {}
## Plain-words problems found while loading ("world.png: ...").
var problems: PackedStringArray = []

static var _id_re: RegEx


static func square_id(x: int, y: int) -> String:
	return "sq_%d_%d" % [x, y]


## Coordinates of a square id; (-1, -1) when the id is malformed.
static func coords(id: String) -> Vector2i:
	if _id_re == null:
		_id_re = RegEx.new()
		_id_re.compile(ID_PATTERN)
	var found := _id_re.search(id)
	if found == null:
		return Vector2i(-1, -1)
	return Vector2i(found.get_string(1).to_int(), found.get_string(2).to_int())


## Adds a kind; returns false (and adds nothing) when the id or colour is taken.
func add_kind(id: String, colour: int, passable: bool) -> bool:
	if kind_ids.has(id) or kind_colours.has(colour) or kind_ids.size() >= UNKNOWN_KIND:
		return false
	kind_colours[colour] = kind_ids.size()
	kind_ids.append(id)
	kind_passable.append(passable)
	return true


func kind_index(kind: String) -> int:
	return kind_ids.find(kind)


func is_on_map(id: String) -> bool:
	var at := coords(id)
	return at.x >= 0 and at.y >= 0 and at.x < width and at.y < height


func is_hand_made(id: String) -> bool:
	return hand_made.has(id) or rooms.has(id)


func is_room(id: String) -> bool:
	return rooms.has(id)


func is_indoor(id: String) -> bool:
	return rooms.has(id) and str(rooms[id]["kind"]) == "indoor"


## Width and height of a box in tiles: a room's own size, else a square's.
func box_size(id: String) -> Vector2i:
	if rooms.has(id):
		return rooms[id]["size"]
	return Vector2i(SIZE, SIZE)


func box_area(id: String) -> int:
	var size := box_size(id)
	return size.x * size.y


## Where a door on `cell` of `box` leads: {"to": box, "cell": Vector2i}, or {}.
func door_at(box: String, cell: Vector2i) -> Dictionary:
	for link in doors:
		if link["a"] == box and link["a_cell"] == cell:
			return {"to": link["b"], "cell": link["b_cell"]}
		if link["b"] == box and link["b_cell"] == cell:
			return {"to": link["a"], "cell": link["a_cell"]}
	return {}


## The boxes one door away from `box`, in doors.csv order, each once.
func doors_from(box: String) -> Array:
	var out: Array = []
	for link in doors:
		for side in [["a", "b"], ["b", "a"]]:
			if link[side[0]] == box and not out.has(link[side[1]]):
				out.append(link[side[1]])
	return out


## The square of the world grid a box belongs to: a square itself, or the
## square reached from a room through its doors (the closest one). "" when
## a room leads to no square.
func outdoor_square(id: String) -> String:
	if not rooms.has(id):
		return id
	var seen := {id: true}
	var queue: Array = [id]
	while not queue.is_empty():
		var box: String = queue.pop_front()
		for next in doors_from(box):
			if not rooms.has(next):
				return next
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return ""


## The creatures placed in a box from the start.
func placed_in(box: String) -> Array:
	return placed.filter(func(entry: Dictionary) -> bool: return entry["box"] == box)


## The kind a square counts as: a hand-made square's own kind from
## squares.csv, else its pixel's kind; "" outside the map or for an unknown colour.
func kind_of(id: String) -> String:
	if rooms.has(id):
		return str(rooms[id]["kind"])
	if hand_made.has(id):
		return str(hand_made[id]["kind"])
	if not is_on_map(id):
		return ""
	var at := coords(id)
	var index := grid[at.y * width + at.x]
	return kind_ids[index] if index < kind_ids.size() else ""


func is_passable_kind(kind: String) -> bool:
	var index := kind_index(kind)
	return index != -1 and kind_passable[index] and kind != HANDMADE


## Can the hero ever be in this square? Hand-made squares need a usable image;
## other squares need a kind that can be entered. Off the map: never.
func can_enter(id: String) -> bool:
	if rooms.has(id):
		return rooms[id]["tiles"].size() == box_area(id)
	if not is_on_map(id):
		return false
	if hand_made.has(id):
		return hand_made[id]["tiles"].size() == SIZE * SIZE
	return is_passable_kind(kind_of(id))


## The square next to `id` in a direction, or "" off the map.
func neighbour(id: String, direction: String) -> String:
	if not is_on_map(id) or not DIRECTIONS.has(direction):
		return ""
	var at: Vector2i = coords(id) + DIRECTIONS[direction]
	if at.x < 0 or at.y < 0 or at.x >= width or at.y >= height:
		return ""
	return square_id(at.x, at.y)


## What the generator needs to know about the four squares around `id`:
## direction -> {"square", "kind", "can_enter", "hand_made"}.
func neighbour_info(id: String) -> Dictionary:
	var out := {}
	for direction in DIRECTIONS:
		var next := neighbour(id, direction)
		out[direction] = {
			"square": next,
			"kind": kind_of(next),
			"can_enter": can_enter(next),
			"hand_made": is_hand_made(next),
		}
	return out


## A copy of a hand-made square's or a room's tiles (empty when neither, or broken).
func hand_made_tiles(id: String) -> PackedByteArray:
	if rooms.has(id):
		return (rooms[id]["tiles"] as PackedByteArray).duplicate()
	if not hand_made.has(id):
		return PackedByteArray()
	return (hand_made[id]["tiles"] as PackedByteArray).duplicate()


func add_place(place_id: String, square: String, cell: Vector2i) -> void:
	places[place_id] = {"square": square, "cell": cell}


## Place ids whose marker is in this square, in locations.csv order.
func places_in(id: String) -> Array:
	var out: Array = []
	for place_id in places:
		if places[place_id]["square"] == id:
			out.append(place_id)
	return out


func place_square(place_id: String) -> String:
	return str(places.get(place_id, {}).get("square", ""))


## The marker tile of a place, or (-1, -1).
func place_cell(place_id: String) -> Vector2i:
	return places.get(place_id, {}).get("cell", Vector2i(-1, -1))


## The place whose area holds this tile (the closest marker wins; ties go to
## the first in locations.csv), or "" between places.
func place_at(id: String, cell: Vector2i) -> String:
	var best := ""
	var best_distance := PLACE_RADIUS + 1
	for place_id in places_in(id):
		var marker: Vector2i = places[place_id]["cell"]
		var distance := maxi(absi(marker.x - cell.x), absi(marker.y - cell.y))
		if distance < best_distance:
			best = place_id
			best_distance = distance
	return best
