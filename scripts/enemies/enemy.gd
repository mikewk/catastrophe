class_name Enemy
extends CharacterBody2D
## Base class for enemies: health, taking hits, knockback, hit flash and
## contact damage. Subclasses override `_behave(delta)` to move.
##
## Defeating an enemy has a chance to restore a heart (see `heal_chance`).

signal defeated

@export var max_health := 3
@export var move_speed := 40.0
## Chance (0–1) that defeating this enemy restores one heart.
@export_range(0.0, 1.0) var heal_chance := 0.5
## 0 = full knockback, 1 = immovable (useful for bosses).
@export_range(0.0, 1.0) var knockback_resistance := 0.0
@export var gravity := 900.0

var health := 0
var facing := -1
var _flash_timer := 0.0
var _knockback := 0.0

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contact_hitbox: Hitbox = $ContactHitbox


func _ready() -> void:
	health = max_health
	hurtbox.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	_flash_timer -= delta
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 400.0)
	_behave(delta)
	if absf(_knockback) > 1.0:
		velocity.x = _knockback
		_knockback = move_toward(_knockback, 0.0, 900.0 * delta)
	move_and_slide()
	queue_redraw()


## Override for movement. Set velocity.x here; gravity is handled already.
func _behave(_delta: float) -> void:
	pass


func is_flashing() -> bool:
	return _flash_timer > 0.0


func _on_hit_received(hitbox: Hitbox) -> void:
	health -= hitbox.damage
	_flash_timer = 0.1
	var away := signf(global_position.x - hitbox.global_position.x)
	_knockback = away * hitbox.knockback_force * (1.0 - knockback_resistance)
	if health <= 0:
		_die()


func _die() -> void:
	if randf() < heal_chance:
		GameState.heal(1)
	defeated.emit()
	queue_free()
