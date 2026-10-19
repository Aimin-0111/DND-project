extends CharacterBody2D
## Option A: free movement in real time (keyboard or gamepad).
## The AI is not called for every step: invisible Area2D zones in the world
## ("old_mill_entrance", "bridge"...) tell the game when something worth
## narrating happens, and only then is the DM asked.
##
## Input Map (Project Settings → Input Map): create move_left/right/up/down
## and bind the arrow keys AND the W/A/S/D keys as *physical* keys. Physical
## keys follow the key's position, so the same binding becomes Z/Q/S/D on a
## French AZERTY keyboard automatically.

signal arrived
## Emitted when the hero walks into an event zone (an Area2D in group "events").
signal event_zone_entered(zone_id: String)

@export var speed := 110.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Set when the AI moves the hero ("move_to"); the player can take back control.
var _auto_target := Vector2.INF
var locked := false
var _facing := "down"


func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if not locked:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_auto_target = Vector2.INF        # the player took control back
	elif _auto_target != Vector2.INF:
		var to_target := _auto_target - global_position
		if to_target.length() < 3.0:
			_auto_target = Vector2.INF
			arrived.emit()
		else:
			dir = to_target.normalized()
	velocity = dir * speed
	move_and_slide()
	_animate(dir)


## Straight line, which is fine for short AI moves. For long ones, use
## WalkGrid like movement_click.gd does.
func walk_to(target: Vector2) -> void:
	_auto_target = target
	await arrived


## Connect each event Area2D's body_entered signal to this.
func on_zone_body_entered(body: Node2D, zone: Area2D) -> void:
	if body == self:
		event_zone_entered.emit(zone.name)


func _animate(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		sprite.play("idle_" + _facing)
		return
	if absf(dir.x) > absf(dir.y):
		_facing = "right" if dir.x > 0 else "left"
	else:
		_facing = "down" if dir.y > 0 else "up"
	sprite.play("walk_" + _facing)
