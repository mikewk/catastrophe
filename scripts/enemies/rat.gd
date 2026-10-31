extends Enemy
## Rat: basic enemy. Walks back and forth, turning at walls and ledges.
## Drawn as a placeholder until sprites are added.

const BODY := Color("8a8494")
const TAIL := Color("e0a3b0")


func _behave(_delta: float) -> void:
	if is_on_floor() and (is_on_wall() or _ledge_ahead()):
		facing = -facing
	velocity.x = facing * move_speed


func _draw() -> void:
	var color := Color.WHITE if is_flashing() else BODY
	var f := float(facing)
	draw_rect(Rect2(-8, -8, 16, 8), color)
	draw_rect(Rect2(f * 8 - 3, -7, 6, 5), color)
	draw_rect(Rect2(f * 3 - 1, -11, 3, 3), color)
	draw_rect(Rect2(f * 9 - 1, -6, 2, 2), Color.BLACK)
	draw_line(Vector2(-f * 8, -4), Vector2(-f * 16, -8), TAIL, 1.0)
