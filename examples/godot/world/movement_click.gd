extends CharacterBody2D
## Option B: click to move (recommended to start).
## Click a place (or the AI sends "move_to") and the hero walks there along
## a path around trees and water. Works with mouse and touch screens.
##
## Scene: Hero (CharacterBody2D, this script)
##          ├─ AnimatedSprite2D  animations: idle_down, walk_up/down/left/right
##          ├─ CollisionShape2D
##          └─ Camera2D

signal arrived

@export var speed := 90.0
@export var ground: TileMapLayer
@export var obstacles: TileMapLayer

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var grid: WalkGrid
var _path: Array[Vector2] = []
## The story panel locks movement while the AI is answering.
var locked := false


func _ready() -> void:
	grid = WalkGrid.new(ground, obstacles)


func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		walk_to(get_global_mouse_position())


## Also called by SceneDirector for the AI's "move_to". Can be awaited.
func walk_to(target: Vector2) -> void:
	_path.clear()
	for cell in grid.cell_path(global_position, target):
		_path.append(grid.world_of(cell))
	if _path.is_empty():
		return
	await arrived


func _physics_process(_delta: float) -> void:
	if _path.is_empty():
		velocity = Vector2.ZERO
		_animate(Vector2.ZERO)
		return
	var to_next := _path[0] - global_position
	if to_next.length() < 2.0:
		_path.remove_at(0)
		if _path.is_empty():
			arrived.emit()
		return
	velocity = to_next.normalized() * speed
	move_and_slide()
	_animate(velocity)


var _facing := "down"

func _animate(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		sprite.play("idle_" + _facing)
		return
	if absf(dir.x) > absf(dir.y):
		_facing = "right" if dir.x > 0 else "left"
	else:
		_facing = "down" if dir.y > 0 else "up"
	sprite.play("walk_" + _facing)
