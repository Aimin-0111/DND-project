extends RefCounted
## Path-finding with a small runtime TileSet and an obstacle layer.


func run() -> Array:
	var failures: Array = []
	var ground := _make_ground()
	var obstacles := TileMapLayer.new()
	obstacles.tile_set = ground.tile_set
	obstacles.set_cell(Vector2i(2, 0), 0, Vector2i(0, 0))

	var grid := WalkGrid.new(ground, obstacles)
	if not grid.is_walkable(Vector2i(0, 0)):
		failures.append("start cell should be walkable")
	if grid.is_walkable(Vector2i(2, 0)):
		failures.append("obstacle cell should be blocked")

	var path := grid.cell_path(Vector2(16, 16), Vector2(16 + 4 * 32, 16))
	if path.is_empty():
		failures.append("path from (0,0) to (4,0) should exist")
	elif path[0] != Vector2i(0, 0) or path[path.size() - 1] != Vector2i(4, 0):
		failures.append("path endpoints are wrong: %s" % str(path))

	ground.free()
	obstacles.free()
	return failures


func _make_ground() -> TileMapLayer:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "walkable")
	tile_set.set_custom_data_layer_type(0, TYPE_BOOL)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(32, 32)
	tile_set.add_source(source, 0)
	source.create_tile(Vector2i(0, 0))
	source.get_tile_data(Vector2i(0, 0), 0).set_custom_data("walkable", true)
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	for x in 5:
		for y in 5:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	return layer
