extends SceneTree
## Writes the placeholder tile atlas used until a real tileset is chosen.
##   godot --headless --script res://tools/make_placeholder_tiles.gd
## Atlas layout (16x16 tiles): (0,0) solid ground, (1,0) one-way platform.

const OUT := "res://assets/tilesets/common/placeholder_tiles.png"


func _init() -> void:
	var img := Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
	# Solid tile.
	img.fill_rect(Rect2i(0, 0, 16, 16), Color("3b4252"))
	img.fill_rect(Rect2i(0, 0, 16, 2), Color("5e6b85"))
	img.fill_rect(Rect2i(0, 15, 16, 1), Color("2a2f3b"))
	img.fill_rect(Rect2i(15, 0, 1, 16), Color("2a2f3b"))
	img.set_pixel(4, 6, Color("4c556a"))
	img.set_pixel(10, 10, Color("4c556a"))
	# One-way platform: a plank along the top.
	img.fill_rect(Rect2i(16, 0, 16, 4), Color("a3835a"))
	img.fill_rect(Rect2i(16, 3, 16, 1), Color("6e5638"))
	img.fill_rect(Rect2i(19, 4, 2, 3), Color("6e5638"))
	img.fill_rect(Rect2i(27, 4, 2, 3), Color("6e5638"))
	var err := img.save_png(OUT)
	print("Saved ", OUT, ": ", error_string(err))
	quit(0 if err == OK else 1)
