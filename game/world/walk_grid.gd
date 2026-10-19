class_name WalkGrid
extends RefCounted
## Path-finding over the tile map. The artist marks walkable ground tiles in
## the TileSet with a custom data layer named "walkable" (bool); anything on
## the obstacles layer blocks the way.

var astar := AStarGrid2D.new()
var ground: TileMapLayer


func _init(ground_layer: TileMapLayer, obstacles_layer: TileMapLayer = null) -> void:
	ground = ground_layer
	var area := ground.get_used_rect()
	astar.region = area
	astar.cell_size = Vector2(ground.tile_set.tile_size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for x in range(area.position.x, area.end.x):
		for y in range(area.position.y, area.end.y):
			var cell := Vector2i(x, y)
			var data := ground.get_cell_tile_data(cell)
			var blocked: bool = data == null or not bool(data.get_custom_data("walkable"))
			if obstacles_layer != null and obstacles_layer.get_cell_source_id(cell) != -1:
				blocked = true
			astar.set_point_solid(cell, blocked)


func cell_of(world_pos: Vector2) -> Vector2i:
	return ground.local_to_map(ground.to_local(world_pos))


## World position of the centre of a cell.
func world_of(cell: Vector2i) -> Vector2:
	return ground.to_global(ground.map_to_local(cell))


func is_walkable(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell)


## Cells from start to goal (both included). If the goal is unreachable, the
## path stops at the closest reachable cell instead of being empty.
func cell_path(from_world: Vector2, to_world: Vector2) -> Array[Vector2i]:
	var from := cell_of(from_world)
	var to := cell_of(to_world)
	if not astar.is_in_boundsv(from) or not astar.is_in_boundsv(to):
		return []
	return astar.get_id_path(from, to, true)
