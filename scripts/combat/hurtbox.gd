class_name Hurtbox
extends Area2D
## The area of a character that can be hit. The owner listens to
## `hit_received` and decides what damage and knockback to apply.

signal hit_received(hitbox: Hitbox)

## While true, hits are ignored (invulnerability frames).
var invulnerable := false
# `monitoring = false` is set in the scenes: a hurtbox only needs to be found.


## Returns true if the hit was accepted.
func receive_hit(hitbox: Hitbox) -> bool:
	if invulnerable:
		return false
	hit_received.emit(hitbox)
	return true
