extends Node2D
## Option C: grid steps, turn by turn (board-game / D&D feel).
## One tile per key press. After each step the world gets a turn: creatures
## move, torches burn down, and combat uses the same grid.

## The world listens to this to move creatures after the hero.
signal stepped(cell: Vector2i)
signal arrived

@export var ground: TileMapLayer
@export var obstacles: TileMapLayer
@export var step_seconds := 0.15

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var grid: WalkGrid
var cell := Vector2i.ZERO
var locked := false
var _busy := false

const DIRECTIONS := {
	"move_up": [Vector2i.UP, "up"],
	"move_down": [Vector2i.DOWN, "down"],
	"move_left": [Vector2i.LEFT, "left"],
	"move_right": [Vector2i.RIGHT, "right"],
}


func _ready() -> void:
	grid = WalkGrid.new(ground, obstacles)
	cell = grid.cell_of(global_position)
	global_position = grid.world_of(cell)   # snap to the centre of the tile


func _unhandled_input(event: InputEvent) -> void:
	if locked or _busy:
		return
	for action in DIRECTIONS:
		if event.is_action_pressed(action):
			step(DIRECTIONS[action][0], DIRECTIONS[action][1])
			return


func step(dir: Vector2i, facing: String) -> void:
	var next := cell + dir
	if not grid.is_walkable(next):
		sprite.play("idle_" + facing)    # bump into a wall: just turn
		return
	_busy = true
	cell = next
	sprite.play("walk_" + facing)
	var tween := create_tween()
	tween.tween_property(self, "global_position", grid.world_of(next), step_seconds)
	await tween.finished
	sprite.play("idle_" + facing)
	_busy = false
	stepped.emit(cell)


## For the AI's "move_to": walk the path one step at a time.
func walk_to(target: Vector2) -> void:
	var path := grid.cell_path(global_position, target)
	for i in range(1, path.size()):
		var d: Vector2i = path[i] - cell
		var facing := "right" if d.x > 0 else "left" if d.x < 0 else "down" if d.y > 0 else "up"
		await step(d, facing)
	arrived.emit()
