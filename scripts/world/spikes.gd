extends Hitbox
## One tile of spikes. Costs a heart and sends the cat back to safe ground.

const COLOR := Color("c9ced6")


func _draw() -> void:
	for i in 4:
		var x := -8.0 + i * 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 8), Vector2(x + 2, 1), Vector2(x + 4, 8)]), COLOR)
