class_name TileTable
extends RefCounted
## The tile colour table (content/maps/tiles.csv): what each pixel colour of a
## square means. One row per tile, so adding a tile needs no code. Filled by
## MapLoader; everything else only reads it.

## Tile index of a pixel whose colour isn't in the table. It always blocks.
const UNKNOWN := 255
const GROUND := "ground"
const OBSTACLE := "obstacle"

var ids: PackedStringArray = []
## 0xRRGGBB of each tile.
var colours: PackedInt32Array = []
var walkable: Array[bool] = []
var layers: PackedStringArray = []
## Cell of the tile in the tileset image, counted left to right, row by row.
var tileset_index: PackedInt32Array = []
var _by_id := {}
var _by_colour := {}


## Adds a tile; returns false (and adds nothing) when the id or colour is taken.
func add(id: String, colour: int, is_walkable: bool, layer: String, index: int) -> bool:
	if _by_id.has(id) or _by_colour.has(colour) or ids.size() >= UNKNOWN:
		return false
	_by_id[id] = ids.size()
	_by_colour[colour] = ids.size()
	ids.append(id)
	colours.append(colour)
	# Obstacles always block, whatever the table says.
	walkable.append(is_walkable and layer != OBSTACLE)
	layers.append(layer)
	tileset_index.append(index)
	return true


func size() -> int:
	return ids.size()


## Index of a tile id, or -1.
func index_of(id: String) -> int:
	return int(_by_id.get(id, -1))


## Index of the tile with that 0xRRGGBB colour, or UNKNOWN.
func index_of_colour(colour: int) -> int:
	return int(_by_colour.get(colour, UNKNOWN))


func id_of(index: int) -> String:
	return ids[index] if index >= 0 and index < ids.size() else ""


func is_walkable(index: int) -> bool:
	return index >= 0 and index < ids.size() and walkable[index]


func is_obstacle(index: int) -> bool:
	return index >= 0 and index < ids.size() and layers[index] == OBSTACLE


## The first walkable ground tile: the safe stand-in for a stored tile id that
## no longer exists (the hero can never get trapped by it).
func first_walkable_ground() -> int:
	for i in ids.size():
		if walkable[i] and layers[i] == GROUND:
			return i
	return UNKNOWN
