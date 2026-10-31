extends Node
## Scripted playtest of the cat's mechanics in the test room. Simulates
## controller input and checks the results.
##   godot --headless res://tests/smoke_test.tscn
## Exits with code 0 if every check passes.

const TILE := 16

var game: Node
var player: Player
var _failures: Array[String] = []


func _ready() -> void:
	game = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	player = game.player
	await _run()
	print("\n%d check(s) failed" % _failures.size() if _failures else "\nAll checks passed")
	for f in _failures:
		print("  FAIL: ", f)
	get_tree().quit(1 if _failures else 0)


func _run() -> void:
	# Abilities are unlocked explicitly below, so remove the room's pickups,
	# and keep only the rat the combat check fights so others don't interfere.
	var test_rat := _nearest_rat(Vector2(22 * TILE, 42 * TILE))
	for n in game.current_room.get_node("Entities").get_children():
		if n is AbilityPickup or (n is Enemy and n != test_rat):
			n.queue_free()
	await _frames(30)
	_check(player.is_on_floor(), "cat lands on the floor at spawn")

	# Running.
	var x0 := player.global_position.x
	await _hold(&"move_right", 20)
	_check(player.global_position.x > x0 + 30, "running right moves the cat")

	# Single jump height, and no double jump before the ability.
	_teleport(5, 41)
	await _frames(10)
	var peak := await _jump_peak(false)
	_check(peak > 60 and peak < 85, "single jump reaches about 72 px (got %.0f)" % peak)
	_teleport(5, 41)
	await _frames(10)
	var peak_no_dj := await _jump_peak(true)
	_check(peak_no_dj < 85, "second jump does nothing without Double Jump (got %.0f)" % peak_no_dj)

	GameState.unlock_ability(GameState.DOUBLE_JUMP)
	_teleport(5, 41)
	await _frames(10)
	var peak_dj := await _jump_peak(true)
	_check(peak_dj > 115, "Double Jump reaches the 112 px ledge height (got %.0f)" % peak_dj)

	# Scratching a rat to death.
	var rat := _nearest_rat(Vector2(22 * TILE, 42 * TILE))
	if rat:
		rat.set_physics_process(false)
		player.global_position = rat.global_position + Vector2(-20, 0)
		player.facing = 1
		_teleport_hold()
		for i in 3:
			await _tap(&"attack")
			await _frames(20)
		_check(not is_instance_valid(rat), "three scratches defeat a rat")
	else:
		_check(false, "found a rat to test against")

	# Sprint.
	_teleport(5, 41)
	await _frames(5)
	Input.action_press(&"move_right")
	Input.action_press(&"dash")
	await _frames(20)
	_check(absf(player.velocity.x) < player.run_speed + 1, "no sprint without Dash")
	Input.action_release(&"dash")
	GameState.unlock_ability(GameState.DASH)
	Input.action_press(&"dash")
	await _frames(20)
	_check(absf(player.velocity.x) > player.run_speed + 50, "holding Dash sprints (%.0f px/s)" % player.velocity.x)

	# Dash attack out of a sprint.
	GameState.refill()
	await _tap(&"special")
	_check(player.state == Player.State.DASH_ATTACK, "special while sprinting starts the Dash attack")
	_check(GameState.energy < 26, "specials cost 25 energy")
	Input.action_release(&"dash")
	Input.action_release(&"move_right")
	await _frames(30)

	# Spin on the ground.
	GameState.refill()
	_teleport(5, 41)
	await _frames(10)
	await _tap(&"special")
	_check(player.state == Player.State.SPIN, "special on the ground starts the Spin (state %d, energy %.0f)" % [player.state, GameState.energy])
	await _frames(40)

	# Not enough energy.
	GameState.energy = 10
	await _tap(&"special")
	_check(player.state == Player.State.NORMAL, "no special without 25 energy")

	# Pounce: down + special in the air.
	GameState.refill()
	_teleport(5, 41)
	await _frames(10)
	await _tap(&"jump")
	await _frames(8)
	Input.action_press(&"move_down")
	await _tap(&"special")
	Input.action_release(&"move_down")
	_check(player.state == Player.State.POUNCE, "down + special in the air starts the Pounce")
	await _frames(60)

	# Soft blocks need Dig.
	var block := _block_at(53, 41)
	player.global_position = Vector2(51 * TILE + 8, 42 * TILE)
	player.facing = 1
	_teleport_hold()
	await _frames(5)
	await _tap(&"attack")
	await _frames(15)
	_check(is_instance_valid(block), "scratch can't break a soft block without Dig")
	GameState.unlock_ability(GameState.DIG)
	await _frames(10)
	await _tap(&"attack")
	await _frames(15)
	_check(not is_instance_valid(block), "scratch breaks a soft block with Dig")

	# Spikes cost a heart and return the cat to safe ground.
	GameState.refill()
	_teleport(25, 41)
	await _frames(20)
	var hearts := GameState.hearts
	player.global_position = Vector2(29 * TILE + 8, 43 * TILE)
	await _frames(40)
	_check(GameState.hearts == hearts - 1, "spikes cost one heart")
	_check(player.global_position.y <= 42 * TILE + 1 and player.global_position.x < 27 * TILE,
			"spikes return the cat to safe ground (at %s)" % player.global_position)

	# Wall jumping up the shaft (walls at x 58-59 and 66-67).
	GameState.unlock_ability(GameState.WALL_JUMP)
	await _frames(70)  # Let invulnerability wear off.
	_teleport(65, 41)
	await _frames(10)
	var start_y := player.global_position.y
	var dir := 1
	Input.action_press(&"move_right")
	await _hold(&"jump", 8)
	for i in 14:
		# Wall jump away from the current wall, then steer to the other one.
		await _tap(&"jump")
		Input.action_release(&"move_right" if dir == 1 else &"move_left")
		dir = -dir
		Input.action_press(&"move_right" if dir == 1 else &"move_left")
		var waited := 0
		await _frames(4)
		while player._get_wall_dir() == 0 and waited < 60:
			await _frames(1)
			waited += 1
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	var climbed := start_y - player.global_position.y
	_check(climbed > 150, "wall jumps climb the two-wall shaft (%.0f px)" % climbed)
	await _frames(90)

	# A single wall can't be scaled with wall jumps alone (keeps Wall Climb a real gate).
	_teleport(69, 41)
	await _frames(10)
	var floor_y := player.global_position.y
	var best_y := floor_y
	Input.action_press(&"move_left")
	Input.action_press(&"jump")
	for i in 240:
		await _frames(1)
		best_y = minf(best_y, player.global_position.y)
		if i % 10 == 0:
			Input.action_release(&"jump")  # Mash jump while pushing into the wall.
		elif i % 10 == 1:
			Input.action_press(&"jump")
	Input.action_release(&"jump")
	Input.action_release(&"move_left")
	_check(floor_y - best_y < 140, "wall jumps alone can't scale a single wall (best %.0f px)" % (floor_y - best_y))
	await _frames(60)

	# Wall Climb: a single wall that wall jumps alone can't scale.
	_teleport(69, 41)
	await _frames(10)
	Input.action_press(&"move_left")
	await _tap(&"jump")
	await _frames(30)
	_check(player.state == Player.State.WALL_SLIDE, "without Wall Climb the cat slides instead of clinging")
	Input.action_release(&"move_left")
	GameState.unlock_ability(GameState.WALL_CLIMB)
	_teleport(69, 41)
	await _frames(10)
	Input.action_press(&"move_left")
	await _tap(&"jump")
	await _frames(10)
	Input.action_release(&"move_left")
	_check(player.state == Player.State.WALL_CLIMB, "with Wall Climb the cat clings to the wall")
	await _frames(60)
	_check(player.state == Player.State.WALL_CLIMB, "the cat stays on the wall with no input")
	Input.action_press(&"move_up")
	await _frames(400)
	Input.action_release(&"move_up")
	await _frames(30)
	_check(player.global_position.y <= 10 * TILE + 1, "climbing hops onto the top of the wall (y=%.0f)" % player.global_position.y)

	# Dying returns the cat to the spawn point with full hearts.
	GameState.hearts = 1
	await _frames(70)
	player.global_position = Vector2(29 * TILE + 8, 43 * TILE)
	await _frames(10)
	_check(player.state == Player.State.DEAD, "losing the last heart kills the cat")
	await _frames(90)
	_check(player.global_position.distance_to(player.spawn_position) < 2.0, "the cat respawns at the spawn point")
	_check(GameState.hearts == GameState.max_hearts, "respawning refills hearts")


# --- Helpers ---------------------------------------------------------------------

func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _hold(action: StringName, n: int) -> void:
	Input.action_press(action)
	await _frames(n)
	Input.action_release(action)


## Holds jump (and taps it again mid-air if `second`) and returns peak height.
func _jump_peak(second: bool) -> float:
	var ground := player.global_position.y
	var best := ground
	Input.action_press(&"jump")
	for i in 90:
		await _frames(1)
		best = minf(best, player.global_position.y)
		if second and i == 20:
			Input.action_release(&"jump")
			await _frames(1)
			Input.action_press(&"jump")
	Input.action_release(&"jump")
	await _frames(20)
	return ground - best


func _teleport(cell_x: int, cell_y: int) -> void:
	player.global_position = Vector2(cell_x * TILE + 8, (cell_y + 1) * TILE)
	_teleport_hold()


func _teleport_hold() -> void:
	player.velocity = Vector2.ZERO
	player._change_state(Player.State.NORMAL)


func _nearest_rat(pos: Vector2) -> Node2D:
	var best: Node2D = null
	for n in game.current_room.get_node("Entities").get_children():
		if n is Enemy and (best == null or n.global_position.distance_to(pos) < best.global_position.distance_to(pos)):
			best = n
	return best


func _block_at(cell_x: int, cell_y: int) -> Node2D:
	var pos := Vector2(cell_x * TILE + 8, cell_y * TILE + 8)
	for n in game.current_room.get_node("Entities").get_children():
		if n is SoftBlock and n.global_position.distance_to(pos) < 1.0:
			return n
	return null
