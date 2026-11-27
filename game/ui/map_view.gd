class_name MapView
extends Control
## Draws squares of the world (SPEC-main-screen, "Minimap and world map"): a
## visited square (a key of state.squares) in its kind's colour from
## kinds.csv; unvisited squares and squares beyond the edge of the world as
## dark fog; a red frame on the hero's square. The minimap shows the 7 x 7
## squares around the hero (`around` = 7); the world map window shows the
## whole grid (`around` = 0), with the painted map, when there is one, under
## the fog instead of the flat colours. It only shows the state.

const FOG := Color(0.14, 0.15, 0.18)
const FRAME_COLOUR := Color(0.92, 0.16, 0.14)
const BACKGROUND := Color(0.02, 0.02, 0.03)

## Squares per side around the hero's square; 0 shows the whole world.
@export var around := 0
## Room around the squares, in pixels.
@export var padding := 3.0

## What is drawn: the colour of every square shown, row by row, from the
## square at `origin` (top left); and the index of the hero's square, -1 when
## it isn't shown.
var cells: Array[Color] = []
var origin := Vector2i.ZERO
var columns := 0
var rows := 0
var frame_index := -1
## Drawn under the fog instead of the flat colours (the world map's painted map).
var painted: Texture2D


## Takes the squares to show from the state, then redraws.
func refresh(world: WorldMap, state: Dictionary) -> void:
	var hero := WorldMap.coords(str(state.get("square", "")))
	if around > 0:
		columns = around
		rows = around
		origin = hero - Vector2i(around / 2, around / 2)
	else:
		columns = world.width if world != null else 0
		rows = world.height if world != null else 0
		origin = Vector2i.ZERO
	var squares: Variant = state.get("squares")
	var visited: Dictionary = squares if squares is Dictionary else {}
	cells.clear()
	for y in rows:
		for x in columns:
			cells.append(square_colour(world, visited, origin + Vector2i(x, y)))
	var at := hero - origin
	frame_index = -1
	if hero.x >= 0 and at.x >= 0 and at.y >= 0 and at.x < columns and at.y < rows:
		frame_index = at.y * columns + at.x
	queue_redraw()


## The colour of the square at `at`: its kind's colour when visited, else fog
## (also beyond the edge of the world).
static func square_colour(world: WorldMap, visited: Dictionary, at: Vector2i) -> Color:
	if world == null or at.x < 0 or at.y < 0 or at.x >= world.width or at.y >= world.height:
		return FOG
	var id := WorldMap.square_id(at.x, at.y)
	if not visited.has(id):
		return FOG
	return kind_colour(world, world.kind_of(id))


## A kind's colour from kinds.csv; fog for an unknown kind.
static func kind_colour(world: WorldMap, kind: String) -> Color:
	var index := world.kind_index(kind)
	if index == -1:
		return FOG
	for colour in world.kind_colours:
		if int(world.kind_colours[colour]) == index:
			return Color.hex((int(colour) << 8) | 0xff)
	return FOG


func _draw() -> void:
	if columns <= 0 or rows <= 0:
		return
	var room := size - Vector2(padding, padding) * 2.0
	var cell := floorf(minf(room.x / columns, room.y / rows))
	if cell < 1.0:
		return
	var grid := Vector2(columns, rows) * cell
	var top_left := ((size - grid) / 2.0).floor()
	draw_rect(Rect2(top_left, grid).grow(padding), BACKGROUND)
	if painted != null:
		draw_texture_rect(painted, Rect2(top_left, grid), false)
	for i in cells.size():
		# Over the painted map only the fog is drawn.
		if painted != null and cells[i] != FOG:
			continue
		draw_rect(Rect2(top_left + Vector2(i % columns, i / columns) * cell, Vector2(cell, cell)), cells[i])
	if frame_index >= 0:
		var at := Vector2(frame_index % columns, frame_index / columns)
		draw_rect(Rect2(top_left + at * cell, Vector2(cell, cell)).grow(-1.0), FRAME_COLOUR, false, 2.0)
