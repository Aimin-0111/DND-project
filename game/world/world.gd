extends Node2D
## The animated world: draws the box the hero is in, a square of the world
## grid (64 x 64 tiles) or a room of any size, from its tiles, with that box's
## place markers, Oda, creatures and the weather. It shows the state and never
## changes it: the end of a step or a walk is reported with walk_ended, a
## creature the hero touches with creature_touched, and main.gd decides what
## they mean (SPEC-world.md). Which boxes exist, their tiles, exits and doors
## come from the map module (game/map/).

## The hero stopped after a step or a walk (a click, a key, a move_to) on `cell`.
signal walk_ended(cell: Vector2i)
## The hero came within reach of a creature (a fight starts).
signal creature_touched(creature: Node2D)

## Tile size in pixels: one setting (team question Q10), also in movement_click.gd.
const TILE := 32
const SIZE := WorldMap.SIZE
const TILESET_TEXTURE := preload("res://content/art/tiles.png")
## Each half of the fade between boxes.
const FADE_SECONDS := 0.25
## Oda stands by her mill, so she is only drawn in the box of this place.
const ODA_PLACE := "old_mill"
const ODA_OFFSET := Vector2(0, -20)
## A creature this close to the hero (in pixels) starts a fight.
const TOUCH_DISTANCE := 26.0
## Around a box: dark stone indoors, deep forest outdoors.
const BACKDROP_INDOOR := Color(0.07, 0.06, 0.06)
const BACKDROP_OUTDOOR := Color(0.12, 0.24, 0.1)

@onready var ground: TileMapLayer = $Ground
@onready var obstacles: TileMapLayer = $Obstacles
@onready var locations: Node2D = $Locations
@onready var hero = $Hero
@onready var oda: Sprite2D = $Oda
@onready var director: Node = $SceneDirector
@onready var fade: ColorRect = $Fade/Black

## The box on screen (a square id or a room id).
var square := ""
## Its size in tiles.
var box_size := Vector2i(SIZE, SIZE)
## Walkable tiles of the box on screen (one byte per tile, 1 = walkable).
var _mask := PackedByteArray()
var _columns := 1
## Tiles in the tileset image.
var _cells := 0
var _edges: EdgeLayer
var _backdrop: Polygon2D


func _ready() -> void:
	var tile_set := _make_tile_set(Game.world_map.tiles)
	ground.tile_set = tile_set
	obstacles.tile_set = tile_set
	_backdrop = Polygon2D.new()
	_backdrop.name = "Backdrop"
	add_child(_backdrop)
	move_child(_backdrop, 0)
	_edges = EdgeLayer.new()
	_edges.name = "Edges"
	add_child(_edges)
	move_child(_edges, ground.get_index() + 1)
	director.hero = hero
	director.creatures_root = $Creatures
	director.weather_tint = $WeatherTint
	director.travel_player = _play_travel
	hero.arrived.connect(func() -> void: walk_ended.emit(hero_cell()))
	get_viewport().size_changed.connect(_fit_camera)
	show_state(Game.state)


## Draws the state's box with no animation: its tiles, markers, Oda, the
## hero on its tile, that box's creatures and the weather. Used at the
## start, after a load and after a lost fight.
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
## are never exits; a blocked border tile isn't one either). Rooms have no
## exits on their edges: they are left through their doors.
func exit_at(cell: Vector2i) -> String:
	if Game.world_map.is_room(square) or not SquareGrid.is_walkable(_mask, cell, box_size):
		return ""
	return SquareGrid.exit_direction(cell)


## Is there a door on `cell` of the box on screen?
func door_at(cell: Vector2i) -> bool:
	return not Game.world_map.door_at(square, cell).is_empty()


## Walks the hero one tile inside the square from the exit it stands on and
## returns that tile (the state can take it at once; the walk takes a moment).
func step_back() -> Vector2i:
	var from := hero_cell()
	var to := SquareGrid.step_back_cell(_mask, from)
	if to != from:
		hero.walk_to(to_global(cell_position(to)))
	return to


## Clicks and keys don't move the hero while a turn or a fight runs; locking
## also stops a walk still under way, so the state and the screen agree on
## the hero's tile.
func set_locked(value: bool) -> void:
	hero.locked = value
	if value:
		hero.stop()


## Plays a move the state already made (a travel or a door): fade out, draw
## the destination, put the hero on the arrival tile with that box's
## creatures, fade in.
func play_arrival(destination: String, cell: Vector2i) -> void:
	hero.stop()
	await _fade_to(1.0)
	_draw_square(destination)
	place_hero(cell)
	director.show_state(Game.state)
	await _fade_to(0.0)


func _play_travel(command: Dictionary) -> void:
	var cell: Variant = command.get("cell")
	var destination := str(command.get("square", ""))
	if destination.is_empty() or not (cell is Array) or cell.size() != 2:
		return
	await play_arrival(destination, Vector2i(int(cell[0]), int(cell[1])))


func _physics_process(_delta: float) -> void:
	if hero.locked:
		return
	for creature in $Creatures.get_children():
		if creature.is_queued_for_deletion():
			continue
		var distance: float = creature.global_position.distance_to(hero.global_position)
		if creature.get_meta("calm", false):
			# A creature the hero just fled from waits until the hero is away.
			if distance > TOUCH_DISTANCE * 3.0:
				creature.set_meta("calm", false)
			continue
		if distance <= TOUCH_DISTANCE:
			hero.stop()
			creature_touched.emit(creature)
			return


## Is this creature within reach of the hero?
func is_touching(creature: Node2D) -> bool:
	return creature.global_position.distance_to(hero.global_position) <= TOUCH_DISTANCE


func _fade_to(alpha: float) -> void:

	var tween := create_tween()
	tween.tween_property(fade, "color:a", alpha, FADE_SECONDS)
	await tween.finished


func _draw_square(id: String) -> void:
	square = id
	box_size = Game.world_map.box_size(id)
	var table: TileTable = Game.world_map.tiles
	var tiles := WorldState.square_tiles(Game.state, Game.world_map, id)
	ground.clear()
	obstacles.clear()
	if tiles.size() == box_size.x * box_size.y:
		for y in box_size.y:
			for x in box_size.x:
				var cell := Vector2i(x, y)
				var tile := tiles[y * box_size.x + x]
				if tile >= table.size() or table.tileset_index[tile] >= _cells:
					continue  # Unknown colour or missing picture: nothing drawn, and it blocks.
				if table.is_obstacle(tile):
					obstacles.set_cell(cell, 0, _atlas(table, tile, cell))
					var under := _ground_under(tiles, table, cell)
					ground.set_cell(cell, 0, _atlas(table, under, cell))
				else:
					ground.set_cell(cell, 0, _atlas(table, tile, cell))
	else:
		push_warning("World: no tiles for box '%s'" % id)
	_mask = SquareGrid.walkable_mask(tiles, table)
	_edges.show_box(tiles, table, box_size)
	var indoor := Game.world_map.is_indoor(id)
	_draw_backdrop(indoor)
	director.indoor = indoor
	hero.set_grid(ground, obstacles)
	hero.grid.apply_mask(_mask, box_size.x)
	_place_markers(id)
	_place_oda(id)
	_fit_camera()


## The ground drawn under an obstacle: the most common ground tile around it.
func _ground_under(tiles: PackedByteArray, table: TileTable, cell: Vector2i) -> int:
	var counts := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var next := cell + Vector2i(dx, dy)
			if SquareGrid.is_inside(next, box_size):
				var tile := tiles[next.y * box_size.x + next.x]
				if tile < table.size() and not table.is_obstacle(tile):
					counts[tile] = int(counts.get(tile, 0)) + 1
	var best := table.first_walkable_ground()
	var best_count := 0
	for tile in counts:
		if counts[tile] > best_count or (counts[tile] == best_count and tile < best):
			best = tile
			best_count = counts[tile]
	return best


## The camera stays inside the box; a box smaller than the view is centred.
func _fit_camera() -> void:
	if not is_inside_tree():
		return
	var camera: Camera2D = hero.get_node("Camera2D")
	var view := get_viewport_rect().size / camera.zoom
	var extent := Vector2(box_size * TILE)
	var left := 0.0
	var top := 0.0
	var right := extent.x
	var bottom := extent.y
	if extent.x < view.x:
		left = (extent.x - view.x) / 2.0
		right = left + view.x
	if extent.y < view.y:
		top = (extent.y - view.y) / 2.0
		bottom = top + view.y
	camera.limit_left = floori(left)
	camera.limit_top = floori(top)
	camera.limit_right = ceili(right)
	camera.limit_bottom = ceili(bottom)


func _draw_backdrop(indoor: bool) -> void:
	var margin := 4000.0
	var extent := Vector2(box_size * TILE)
	_backdrop.polygon = PackedVector2Array([
		Vector2(-margin, -margin), Vector2(extent.x + margin, -margin),
		Vector2(extent.x + margin, extent.y + margin), Vector2(-margin, extent.y + margin),
	])
	_backdrop.color = BACKDROP_INDOOR if indoor else BACKDROP_OUTDOOR


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


## The tileset cell for a tile: one of its variants, picked from the tile's
## position so the same box always looks the same.
func _atlas(table: TileTable, tile: int, cell: Vector2i) -> Vector2i:
	var count := table.variants[tile] if tile < table.variants.size() else 1
	var index := table.tileset_index[tile]
	if count > 1:
		var pick := posmod(hash(Vector3i(cell.x, cell.y, hash(square))), count)
		if index + pick < _cells:
			index += pick
	return Vector2i(index % _columns, index / _columns)


## Every variant cell of every row of tiles.csv, with its "walkable" flag.
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
		var first := table.tileset_index[i]
		if first >= _cells:
			push_warning("World: tile '%s' points outside the tileset" % table.ids[i])
			continue
		var count := table.variants[i] if i < table.variants.size() else 1
		for index in range(first, mini(first + count, _cells)):
			var coords := Vector2i(index % _columns, index / _columns)
			if not source.has_tile(coords):
				source.create_tile(coords)
			source.get_tile_data(coords, 0).set_custom_data("walkable", table.walkable[i])
	return tile_set
