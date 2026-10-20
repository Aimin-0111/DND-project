extends Node2D
## M1 test zone: a single hand-built tile map with three named locations.
## Tiles are painted at runtime from the placeholder tileset so the scene file
## stays readable while the artist's real tileset is not ready.

const TILE := 32
const MAP_WIDTH := 24
const MAP_HEIGHT := 22
const PATH_ROW := 11
const WATER_COLUMN := 19
const GRASS := 0
const PATH := 1
const WATER := 2
const TREE := 3
const TILESET_TEXTURE := preload("res://content/art/tiles-placeholder.png")

@onready var ground: TileMapLayer = $Ground
@onready var obstacles: TileMapLayer = $Obstacles
@onready var locations: Node2D = $Locations
@onready var hero = $Hero
@onready var oda: Sprite2D = $Oda


func _ready() -> void:
	var tile_set := _make_tile_set()
	ground.tile_set = tile_set
	obstacles.tile_set = tile_set
	_paint_map()
	hero.set_grid(ground, obstacles)
	hero.global_position = _location("mill_road")
	var director = $SceneDirector
	director.hero = hero
	director.creatures_root = $Creatures
	director.weather_tint = $WeatherTint
	var camera: Camera2D = hero.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP_WIDTH * TILE
	camera.limit_bottom = MAP_HEIGHT * TILE
	camera.reset_smoothing()
	oda.global_position = _location("old_mill") + Vector2(0, -20)


func _make_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "walkable")
	tile_set.set_custom_data_layer_type(0, TYPE_BOOL)
	var source := TileSetAtlasSource.new()
	source.texture = TILESET_TEXTURE
	source.texture_region_size = Vector2i(TILE, TILE)
	tile_set.add_source(source, 0)
	for index in 4:
		source.create_tile(Vector2i(index, 0))
		var data := source.get_tile_data(Vector2i(index, 0), 0)
		data.set_custom_data("walkable", index != TREE)
	return tile_set


func _paint_map() -> void:
	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			var cell := Vector2i(x, y)
			var tile := GRASS
			if y == PATH_ROW:
				tile = PATH
			if x == WATER_COLUMN and y != PATH_ROW:
				tile = WATER
			ground.set_cell(cell, 0, Vector2i(tile, 0))
			if _is_obstacle(x, y):
				obstacles.set_cell(cell, 0, Vector2i(TREE, 0))


func _is_obstacle(x: int, y: int) -> bool:
	if x == 0 or y == 0 or x == MAP_WIDTH - 1 or y == MAP_HEIGHT - 1:
		return true
	if x == WATER_COLUMN:
		return false
	var trees := [
		Vector2i(4, 4), Vector2i(8, 7), Vector2i(15, 5), Vector2i(6, 16),
		Vector2i(13, 17), Vector2i(21, 5), Vector2i(3, 15), Vector2i(16, 14),
	]
	return Vector2i(x, y) in trees


func _location(id: String) -> Vector2:
	var marker := locations.get_node_or_null(id) as Marker2D
	if marker == null:
		push_warning("World: no marker for location '%s'" % id)
		return hero.global_position
	return marker.global_position
