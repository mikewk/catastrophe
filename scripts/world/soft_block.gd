class_name SoftBlock
extends StaticBody2D
## A 16x16 block that a scratch breaks once the cat has Dig. Without Dig it
## just flashes, telling the player it needs something more.

const SIZE := 16.0
const COLOR := Color("8b5e3c")
const CRACK := Color("5a3a22")

var _flash_timer := 0.0


func dig(_hitbox: Hitbox) -> void:
	if GameState.has_ability(GameState.DIG):
		queue_free()
	else:
		_flash_timer = 0.12
		queue_redraw()


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			queue_redraw()


func _draw() -> void:
	var half := SIZE / 2.0
	draw_rect(Rect2(-half, -half, SIZE, SIZE), Color.WHITE if _flash_timer > 0.0 else COLOR)
	draw_line(Vector2(-5, -8), Vector2(-1, -1), CRACK, 1.0)
	draw_line(Vector2(-1, -1), Vector2(4, 2), CRACK, 1.0)
	draw_line(Vector2(-1, -1), Vector2(-3, 6), CRACK, 1.0)
