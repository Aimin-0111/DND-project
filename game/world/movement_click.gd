extends CharacterBody2D
## Click-to-move hero. The world calls set_grid() after its tiles are painted;
## SceneDirector can call walk_to() for the AI's move_to command.

signal arrived

const HERO_TEXTURE := preload("res://content/art/hero-placeholder.png")
const TILE := 32
const ANIMATIONS := {
	"idle_down": 0,
	"walk_down": 1,
	"walk_up": 2,
	"walk_left": 3,
	"walk_right": 4,
	"attack_down": 5,
}

@export var speed := 90.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var grid: WalkGrid
var locked := false
var _path: Array[Vector2] = []
var _facing := "down"


func _ready() -> void:
	_build_frames()
	sprite.play("idle_down")


func set_grid(ground: TileMapLayer, obstacles: TileMapLayer) -> void:
	grid = WalkGrid.new(ground, obstacles)


func stop() -> void:
	_path.clear()
	velocity = Vector2.ZERO
	_animate(Vector2.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		walk_to(get_global_mouse_position())


## Also called by SceneDirector for the AI's "move_to". Can be awaited.
func walk_to(target: Vector2) -> void:
	if grid == null:
		return
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
			velocity = Vector2.ZERO
			_animate(Vector2.ZERO)
			arrived.emit()
		return
	velocity = to_next.normalized() * speed
	move_and_slide()
	_animate(velocity)


func _animate(direction: Vector2) -> void:
	var choice := HeroFacing.pick(direction, _facing, sprite.sprite_frames.get_animation_names())
	_facing = choice["facing"]
	sprite.flip_h = choice["flip_h"]
	if sprite.animation != choice["animation"] or not sprite.is_playing():
		sprite.play(choice["animation"])


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation in ANIMATIONS:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 8.0)
		frames.set_animation_loop(animation, animation != "attack_down")
		for column in 4:
			var frame := AtlasTexture.new()
			frame.atlas = HERO_TEXTURE
			frame.region = Rect2(column * TILE, int(ANIMATIONS[animation]) * TILE, TILE, TILE)
			frames.add_frame(animation, frame)
	sprite.sprite_frames = frames
