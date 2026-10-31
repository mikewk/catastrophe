class_name Player
extends CharacterBody2D
## The cat. A single state machine handles movement, the five traversal
## abilities (gated through GameState), the scratch attack and the three
## energy-based specials.
##
## Origin is at the cat's feet. All tuning values are exported so they can be
## adjusted live in the Inspector while the game runs.

signal died
signal scratch_started(dir: ScratchDir)
signal respawned

enum State { NORMAL, WALL_SLIDE, WALL_CLIMB, SPIN, POUNCE, POUNCE_LAND, DASH_ATTACK, HURT, DEAD }
enum ScratchDir { SIDE, UP, DOWN }

const BODY_HEIGHT := 18.0
const SOLID_MASK := 1 | 2  # world + soft_blocks
const ONE_WAY_LAYER := 7

@export_group("Run")
@export var run_speed := 150.0
## Speed while holding Dash (needs the Dash ability).
@export var sprint_speed := 260.0
@export var ground_accel := 1400.0
@export var ground_decel := 1800.0
@export var air_accel := 1000.0
@export var air_decel := 600.0

@export_group("Jump")
@export var jump_height := 72.0
@export var jump_time_to_apex := 0.36
@export var double_jump_height := 56.0
@export var fall_gravity_multiplier := 1.6
## Upward speed is multiplied by this when jump is released early.
@export var jump_cut_multiplier := 0.45
@export var max_fall_speed := 420.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12

@export_group("Wall")
@export var wall_slide_speed := 70.0
@export var wall_jump_push := 170.0
@export var wall_jump_height := 64.0
## Time after a wall jump when steering is ignored. Long enough that a wall
## jump can't scale a single wall, which keeps Wall Climb meaningful.
@export var wall_jump_input_lock := 0.2
@export var climb_speed := 90.0
@export var ledge_hop_speed := 230.0

@export_group("Combat")
@export var scratch_duration := 0.16
@export var scratch_cooldown := 0.28
@export var pogo_velocity := 300.0
@export var spin_duration := 0.4
@export var pounce_speed := 480.0
@export var pounce_bounce := 320.0
@export var pounce_land_recovery := 0.15
@export var dash_attack_speed := 420.0
@export var dash_attack_duration := 0.25

@export_group("Damage")
@export var hurt_knockback := Vector2(160.0, -180.0)
@export var hurt_stun := 0.25
@export var invulnerable_time := 1.0
@export var hazard_respawn_delay := 0.35
@export var death_respawn_delay := 1.2

var state := State.NORMAL
var facing := 1
var scratch_dir := ScratchDir.SIDE
## Where the cat returns after death (set by the room or a checkpoint).
var spawn_position := Vector2.ZERO

var _gravity := 0.0
var _jump_velocity := 0.0
var _double_jump_velocity := 0.0
var _wall_jump_velocity := 0.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _air_jumps_used := 0
var _input_lock_timer := 0.0
## Only normal and double jumps get shorter when jump is released early;
## wall jumps and bounces always get their full height.
var _jump_cuttable := false
var _ledge_timer := 0.0
var _ledge_dir := 0
var _wall_dir := 0
var _sprinting := false
var _drop_through_timer := 0.0
var _scratch_timer := 0.0
var _scratch_cooldown_timer := 0.0
var _state_timer := 0.0
var _invulnerable_timer := 0.0
var _hazard_pending := false
var _safe_ground_timer := 0.0
var _last_safe_position := Vector2.ZERO

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var scratch_hitbox: Hitbox = $ScratchHitbox
@onready var spin_hitbox: Hitbox = $SpinHitbox
@onready var pounce_hitbox: Hitbox = $PounceHitbox
@onready var dash_attack_hitbox: Hitbox = $DashAttackHitbox
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group(&"player")
	_recalculate_jump_physics()
	hurtbox.hit_received.connect(_on_hit_received)
	scratch_hitbox.hit_landed.connect(_on_scratch_landed)
	pounce_hitbox.hit_landed.connect(_on_pounce_landed)
	spawn_position = global_position
	_last_safe_position = global_position


func _recalculate_jump_physics() -> void:
	_gravity = 2.0 * jump_height / (jump_time_to_apex * jump_time_to_apex)
	_jump_velocity = -2.0 * jump_height / jump_time_to_apex
	_double_jump_velocity = -sqrt(2.0 * _gravity * double_jump_height)
	_wall_jump_velocity = -sqrt(2.0 * _gravity * wall_jump_height)


## Places the cat at a spawn point (room entry, checkpoint) and makes it the
## respawn position.
func place_at(spawn: Vector2) -> void:
	global_position = spawn
	spawn_position = spawn
	_last_safe_position = spawn
	velocity = Vector2.ZERO
	camera.reset_smoothing()


func set_camera_limits(bounds: Rect2) -> void:
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)


func is_invulnerable() -> bool:
	return _invulnerable_timer > 0.0


func is_scratching() -> bool:
	return _scratch_timer > 0.0


func is_sprinting() -> bool:
	return _sprinting


# --- Main loop ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = jump_buffer_time

	match state:
		State.NORMAL:
			_state_normal(delta)
		State.WALL_SLIDE, State.WALL_CLIMB:
			_state_wall(delta)
		State.SPIN:
			_state_spin(delta)
		State.POUNCE:
			_state_pounce()
		State.POUNCE_LAND:
			_state_pounce_land(delta)
		State.DASH_ATTACK:
			_state_dash_attack()
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			_state_dead()

	move_and_slide()
	_track_safe_ground(delta)


func _tick_timers(delta: float) -> void:
	_coyote_timer -= delta
	_jump_buffer_timer -= delta
	_input_lock_timer -= delta
	_ledge_timer -= delta
	_scratch_cooldown_timer -= delta
	_state_timer -= delta
	_invulnerable_timer -= delta
	hurtbox.invulnerable = is_invulnerable() or state == State.DEAD
	if _drop_through_timer > 0.0:
		_drop_through_timer -= delta
		if _drop_through_timer <= 0.0:
			set_collision_mask_value(ONE_WAY_LAYER, true)
	if _scratch_timer > 0.0:
		_scratch_timer -= delta
		_position_scratch_hitbox()
		if _scratch_timer <= 0.0:
			scratch_hitbox.deactivate()


# --- States ------------------------------------------------------------------

func _state_normal(delta: float) -> void:
	var x := _input_x()
	var grounded := is_on_floor()

	if grounded:
		_coyote_timer = coyote_time
		_air_jumps_used = 0
		_sprinting = GameState.has_ability(GameState.DASH) and Input.is_action_pressed(&"dash") and x != 0.0

	_apply_horizontal(delta, x, grounded, 1.0)
	if _ledge_timer > 0.0:
		velocity.x = _ledge_dir * 100.0  # Keep pushing onto the ledge after a climb.
	_apply_gravity(delta)

	# Drop through one-way platforms with down + jump.
	if grounded and _jump_buffer_timer > 0.0 and _input_y() > 0.0 and _standing_on_one_way_only():
		_jump_buffer_timer = 0.0
		set_collision_mask_value(ONE_WAY_LAYER, false)
		_drop_through_timer = 0.25
		position.y += 1.0

	_wall_dir = 0 if grounded else _get_wall_dir()

	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0:
			_jump(_jump_velocity)
		elif _wall_dir != 0 and GameState.has_ability(GameState.WALL_JUMP):
			_wall_jump(_wall_dir)
		elif GameState.has_ability(GameState.DOUBLE_JUMP) and _air_jumps_used < 1:
			_air_jumps_used += 1
			_jump(_double_jump_velocity)

	if Input.is_action_just_released(&"jump") and velocity.y < 0.0 and _jump_cuttable:
		velocity.y *= jump_cut_multiplier
		_jump_cuttable = false

	# Grab a wall when pressing into it in the air.
	if _wall_dir != 0 and x == float(_wall_dir) and _input_lock_timer <= 0.0:
		if GameState.has_ability(GameState.WALL_CLIMB):
			_enter_wall_state(State.WALL_CLIMB)
			return
		if GameState.has_ability(GameState.WALL_JUMP) and velocity.y > 0.0:
			_enter_wall_state(State.WALL_SLIDE)
			return

	_handle_attack_input()


func _state_wall(delta: float) -> void:
	var x := _input_x()
	var y := _input_y()
	_wall_dir = _get_wall_dir()
	if _wall_dir == 0 or is_on_floor():
		_change_state(State.NORMAL)
		return
	_set_facing(_wall_dir)
	_air_jumps_used = 0

	if _jump_buffer_timer > 0.0:
		_wall_jump(_wall_dir)
		return
	if x == float(-_wall_dir):
		_change_state(State.NORMAL)  # Let go by pushing away.
		return

	velocity.x = _wall_dir * 20.0  # Keep pressed against the wall.
	if state == State.WALL_CLIMB:
		# Climbing holds indefinitely; up/down moves along the wall.
		velocity.y = y * climb_speed
		if y < 0.0 and not _wall_at_head(_wall_dir):
			_ledge_hop(_wall_dir)
	else:
		if x != float(_wall_dir):
			_change_state(State.NORMAL)  # Sliding needs the stick held toward the wall.
			return
		velocity.y = minf(velocity.y + _gravity * delta, wall_slide_speed)


func _state_spin(delta: float) -> void:
	_apply_horizontal(delta, _input_x(), is_on_floor(), 0.5)
	_apply_gravity(delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y, 30.0)  # Hang in the air a little while spinning.
	if _state_timer <= 0.0:
		_change_state(State.NORMAL)


func _state_pounce() -> void:
	velocity = Vector2(facing * 90.0, pounce_speed)
	if is_on_floor():
		_change_state(State.POUNCE_LAND)
		_state_timer = pounce_land_recovery


func _state_pounce_land(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
	_apply_gravity(delta)
	if _state_timer <= 0.0:
		_change_state(State.NORMAL)


func _state_dash_attack() -> void:
	velocity = Vector2(facing * dash_attack_speed, 0.0)
	if _state_timer <= 0.0 or is_on_wall():
		velocity.x = facing * sprint_speed
		_change_state(State.NORMAL)


func _state_hurt(delta: float) -> void:
	if _hazard_pending:
		velocity = Vector2.ZERO
		if _state_timer <= 0.0:
			_hazard_pending = false
			global_position = _last_safe_position
			camera.reset_smoothing()
			_change_state(State.NORMAL)
		return
	velocity.x = move_toward(velocity.x, 0.0, air_decel * delta)
	_apply_gravity(delta)
	if _state_timer <= 0.0:
		_change_state(State.NORMAL)


func _state_dead() -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_respawn()


func _change_state(new_state: State) -> void:
	if state == new_state:
		return
	match state:
		State.SPIN:
			spin_hitbox.deactivate()
		State.POUNCE:
			pounce_hitbox.deactivate()
		State.DASH_ATTACK:
			dash_attack_hitbox.deactivate()
	state = new_state


func _enter_wall_state(wall_state: State) -> void:
	_change_state(wall_state)
	_sprinting = false
	velocity = Vector2.ZERO


# --- Movement helpers --------------------------------------------------------

func _input_x() -> float:
	var x := Input.get_axis(&"move_left", &"move_right")
	return 0.0 if absf(x) < 0.3 else signf(x)


func _input_y() -> float:
	var y := Input.get_axis(&"move_up", &"move_down")
	return 0.0 if absf(y) < 0.3 else signf(y)


func _apply_horizontal(delta: float, x: float, grounded: bool, control: float) -> void:
	if _input_lock_timer > 0.0:
		return
	var speed := sprint_speed if _sprinting else run_speed
	var accel: float
	if grounded:
		accel = ground_accel if x != 0.0 else ground_decel
	else:
		accel = air_accel if x != 0.0 else air_decel
	velocity.x = move_toward(velocity.x, x * speed, accel * control * delta)
	if x != 0.0 and not is_scratching():
		_set_facing(int(x))


func _apply_gravity(delta: float) -> void:
	var g := _gravity if velocity.y < 0.0 else _gravity * fall_gravity_multiplier
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func _jump(jump_velocity: float) -> void:
	velocity.y = jump_velocity
	_jump_cuttable = true
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func _wall_jump(wall_dir: int) -> void:
	_change_state(State.NORMAL)
	velocity = Vector2(-wall_dir * wall_jump_push, _wall_jump_velocity)
	_input_lock_timer = wall_jump_input_lock
	_jump_cuttable = false
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_sprinting = false
	_set_facing(-wall_dir)


func _ledge_hop(wall_dir: int) -> void:
	_change_state(State.NORMAL)
	velocity = Vector2(wall_dir * 100.0, -ledge_hop_speed)
	_input_lock_timer = 0.15
	_ledge_timer = 0.25
	_ledge_dir = wall_dir
	_jump_cuttable = false


func _set_facing(dir: int) -> void:
	if dir != 0:
		facing = dir


## -1 if a wall is touching the cat's left side, 1 for the right, 0 for none.
func _get_wall_dir() -> int:
	if test_move(global_transform, Vector2(2.0, 0.0)):
		return 1
	if test_move(global_transform, Vector2(-2.0, 0.0)):
		return -1
	return 0


## Whether there is still wall in front of the cat's head (false at a ledge top).
func _wall_at_head(dir: int) -> bool:
	var from := global_position + Vector2(0.0, -BODY_HEIGHT + 2.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(dir * 14.0, 0.0), SOLID_MASK, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _standing_on_one_way_only() -> bool:
	set_collision_mask_value(ONE_WAY_LAYER, false)
	var on_solid := test_move(global_transform, Vector2(0.0, 1.0))
	set_collision_mask_value(ONE_WAY_LAYER, true)
	return not on_solid


func _track_safe_ground(delta: float) -> void:
	if state == State.NORMAL and is_on_floor() and _drop_through_timer <= 0.0:
		_safe_ground_timer += delta
		if _safe_ground_timer > 0.15:
			_last_safe_position = global_position
	else:
		_safe_ground_timer = 0.0


# --- Attacks -----------------------------------------------------------------

func _handle_attack_input() -> void:
	if Input.is_action_just_pressed(&"special"):
		_try_special()
	elif Input.is_action_just_pressed(&"attack") and _scratch_cooldown_timer <= 0.0:
		_start_scratch()


func _start_scratch() -> void:
	var y := _input_y()
	if y < 0.0:
		scratch_dir = ScratchDir.UP
	elif y > 0.0 and not is_on_floor():
		scratch_dir = ScratchDir.DOWN
	else:
		scratch_dir = ScratchDir.SIDE
	_scratch_timer = scratch_duration
	_scratch_cooldown_timer = scratch_cooldown
	_position_scratch_hitbox()
	scratch_hitbox.activate()
	scratch_started.emit(scratch_dir)


func _position_scratch_hitbox() -> void:
	match scratch_dir:
		ScratchDir.SIDE:
			scratch_hitbox.position = Vector2(facing * 22.0, -9.0)
		ScratchDir.UP:
			scratch_hitbox.position = Vector2(0.0, -28.0)
		ScratchDir.DOWN:
			scratch_hitbox.position = Vector2(0.0, 10.0)


func _cancel_scratch() -> void:
	_scratch_timer = 0.0
	scratch_hitbox.deactivate()


func _try_special() -> void:
	var dashing := _sprinting and absf(velocity.x) > run_speed + 1.0
	var pouncing := not is_on_floor() and _input_y() > 0.0
	if not GameState.try_spend_energy(GameState.SPECIAL_COST):
		return
	_cancel_scratch()
	if dashing:
		# Dash attack: a fast, high-damage lunge out of a sprint.
		_change_state(State.DASH_ATTACK)
		_state_timer = dash_attack_duration
		dash_attack_hitbox.position.x = facing * 18.0
		dash_attack_hitbox.activate()
	elif pouncing:
		# Pounce: dive straight down; bounces off whatever it hits.
		_change_state(State.POUNCE)
		pounce_hitbox.activate()
	else:
		# Spin: hits everything in a circle around the cat.
		_change_state(State.SPIN)
		_state_timer = spin_duration
		spin_hitbox.activate()


func _on_scratch_landed(_target: Node) -> void:
	if scratch_dir == ScratchDir.DOWN and state == State.NORMAL:
		velocity.y = -pogo_velocity  # Pogo bounce off enemies and blocks.
		_air_jumps_used = 0
		_jump_cuttable = false


func _on_pounce_landed(target: Node) -> void:
	if state == State.POUNCE and target is Hurtbox:
		_change_state(State.NORMAL)
		velocity.y = -pounce_bounce
		_air_jumps_used = 0
		_jump_cuttable = false


# --- Damage ------------------------------------------------------------------

func _on_hit_received(hitbox: Hitbox) -> void:
	if state == State.DEAD:
		return
	# Block any other hits arriving this same physics frame (overlapping spike
	# tiles, two enemies at once) before the timer takes over next frame.
	hurtbox.invulnerable = true
	_cancel_scratch()
	_sprinting = false
	if GameState.damage(hitbox.damage):
		_die()
		return
	_invulnerable_timer = invulnerable_time
	_change_state(State.HURT)
	if hitbox.is_hazard:
		_hazard_pending = true
		_state_timer = hazard_respawn_delay
		velocity = Vector2.ZERO
	else:
		var away := signf(global_position.x - hitbox.global_position.x)
		if away == 0.0:
			away = -facing
		velocity = Vector2(away * hurt_knockback.x, hurt_knockback.y)
		_state_timer = hurt_stun


func _die() -> void:
	_change_state(State.DEAD)
	_hazard_pending = false
	_state_timer = death_respawn_delay
	died.emit()


func _respawn() -> void:
	GameState.refill()
	global_position = spawn_position
	_last_safe_position = spawn_position
	velocity = Vector2.ZERO
	_invulnerable_timer = invulnerable_time
	camera.reset_smoothing()
	_change_state(State.NORMAL)
	respawned.emit()
