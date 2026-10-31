class_name BestiaryEnemy
extends Enemy
## An enemy drawn with a creature from the BESTIARY pack. Set `creature_id`
## and `movement`; the sprite placement, body size and (by default) health are
## worked out from the creature's artwork.
##
## Animations: move/idle while patrolling, attack when the cat comes close,
## hit when struck, and death before the enemy is removed.

enum Movement { WALK, FLY, STATIC }

## Creatures that hover, and ones that stay rooted in place. Everything else walks.
const FLYING_PREFIXES := ["bat_", "crow_", "ghost_", "imp_", "wisp_", "eye_", "jelly_",
		"skull_", "shade_", "wraith_"]
const STATIC_PREFIXES := ["mimic_", "fungus_", "hand_", "bonepile_"]

@export var creature_id := "rat_grey"
@export var movement := Movement.WALK
## Flyers patrol this far either side of where they spawn.
@export var patrol_range := 40.0
## Distance at which the creature plays its attack animation at the cat.
@export var attack_range := 40.0
@export var attack_cooldown := 1.6

## Opaque area of each creature's first idle frame, shared between instances.
static var _bounds_cache: Dictionary[String, Rect2] = {}

var sprite: Bestiary
var _sprite_offset := Vector2.ZERO
var _home := Vector2.ZERO
var _attack_timer := 0.0
var _bob_time := 0.0
var _player: Node2D


## The usual way a creature moves, from its id.
static func movement_for(id: String) -> Movement:
	for prefix: String in FLYING_PREFIXES:
		if id.begins_with(prefix):
			return Movement.FLY
	for prefix: String in STATIC_PREFIXES:
		if id.begins_with(prefix):
			return Movement.STATIC
	return Movement.WALK


func _ready() -> void:
	flying = movement == Movement.FLY
	_home = global_position
	_bob_time = randf() * TAU
	facing = -1 if randf() < 0.5 else 1

	var frames := Bestiary.load_frames(creature_id)
	if frames == null:
		push_error("BestiaryEnemy: unknown creature " + creature_id)
		queue_free()
		return
	var cell := frames.get_frame_texture(&"idle", 0).get_size()
	var used := _opaque_bounds(creature_id, frames)
	if max_health <= 0:
		max_health = 8 if cell.x >= 48 else 3

	# Sprite: feet (bottom of the artwork) at the origin, centred horizontally.
	sprite = Bestiary.new()
	sprite.creature_id = creature_id
	sprite.start_state = &"idle"
	_sprite_offset = Vector2(cell.x / 2.0 - used.get_center().x, cell.y / 2.0 - used.end.y)
	sprite.position = _sprite_offset
	add_child(sprite)

	# Collision shapes sized from the artwork.
	_set_box($CollisionShape2D, used.size * Vector2(0.6, 0.7), true)
	_set_box($Hurtbox/CollisionShape2D, used.size * 0.85, false, used.size.y)
	_set_box($ContactHitbox/CollisionShape2D, used.size * 0.6, false, used.size.y)

	super._ready()


func _set_box(shape_node: CollisionShape2D, size: Vector2, from_feet: bool, art_height := 0.0) -> void:
	var box := RectangleShape2D.new()
	box.size = size.max(Vector2(6, 6))
	shape_node.shape = box
	# Body sits on the feet; hurt/contact boxes are centred on the artwork.
	shape_node.position = Vector2(0, -size.y / 2.0 if from_feet else -art_height / 2.0)


static func _opaque_bounds(id: String, frames: SpriteFrames) -> Rect2:
	if not _bounds_cache.has(id):
		var image := frames.get_frame_texture(&"idle", 0).get_image()
		_bounds_cache[id] = Rect2(image.get_used_rect())
	return _bounds_cache[id]


func _behave(delta: float) -> void:
	_attack_timer -= delta
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player")

	match movement:
		Movement.WALK:
			if is_on_floor() and (is_on_wall() or _ledge_ahead()):
				facing = -facing
			velocity.x = facing * move_speed
		Movement.FLY:
			_bob_time += delta
			if is_on_wall() or (global_position.x - _home.x) * facing > patrol_range:
				facing = -facing
			velocity.x = facing * move_speed
			var target_y := _home.y + sin(_bob_time * 2.0) * 6.0
			velocity.y = (target_y - global_position.y) * 4.0
		Movement.STATIC:
			velocity.x = 0.0
			if _player:
				facing = 1 if _player.global_position.x > global_position.x else -1

	if _player and _attack_timer <= 0.0 and global_position.distance_to(_player.global_position) < attack_range:
		_attack_timer = attack_cooldown
		sprite.attack()
	_update_sprite()


func _update_sprite() -> void:
	# The pack's side-on creatures face left, so mirror them when facing right.
	sprite.flip_h = facing > 0
	sprite.position.x = -_sprite_offset.x if sprite.flip_h else _sprite_offset.x
	var state := sprite.current_state()
	if state in [&"attack", &"hit"] and sprite.is_playing():
		return
	var want := &"move" if movement == Movement.FLY or absf(velocity.x) > 1.0 else &"idle"
	if state != want or not sprite.is_playing():
		sprite.play_state(want)


func _on_hit_received(hitbox: Hitbox) -> void:
	super._on_hit_received(hitbox)
	if not dead:
		sprite.hurt()


func _on_defeated() -> void:
	sprite.die()
	await sprite.died
	queue_free()
