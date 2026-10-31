class_name Hitbox
extends Area2D
## An area that deals damage to Hurtboxes it overlaps while `active`.
## Used for the cat's attacks, enemy contact damage, and hazards like spikes.
##
## A one-shot hitbox (the default) hits each target once per activate() call,
## so one swing can't hit the same enemy twice. A continuous hitbox keeps
## hitting every frame; the receiver's invulnerability frames limit it.

## Emitted when this hitbox lands on something: a Hurtbox, or a diggable body.
signal hit_landed(target: Node)

@export var damage := 1
## Horizontal push given to whatever is hit.
@export var knockback_force := 180.0
@export var active := true
@export var continuous := false
## Hazards (spikes, pits) send the cat back to safe ground instead of knocking it back.
@export var is_hazard := false
## Lets this hitbox break soft blocks (bodies with a `dig()` method).
@export var can_dig := false

var _already_hit: Array[Node] = []
# Leave `monitorable` on: in Godot's 2D physics an area with it off stops
# detecting static bodies (soft blocks). Hitboxes sit on collision layer 0,
# so nothing detects them anyway.


func activate() -> void:
	active = true
	_already_hit.clear()


func deactivate() -> void:
	active = false


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for area in get_overlapping_areas():
		if area is Hurtbox:
			_try_hit(area)
	if can_dig:
		for body in get_overlapping_bodies():
			if body.has_method("dig"):
				_try_hit(body)


func _try_hit(target: Node) -> void:
	if not continuous and target in _already_hit:
		return
	var landed := false
	if target is Hurtbox:
		landed = target.receive_hit(self)
	else:
		target.dig(self)
		landed = true
	if not continuous:
		_already_hit.append(target)
	if landed:
		hit_landed.emit(target)
