extends Node2D
## Temporary drawn cat used until real sprites are in assets/sprites/player/.
## Draws the body, plus a visual for each attack so hitboxes are readable
## while tuning.

const FUR := Color("e8913a")
const FUR_DARK := Color("b8692a")
const EYE := Color("1d1b26")
const CLAW := Color("fff4d6")
const SPECIAL := Color("7fd8ff")

@onready var player: Player = get_parent()


func _process(_delta: float) -> void:
	# Flicker while invulnerable.
	visible = not (player.is_invulnerable() and int(Time.get_ticks_msec() / 60.0) % 2 == 0)
	if player.state == Player.State.DEAD:
		modulate = Color(1, 1, 1, 0.4)
	else:
		modulate = Color.WHITE
	queue_redraw()


func _draw() -> void:
	var f := float(player.facing)
	var climbing := player.state in [Player.State.WALL_CLIMB, Player.State.WALL_SLIDE]

	if player.state == Player.State.SPIN:
		var angle := Time.get_ticks_msec() / 40.0
		draw_arc(Vector2(0, -9), 26, angle, angle + TAU * 0.75, 20, SPECIAL, 2.0)
		draw_circle(Vector2(0, -9), 9, FUR)
		return

	if climbing:
		# Upright against the wall: body vertical, head on top.
		draw_rect(Rect2(-5, -18, 10, 16), FUR)
		draw_rect(Rect2(-4, -26, 9, 8), FUR)
		_ears(Vector2(0.5, -26))
		draw_rect(Rect2(f * 1 - 0.5, -23, 2, 2), EYE)
		draw_line(Vector2(-f * 4, -4), Vector2(-f * 8, 2), FUR_DARK, 2.0)
	else:
		# Body, head at the front, tail at the back.
		draw_rect(Rect2(-8, -12, 14, 9), FUR)
		draw_rect(Rect2(-7, -3, 3, 3), FUR_DARK)
		draw_rect(Rect2(2, -3, 3, 3), FUR_DARK)
		var head := Rect2(f * 4 - 4.5 + f * 2, -18, 9, 9)
		draw_rect(head, FUR)
		_ears(Vector2(head.position.x + 4.5, -18))
		draw_rect(Rect2(head.position.x + 4.5 + f * 2 - 1, -15, 2, 2), EYE)
		var tail_base := Vector2(-f * 8, -10)
		draw_line(tail_base, tail_base + Vector2(-f * 5, -8), FUR_DARK, 2.0)

	if player.is_scratching():
		_draw_claws()
	if player.state == Player.State.POUNCE:
		draw_line(Vector2(-6, 6), Vector2(0, 14), SPECIAL, 2.0)
		draw_line(Vector2(6, 6), Vector2(0, 14), SPECIAL, 2.0)
	if player.state == Player.State.DASH_ATTACK:
		for i in 3:
			var y := -14.0 + i * 5.0
			draw_line(Vector2(-f * 10, y), Vector2(-f * 26, y), SPECIAL, 1.0)
		draw_rect(Rect2(f * 12 - 6, -16, 12, 14), Color(SPECIAL, 0.5))


func _ears(top_center: Vector2) -> void:
	var x := top_center.x
	var y := top_center.y
	draw_colored_polygon(PackedVector2Array([Vector2(x - 4.5, y), Vector2(x - 3, y - 4), Vector2(x - 1, y)]), FUR)
	draw_colored_polygon(PackedVector2Array([Vector2(x + 1, y), Vector2(x + 3, y - 4), Vector2(x + 4.5, y)]), FUR)


func _draw_claws() -> void:
	var c := player.scratch_hitbox.position
	match player.scratch_dir:
		Player.ScratchDir.SIDE:
			for i in 3:
				var dy := -5.0 + i * 5.0
				draw_line(c + Vector2(-4 * player.facing, dy - 3), c + Vector2(6 * player.facing, dy + 3), CLAW, 1.0)
		_:
			for i in 3:
				var dx := -6.0 + i * 6.0
				draw_line(c + Vector2(dx - 3, -5), c + Vector2(dx + 3, 5), CLAW, 1.0)
