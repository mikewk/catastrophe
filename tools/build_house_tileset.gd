extends SceneTree
## Builds resources/tilesets/house_tileset.tres from the 8x8 tiles in
## assets/tilesets/house/House/. Each PNG becomes one atlas source whose
## resource_name is the file name (without .png), so rooms can ask for tiles by
## name ("OuterWall_Tile13_Left", "Platform_Middle", "Wallpaper2_Tile"...).
##   godot --headless --script res://tools/build_house_tileset.gd
##
## The tileset is visual only: collision comes from the room's Terrain layer.
## Larger pieces (doors, windows) are placed as decorations instead.

const DIR := "res://assets/tilesets/house/House/"
const OUT := "res://resources/tilesets/house_tileset.tres"
const TILE := Vector2i(8, 8)


func _init() -> void:
	var ts := TileSet.new()
	ts.tile_size = TILE
	var count := 0
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".png"):
			continue
		var tex: Texture2D = load(DIR + file)
		if tex == null or Vector2i(tex.get_size()) != TILE:
			continue
		var source := TileSetAtlasSource.new()
		source.resource_name = file.get_basename()
		source.texture = tex
		source.texture_region_size = TILE
		source.create_tile(Vector2i.ZERO)
		ts.add_source(source)
		count += 1
	var err := ResourceSaver.save(ts, OUT)
	print("Saved %s with %d tiles: %s" % [OUT, count, error_string(err)])
	quit(0 if err == OK else 1)
