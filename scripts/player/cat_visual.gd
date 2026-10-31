extends Node2D
## Drives the cat's AnimatedSprite2D from the Player's state, and draws effects
## for moves the sprite sheets don't cover (spin, pounce, dash attack, up/down
## scratch).
##
## The sheets face left, so the sprite is flipped when facing right. Moves
## without their own animation reuse frames: climbing rotates the run cycle
## upright against the wall, Spin twirls a curled jump frame, and Pounce tilts
## a stretched running-jump frame into a dive.

## The sprite pivots around the cat's body centre (feet are at y = 0).
const BODY_CENTER := Vector2(0, -14)
const SPECIAL := Color("7fd8ff")
const CLAW := Color("fff4d6")
const SPIN_SPEED := 22.0
const POUNCE_TILT := deg_to_rad(60.0)

var _last_state := -1
var _attacking := false
var _spin_angle := 0.0

@onready var player: Player = get_parent()
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var effects: Node2D = $Effects


func _ready() -> void:
	effects.draw.connect(_draw_effects)
	player.scratch_started.connect(_on_scratch_started)
	sprite.animation_finished.connect(func() -> void: _attacking = false)


func _process(delta: float) -> void:
	var entered := player.state != _last_state
	_last_state = player.state
	_update_sprite(delta, entered)

	# Flicker while invulnerable; fade while dead.
	visible = not (player.is_invulnerable() and int(Time.get_ticks_msec() / 60.0) % 2 == 0)
	modulate = Color(1, 1, 1, 0.4) if player.state == Player.State.DEAD else Color.WHITE
	effects.queue_redraw()


func _update_sprite(delta: float, entered: bool) -> void:
	var f := player.facing
	sprite.position = BODY_CENTER
	sprite.rotation = 0.0
	sprite.flip_h = f > 0
	sprite.flip_v = false
	if player.state != Player.State.NORMAL:
		_attacking = false

	match player.state:
		Player.State.WALL_CLIMB, Player.State.WALL_SLIDE:
			# Upright with the feet toward the wall (facing points at the wall).
			sprite.rotation = PI / 2.0
			sprite.flip_h = false
			sprite.flip_v = f > 0
			sprite.position = BODY_CENTER + Vector2(-f * 4.0, 0.0)
			if player.state == Player.State.WALL_CLIMB and absf(player.velocity.y) > 1.0:
				_play(&"run", absf(player.velocity.y) / player.climb_speed)
			else:
				_hold(&"run", 0 if player.state == Player.State.WALL_CLIMB else 2)
		Player.State.SPIN:
			_spin_angle += SPIN_SPEED * delta * -f
			sprite.rotation = _spin_angle
			_hold(&"jump", 1)
		Player.State.POUNCE:
			sprite.rotation = f * POUNCE_TILT
			_hold(&"running_jump", 2)
		Player.State.POUNCE_LAND:
			_hold(&"jump", 0)
		Player.State.DASH_ATTACK:
			_hold(&"running_jump", 1)
		Player.State.HURT:
			if entered:
				sprite.play(&"hurt")
		Player.State.DEAD:
			_hold(&"hurt", 3)
		_:
			_update_normal()


func _update_normal() -> void:
	if _attacking:
		return
	var vx := absf(player.velocity.x)
	if not player.is_on_floor():
		var vy := player.velocity.y
		_hold(&"running_jump" if vx > 160.0 else &"jump", 0 if vy < -120.0 else (1 if vy < 120.0 else 2))
	elif vx > 100.0:
		_play(&"run", clampf(vx / player.run_speed, 0.8, 1.6))
	elif vx > 10.0:
		_play(&"walk")
	else:
		_play(&"idle")


func _on_scratch_started(dir: Player.ScratchDir) -> void:
	if dir == Player.ScratchDir.SIDE:
		# Start at the reach pose so the sheet's slash lines up with the hitbox.
		_attacking = true
		sprite.speed_scale = 1.0
		sprite.play(&"attack")
		sprite.frame = 3


func _play(anim: StringName, speed: float = 1.0) -> void:
	sprite.speed_scale = speed
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func _hold(anim: StringName, frame: int) -> void:
	if sprite.animation != anim:
		sprite.animation = anim
	sprite.pause()
	sprite.frame = frame


func _draw_effects() -> void:
	var f := float(player.facing)
	match player.state:
		Player.State.SPIN:
			var a := Time.get_ticks_msec() / 40.0
			effects.draw_arc(BODY_CENTER, 26, a, a + TAU * 0.75, 20, SPECIAL, 2.0)
		Player.State.POUNCE:
			effects.draw_line(Vector2(-8, 4), Vector2(0, 14), SPECIAL, 2.0)
			effects.draw_line(Vector2(8, 4), Vector2(0, 14), SPECIAL, 2.0)
		Player.State.DASH_ATTACK:
			for i in 3:
				var y := -18.0 + i * 5.0
				effects.draw_line(Vector2(-f * 14, y), Vector2(-f * 32, y), SPECIAL, 1.0)
	if player.is_scratching() and player.scratch_dir != Player.ScratchDir.SIDE:
		var c := player.scratch_hitbox.position
		for i in 3:
			var dx := -6.0 + i * 6.0
			effects.draw_line(c + Vector2(dx - 3, -5), c + Vector2(dx + 3, 5), CLAW, 1.0)
