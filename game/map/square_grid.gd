class_name SquareGrid
extends RefCounted
## Geometry inside one square (64 x 64 tiles): exits, where the hero arrives,
## stepping back from an exit, which tiles connect. It works on a walkable
## mask (one byte per tile, 1 = walkable), so it needs no nodes and no files.
## Rules: SPEC-map.md.

const SIZE := WorldMap.SIZE
const OPPOSITE := {"north": "south", "south": "north", "east": "west", "west": "east"}
const NO_CELL := Vector2i(-1, -1)


## One byte per tile: 1 where the hero can walk.
static func walkable_mask(tiles: PackedByteArray, table: TileTable) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(tiles.size())
	for i in tiles.size():
		mask[i] = 1 if table.is_walkable(tiles[i]) else 0
	return mask


static func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE


static func is_walkable(mask: PackedByteArray, cell: Vector2i) -> bool:
	return is_inside(cell) and mask.size() == SIZE * SIZE and mask[cell.y * SIZE + cell.x] == 1


static func is_border(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == SIZE - 1 or cell.y == SIZE - 1


## The direction a border tile leads to; "" for corners and inside tiles.
## Whether it is an exit also needs the tile to be walkable.
static func exit_direction(cell: Vector2i) -> String:
	if not is_inside(cell):
		return ""
	var last := SIZE - 1
	if (cell.x == 0 or cell.x == last) and (cell.y == 0 or cell.y == last):
		return ""
	if cell.y == 0:
		return "north"
	if cell.y == last:
		return "south"
	if cell.x == 0:
		return "west"
	if cell.x == last:
		return "east"
	return ""


## The tiles of one edge, corners excluded, in order.
static func edge_cells(direction: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var last := SIZE - 1
	for i in range(1, last):
		match direction:
			"north":
				out.append(Vector2i(i, 0))
			"south":
				out.append(Vector2i(i, last))
			"west":
				out.append(Vector2i(0, i))
			"east":
				out.append(Vector2i(last, i))
	return out


## Where the hero arrives after travelling in `direction` from `from_cell` of
## the square left: the walkable tile of the entry edge (the opposite one)
## closest to the mirrored position, else the closest walkable tile anywhere.
## NO_CELL when the square has no walkable tile at all.
static func arrival_cell(mask: PackedByteArray, direction: String, from_cell: Vector2i) -> Vector2i:
	if not OPPOSITE.has(direction):
		return NO_CELL
	var last := SIZE - 1
	var target := Vector2i(clampi(from_cell.x, 0, last), clampi(from_cell.y, 0, last))
	match direction:
		"north":
			target.y = last
		"south":
			target.y = 0
		"east":
			target.x = 0
		"west":
			target.x = last
	var best := NO_CELL
	var best_distance := SIZE * SIZE
	for cell in edge_cells(OPPOSITE[direction]):
		var distance := absi(cell.x - target.x) + absi(cell.y - target.y)
		if is_walkable(mask, cell) and distance < best_distance:
			best = cell
			best_distance = distance
	if best != NO_CELL:
		return best
	return closest_walkable(mask, target)


## The walkable tile closest to `target` (straight-line distance; ties go to
## the first in reading order). With `inside_only`, border tiles are skipped.
static func closest_walkable(mask: PackedByteArray, target: Vector2i, inside_only: bool = false) -> Vector2i:
	var best := NO_CELL
	var best_distance := -1
	if mask.size() != SIZE * SIZE:
		return best
	for y in SIZE:
		for x in SIZE:
			if mask[y * SIZE + x] != 1:
				continue
			var cell := Vector2i(x, y)
			if inside_only and is_border(cell):
				continue
			var distance := (cell - target).length_squared()
			if best_distance == -1 or distance < best_distance:
				best = cell
				best_distance = distance
	return best


## One step inside the square from an exit: the next tile inwards if it is
## walkable, else the closest walkable tile that isn't on the border.
## A tile that isn't an exit is returned unchanged.
static func step_back_cell(mask: PackedByteArray, cell: Vector2i) -> Vector2i:
	var direction := exit_direction(cell)
	if direction.is_empty():
		return cell
	var inward: Vector2i = cell - WorldMap.DIRECTIONS[direction]
	if is_walkable(mask, inward) and not is_border(inward):
		return inward
	var nearest := closest_walkable(mask, cell, true)
	return cell if nearest == NO_CELL else nearest


## Every tile reachable from `start` by walking (1 = reached). Diagonal steps
## never cut corners in the game, so 4 directions give the same answer.
static func reachable(mask: PackedByteArray, start: Vector2i) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(SIZE * SIZE)
	if not is_walkable(mask, start):
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start.y * SIZE + start.x] = 1
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for step in WorldMap.DIRECTIONS.values():
			var next: Vector2i = cell + step
			if is_walkable(mask, next) and seen[next.y * SIZE + next.x] == 0:
				seen[next.y * SIZE + next.x] = 1
				queue.append(next)
	return seen
