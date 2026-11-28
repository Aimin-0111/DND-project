class_name EdgeLayer
extends Node2D
## Soft edges between terrains, drawn over the ground and under the
## obstacles: grass spills over the edges of paths, dirt, sand and mud, and
## foam runs along the shores of water. Without it, every terrain change is a
## hard square line. The pictures are content/art/edges.png: row 0 the grass
## fringe, row 1 the foam, each in the order N, E, S, W, NE, SE, SW, NW.
## Which tiles take part is a list here; the artist only paints the pictures.

const TILE := 32
const TEXTURE := preload("res://content/art/edges.png")
## Tiles that spill grass onto their neighbours. Trees and bushes stand on grass.
const GRASSY := ["grass", "flowers", "tall_grass", "forest_floor", "tree", "bush"]
## Tiles that get the grass fringe on their edges.
const FRINGED := ["path", "dirt", "sand", "mud"]
## Water gets foam where it meets anything but water or a bridge.
const WATER := "water"
const NOT_SHORE := ["water", "bridge", "reeds"]
const SIDES := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const CORNERS := {"NE": ["N", "E"], "SE": ["S", "E"], "SW": ["S", "W"], "NW": ["N", "W"]}
const ORDER := ["N", "E", "S", "W", "NE", "SE", "SW", "NW"]

## [cell, row, column] of every overlay to draw.
var _pieces: Array = []


## Works out the overlays of a box from its tiles, then redraws.
func show_box(tiles: PackedByteArray, table: TileTable, size: Vector2i) -> void:
	_pieces.clear()
	if tiles.size() == size.x * size.y:
		for y in size.y:
			for x in size.x:
				var cell := Vector2i(x, y)
				var id := table.id_of(tiles[y * size.x + x])
				if id in FRINGED:
					_add(cell, 0, func(next_id: String) -> bool: return next_id in GRASSY, tiles, table, size)
				elif id == WATER:
					_add(cell, 1, func(next_id: String) -> bool: return not next_id.is_empty() and not next_id in NOT_SHORE, tiles, table, size)
	queue_redraw()


func _add(cell: Vector2i, row: int, other: Callable, tiles: PackedByteArray, table: TileTable, size: Vector2i) -> void:
	var touching := {}
	for side in SIDES:
		touching[side] = other.call(_id_at(cell + SIDES[side], tiles, table, size))
		if touching[side]:
			_pieces.append([cell, row, ORDER.find(side)])
	for corner in CORNERS:
		var pair: Array = CORNERS[corner]
		if touching[pair[0]] or touching[pair[1]]:
			continue
		var diagonal: Vector2i = SIDES[pair[0]] + SIDES[pair[1]]
		if other.call(_id_at(cell + diagonal, tiles, table, size)):
			_pieces.append([cell, row, ORDER.find(corner)])


func _id_at(cell: Vector2i, tiles: PackedByteArray, table: TileTable, size: Vector2i) -> String:
	if not SquareGrid.is_inside(cell, size):
		return ""
	return table.id_of(tiles[cell.y * size.x + cell.x])


func _draw() -> void:
	for piece in _pieces:
		var cell: Vector2i = piece[0]
		var target := Rect2(Vector2(cell * TILE), Vector2(TILE, TILE))
		var source := Rect2(piece[2] * TILE, piece[1] * TILE, TILE, TILE)
		draw_texture_rect_region(TEXTURE, target, source)
