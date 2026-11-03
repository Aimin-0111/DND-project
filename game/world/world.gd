extends Node2D
## The animated world: draws the hero's current square (64 x 64 tiles) from its
## tiles, with that square's place markers, Oda, creatures and the weather.
## It shows the state and never changes it: the end of a walk is reported with
## walk_ended, and main.gd decides what it means (SPEC-world.md). Which squares
## exist, their tiles and exits come from the map module (game/map/).

## The hero stopped after a walk (a click or a move_to) on `cell`.
signal walk_ended(cell: Vector2i)

## Tile size in pixels: one setting (team question Q10), also in movement_click.gd.
const TILE := 32
const SIZE := WorldMap.SIZE
const TILESET_TEXTURE := preload("res://content/art/tiles-placeholder.png")
## Each half of the fade between squares.
const FADE_SECONDS := 0.25
## Oda stands by her mill, so she is only drawn in the square of this place.
const ODA_PLACE := "old_mill"
const ODA_OFFSET := Vector2(0, -20)

@onready var ground: TileMapLayer = $Ground
@onready var obstacles: TileMapLayer = $Obstacles
@onready var locations: Node2D = $Locations
@onready var hero = $Hero
@onready var oda: Sprite2D = $Oda
@onready var director: Node = $SceneDirector
@onready var fade: ColorRect = $Fade/Black

## The square on screen.
var square := ""
## Walkable tiles of the square on screen (one byte per tile, 1 = walkable).
var _mask := PackedByteArray()
var _columns := 1
## Tiles in the tileset image.
var _cells := 0


func _ready() -> void:
	var tile_set := _make_tile_set(Game.world_map.tiles)
	ground.tile_set = tile_set
	obstacles.tile_set = tile_set
	director.hero = hero
	director.creatures_root = $Creatures
	director.weather_tint = $WeatherTint
	director.travel_player = _play_travel
	hero.arrived.connect(func() -> void: walk_ended.emit(hero_cell()))
	var camera: Camera2D = hero.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = SIZE * TILE
	camera.limit_bottom = SIZE * TILE
	show_state(Game.state)


## Draws the state's square with no animation: its tiles, markers, Oda, the
## hero on its tile, that square's creatures and the weather. Used at the
## start and after a load.
func show_state(state: Dictionary) -> void:
	_draw_square(str(state.get("square", "")))
	place_hero(WorldState.hero_cell(state))
	director.show_state(state)


## Puts the hero on a tile at once (no walk).
func place_hero(cell: Vector2i) -> void:
	hero.stop()
	hero.global_position = to_global(cell_position(cell))
	hero.get_node("Camera2D").reset_smoothing()


## The tile under the hero.
func hero_cell() -> Vector2i:
	return ground.local_to_map(ground.to_local(hero.global_position))


## Centre of a tile, in the world's own coordinates.
func cell_position(cell: Vector2i) -> Vector2:
	return ground.map_to_local(cell)


## The direction of the exit at `cell`, or "" (corners and inside tiles
## are never exits; a blocked border tile isn't one either).
func exit_at(cell: Vector2i) -> String:
	if not SquareGrid.is_walkable(_mask, cell):
		return ""
	return SquareGrid.exit_direction(cell)


## Walks the hero one tile inside the square from the exit it stands on and
## returns that tile (the state can take it at once; the walk takes a moment).
func step_back() -> Vector2i:
	var from := hero_cell()
	var to := SquareGrid.step_back_cell(_mask, from)
	if to != from:
		hero.walk_to(to_global(cell_position(to)))
	return to


## Clicks don't move the hero while a turn runs; locking also stops a walk
## still under way, so the state and the screen agree on the hero's tile.
func set_locked(value: bool) -> void:
	hero.locked = value
	if value:
		hero.stop()


## Plays a travel that core already applied: fade out, draw the destination,
## put the hero on the arrival tile with that square's creatures, fade in.
func _play_travel(command: Dictionary) -> void:
	var cell: Variant = command.get("cell")
	var destination := str(command.get("square", ""))
	if destination.is_empty() or not (cell is Array) or cell.size() != 2:
		return
	hero.stop()
	await _fade_to(1.0)
	_draw_square(destination)
	place_hero(Vector2i(int(cell[0]), int(cell[1])))
	director.show_state(Game.state)
	await _fade_to(0.0)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade, "color:a", alpha, FADE_SECONDS)
	await tween.finished


func _draw_square(id: String) -> void:
	square = id
	var table: TileTable = Game.world_map.tiles
	var tiles := WorldState.square_tiles(Game.state, Game.world_map, id)
	ground.clear()
	obstacles.clear()
	if tiles.size() == SIZE * SIZE:
		for y in SIZE:
			for x in SIZE:
				var cell := Vector2i(x, y)
				var tile := tiles[y * SIZE + x]
				if tile >= table.size() or table.tileset_index[tile] >= _cells:
					continue  # Unknown colour or missing picture: nothing drawn, and it blocks.
				if table.is_obstacle(tile):
					obstacles.set_cell(cell, 0, _atlas(table, tile))
					ground.set_cell(cell, 0, _atlas(table, _ground_under(tiles, table, cell)))
				else:
					ground.set_cell(cell, 0, _atlas(table, tile))
	else:
		push_warning("World: no tiles for square '%s'" % id)
	_mask = SquareGrid.walkable_mask(tiles, table)
	hero.set_grid(ground, obstacles)
	hero.grid.apply_mask(_mask, SIZE)
	_place_markers(id)
	_place_oda(id)


## The ground drawn under an obstacle: the most common ground tile around it.
func _ground_under(tiles: PackedByteArray, table: TileTable, cell: Vector2i) -> int:
	var counts := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var next := cell + Vector2i(dx, dy)
			if SquareGrid.is_inside(next):
				var tile := tiles[next.y * SIZE + next.x]
				if tile < table.size() and not table.is_obstacle(tile):
					counts[tile] = int(counts.get(tile, 0)) + 1
	var best := table.first_walkable_ground()
	var best_count := 0
	for tile in counts:
		if counts[tile] > best_count or (counts[tile] == best_count and tile < best):
			best = tile
			best_count = counts[tile]
	return best


func _place_markers(id: String) -> void:
	for child in locations.get_children():
		locations.remove_child(child)
		child.queue_free()
	for place in Game.world_map.places_in(id):
		var marker := Marker2D.new()
		marker.name = place
		marker.position = cell_position(Game.world_map.place_cell(place))
		marker.add_to_group("locations")
		locations.add_child(marker)


func _place_oda(id: String) -> void:
	oda.visible = Game.world_map.place_square(ODA_PLACE) == id
	if oda.visible:
		oda.position = cell_position(Game.world_map.place_cell(ODA_PLACE)) + ODA_OFFSET


func _atlas(table: TileTable, tile: int) -> Vector2i:
	var index := table.tileset_index[tile]
	return Vector2i(index % _columns, index / _columns)


## One atlas tile per row of tiles.csv, with its "walkable" flag.
func _make_tile_set(table: TileTable) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "walkable")
	tile_set.set_custom_data_layer_type(0, TYPE_BOOL)
	var source := TileSetAtlasSource.new()
	source.texture = TILESET_TEXTURE
	source.texture_region_size = Vector2i(TILE, TILE)
	tile_set.add_source(source, 0)
	_columns = maxi(1, TILESET_TEXTURE.get_width() / TILE)
	_cells = _columns * (TILESET_TEXTURE.get_height() / TILE)
	for i in table.size():
		var index := table.tileset_index[i]
		if index >= _cells:
			push_warning("World: tile '%s' points outside the tileset" % table.ids[i])
			continue
		var coords := Vector2i(index % _columns, index / _columns)
		if not source.has_tile(coords):
			source.create_tile(coords)
		source.get_tile_data(coords, 0).set_custom_data("walkable", table.walkable[i])
	return tile_set
