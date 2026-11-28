extends CharacterBody2D
## The hero, moved by clicks (path-finding to the clicked tile) or by keys
## (one tile per step while a direction is held, 8 directions). main.gd reads
## the keys from the Controls settings and sets `held_direction`; it also
## turns clicks off when the player chose keys only. The world calls
## set_grid() after its tiles are painted; SceneDirector can call walk_to()
## for the AI's move_to command.

signal arrived

const HERO_TEXTURE := preload("res://content/art/hero.png")
const TILE := 32
## Walking speed in tiles per second: the one setting for it (SPEC-world).
const WALK_CELLS_PER_SECOND := 5.0
const ANIMATIONS := {
	"idle_down": 0,
	"walk_down": 1,
	"walk_up": 2,
	"walk_left": 3,
	"walk_right": 4,
	"attack_down": 5,
}

var speed := WALK_CELLS_PER_SECOND * TILE

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var grid: WalkGrid
var locked := false
## Clicks walk the hero (Controls setting "click to move").
var click_enabled := true
## The direction keys held this frame (x and y each -1, 0 or 1), set by main.gd.
var held_direction := Vector2i.ZERO
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
	if not click_enabled:
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
	if _path.is_empty() and not locked and held_direction != Vector2i.ZERO:
		_step_by_key()
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


## One tile in the held direction. A diagonal step needs both straight tiles
## free (no cutting corners); when it is blocked, the hero slides along the
## free straight direction instead.
func _step_by_key() -> void:
	if grid == null:
		return
	var here := grid.cell_of(global_position)
	var candidates: Array[Vector2i] = [held_direction]
	if held_direction.x != 0 and held_direction.y != 0:
		candidates.append(Vector2i(held_direction.x, 0))
		candidates.append(Vector2i(0, held_direction.y))
	for step in candidates:
		var next := here + step
		if not grid.is_walkable(next):
			continue
		if step.x != 0 and step.y != 0 and not (grid.is_walkable(here + Vector2i(step.x, 0)) and grid.is_walkable(here + Vector2i(0, step.y))):
			continue
		_path.append(grid.world_of(next))
		return
	# Blocked: just turn to face the key.
	_animate(Vector2(held_direction) * 0.001)


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
