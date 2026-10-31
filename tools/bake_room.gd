extends Node
## Turns a text map in tools/rooms/<name>.txt into scenes/rooms/<name>.tscn.
##   godot --headless res://tools/bake_room.tscn -- test_room
## (Runs as a scene rather than with --script so autoloads like GameState exist.)
##
## Map legend (one character per 16x16 tile):
##   #  solid ground          -  one-way platform
##   S  soft block (Dig)      ^  spikes
##   P  default spawn point   R  rat (BESTIARY grey and plague rats, alternating)
##   1-5  ability pickup: 1 Dash, 2 Double Jump, 3 Wall Jump, 4 Wall Climb, 5 Dig
##   E  bestiary creature slot: slots are filled with every creature in
##      BESTIARY/creatures.json, in the pack's order, bottom row first and left
##      to right, each labelled with its id. Flyers hover above their slot.
## An optional tools/rooms/<name>.hint.txt becomes the room's HUD hint text.
##
## An optional tools/rooms/<name>.decor.txt sets the room's art. One command per
## line, cell coordinates, # starts a comment:
##   tileset house                       draw the room with the house tiles
##                                       (otherwise the placeholder tiles show)
##   wallpaper <Name> x0 y0 x1 y1        background wallpaper for a block of
##                                       cells, e.g. Wallpaper2 (later lines win)
##   <Asset> x y [dx dy]                 a decoration from house/Furniture or
##                                       house/House (drawn at 2x), standing on
##                                       the bottom of cell (x, y), nudged by
##                                       (dx, dy) pixels
## Decorations and art are visual only; collision always comes from the map.
##
## The baked scene is a normal Godot scene: it can be edited in the editor
## afterwards, but re-baking overwrites it.

const TILE := 16
const TILESET_PATH := "res://resources/tilesets/placeholder_tileset.tres"
const ATLAS_PATH := "res://assets/tilesets/common/placeholder_tiles.png"
const SOLID := Vector2i(0, 0)
const ONE_WAY := Vector2i(1, 0)
const ABILITIES := ["dash", "double_jump", "wall_jump", "wall_climb", "dig"]

var _scenes := {
	"S": preload("res://scenes/world/soft_block.tscn"),
	"^": preload("res://scenes/world/spikes.tscn"),
	"pickup": preload("res://scenes/world/ability_pickup.tscn"),
	"E": preload("res://scenes/enemies/bestiary_enemy.tscn"),
}
## How far above its slot a flying creature hovers.
const FLYER_HEIGHT := 56.0
const RAT_IDS := ["rat_grey", "rat_plague"]

const HOUSE_TILESET := "res://resources/tilesets/house_tileset.tres"
const HOUSE_DIRS := ["res://assets/tilesets/house/Furniture/", "res://assets/tilesets/house/House/"]
const DEFAULT_WALLPAPER := "Wallpaper1"
## House art is drawn at this scale so it's in proportion with the cat.
const HOUSE_SCALE := 2.0
const HASH := 35  # "#"
const DASH := 45  # "-"
## Wallpaper is dimmed so the cat and enemies stand out against it.
const WALLPAPER_TINT := Color(0.5, 0.48, 0.58)
## Solid areas get a dark backing so the seams between beams read as shadow.
const BACKING_TINT := Color("2b1630")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Usage: godot --headless res://tools/bake_room.tscn -- <room_name>")
		get_tree().quit(1)
		return
	var room_name: String = args[0]
	var tileset := _get_or_build_tileset()
	var err := _bake(room_name, tileset)
	get_tree().quit(0 if err == OK else 1)


func _bake(room_name: String, tileset: TileSet) -> Error:
	var map_text := FileAccess.get_file_as_string("res://tools/rooms/%s.txt" % room_name)
	if map_text.is_empty():
		push_error("Map not found: tools/rooms/%s.txt" % room_name)
		return ERR_FILE_NOT_FOUND
	var lines := map_text.split("\n", false)

	var root := Node2D.new()
	root.name = room_name.to_pascal_case()
	root.set_script(load("res://scripts/world/room.gd"))
	var hint_path := "res://tools/rooms/%s.hint.txt" % room_name
	if FileAccess.file_exists(hint_path):
		root.set("hud_hint", FileAccess.get_file_as_string(hint_path).strip_edges())

	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = tileset
	_add(root, root, terrain)
	var spawns := Node2D.new()
	spawns.name = "Spawns"
	_add(root, root, spawns)
	var entities := Node2D.new()
	entities.name = "Entities"
	_add(root, root, entities)

	var creature_slots: Array[Vector2i] = []
	var rats_placed := 0
	for y in lines.size():
		var line := lines[y]
		for x in line.length():
			var c := line[x]
			var cell := Vector2i(x, y)
			var center := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			var feet := Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
			match c:
				"#":
					terrain.set_cell(cell, 0, SOLID)
				"-":
					terrain.set_cell(cell, 0, ONE_WAY)
				"S", "^":
					_spawn(root, entities, _scenes[c], center)
				"R":
					var rat := _spawn(root, entities, _scenes["E"], feet)
					rat.name = "Rat%d" % (rats_placed + 1)
					rat.set("creature_id", RAT_IDS[rats_placed % RAT_IDS.size()])
					rats_placed += 1
				"P":
					var marker := Marker2D.new()
					marker.name = "Default"
					marker.position = feet
					_add(root, spawns, marker)
				"1", "2", "3", "4", "5":
					var pickup := _spawn(root, entities, _scenes["pickup"], feet)
					pickup.set("ability", ABILITIES[int(c) - 1])
				"E":
					creature_slots.append(cell)
				" ":
					pass
				_:
					push_warning("Unknown map character '%s' at %s" % [c, cell])

	_place_creatures(root, entities, creature_slots)
	_apply_decor(room_name, root, terrain, lines)

	# Test rooms are exempt from the 3x4 screen limit on game rooms.
	var size := Vector2(terrain.get_used_rect().size * TILE)
	if not room_name.begins_with("test") and (size.x > 1920 or size.y > 1440):
		push_warning("Room is %s px, larger than the 3x4 screen limit (1920x1440)" % size)

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		var out := "res://scenes/rooms/%s.tscn" % room_name
		DirAccess.make_dir_recursive_absolute("res://scenes/rooms")
		err = ResourceSaver.save(packed, out)
		print("Baked ", out, " (", lines.size(), " rows): ", error_string(err))
	root.free()
	return err


# --- Art -----------------------------------------------------------------------

func _apply_decor(room_name: String, root: Node2D, terrain: TileMapLayer, lines: PackedStringArray) -> void:
	var path := "res://tools/rooms/%s.decor.txt" % room_name
	if not FileAccess.file_exists(path):
		return
	var wallpapers: Array = []  # [name, Rect2i] in file order
	var decorations: Array = []  # [asset, cell, offset]
	var style := ""
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.get_slice("#", 0).strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(" ", false)
		match parts[0]:
			"tileset":
				style = parts[1]
			"wallpaper":
				var r := Rect2i(int(parts[2]), int(parts[3]), 0, 0)
				r.end = Vector2i(int(parts[4]) + 1, int(parts[5]) + 1)
				wallpapers.append([parts[1], r])
			_:
				var offset := Vector2.ZERO
				if parts.size() >= 5:
					offset = Vector2(float(parts[3]), float(parts[4]))
				decorations.append([parts[0], Vector2i(int(parts[1]), int(parts[2])), offset])

	if style == "house":
		_paint_house(root, terrain, lines, wallpapers)
	var decor := Node2D.new()
	decor.name = "Decor"
	decor.z_index = -1
	_add(root, root, decor)
	root.move_child(decor, terrain.get_index() + 1)
	for d: Array in decorations:
		_place_decoration(root, decor, d[0], d[1], d[2])


## Draws the room with the house tiles. The house art is drawn for small
## characters, so it's shown at 2x: each 8x8 tile fills one 16x16 map cell and
## furniture keeps sensible proportions next to the cat. Solid areas become
## stacked beams (horizontal on wide runs, vertical on tall ones) over a dark
## backing, one-way platforms become shelves, and everything sits on wallpaper.
func _paint_house(root: Node2D, terrain: TileMapLayer, lines: PackedStringArray, wallpapers: Array) -> void:
	var ts: TileSet = load(HOUSE_TILESET)
	var ids := {}
	for i in ts.get_source_count():
		var sid := ts.get_source_id(i)
		ids[ts.get_source(sid).resource_name] = sid
	terrain.visible = false  # Collision only from here on.

	var wallpaper := _art_layer(root, terrain, "Wallpaper", ts, -3, WALLPAPER_TINT)
	var backing := _art_layer(root, terrain, "Backing", ts, -2, BACKING_TINT)
	var structure := _art_layer(root, terrain, "Structure", ts, 0, Color.WHITE)

	var w := 0
	for line in lines:
		w = maxi(w, line.length())
	var h := lines.size()
	# Map characters as a flat byte grid (reading the strings directly is slow).
	var grid := PackedByteArray()
	grid.resize(w * h)
	for y in h:
		var bytes := lines[y].to_ascii_buffer()
		for x in bytes.size():
			grid[y * w + x] = bytes[x]
	var is_char := func(x: int, y: int, c: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and grid[y * w + x] == c
	var solid := func(x: int, y: int) -> bool: return is_char.call(x, y, HASH)

	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var paper := DEFAULT_WALLPAPER
			for wp: Array in wallpapers:
				if (wp[1] as Rect2i).has_point(cell):
					paper = wp[0]
			_set_tile(wallpaper, ids, cell, paper + "_Tile")

			if solid.call(x, y):
				_set_tile(backing, ids, cell, DEFAULT_WALLPAPER + "_Tile")
				var h_run := _run(solid, x, y, Vector2i(1, 0))
				var v_run := _run(solid, x, y, Vector2i(0, 1))
				_set_tile(structure, ids, cell, "OuterWall_Tile13_Left" if h_run >= v_run else "OuterWall_Tile10_Left")
			elif is_char.call(x, y, DASH):
				var left: bool = is_char.call(x - 1, y, DASH)
				var right: bool = is_char.call(x + 1, y, DASH)
				var piece := "Platform_Middle"
				if not left and not right:
					piece = "Platform_Single"
				elif not left:
					piece = "Platform_Left"
				elif not right:
					piece = "Platform_Right"
				_set_tile(structure, ids, cell, piece)


func _art_layer(root: Node2D, terrain: TileMapLayer, layer_name: String, ts: TileSet, z: int, tint: Color) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = ts
	layer.z_index = z
	layer.modulate = tint
	layer.collision_enabled = false
	layer.scale = Vector2(HOUSE_SCALE, HOUSE_SCALE)
	_add(root, root, layer)
	root.move_child(layer, terrain.get_index() + 1 + ["Wallpaper", "Backing", "Structure"].find(layer_name))
	return layer


func _set_tile(layer: TileMapLayer, ids: Dictionary, cell: Vector2i, tile_name: String) -> void:
	if not ids.has(tile_name):
		push_warning("House tileset has no tile " + tile_name)
		return
	layer.set_cell(cell, ids[tile_name], Vector2i.ZERO)


## Length of the solid run through (x, y) along `step`, counted both ways.
func _run(solid: Callable, x: int, y: int, step: Vector2i) -> int:
	var n := 1
	for dir: int in [1, -1]:
		var p := Vector2i(x, y) + step * dir
		while n < 16 and solid.call(p.x, p.y):
			n += 1
			p += step * dir
	return n


func _place_decoration(root: Node, parent: Node, asset: String, cell: Vector2i, offset: Vector2) -> void:
	var tex: Texture2D = null
	for dir: String in HOUSE_DIRS:
		if ResourceLoader.exists(dir + asset + ".png"):
			tex = load(dir + asset + ".png")
			break
	if tex == null:
		push_warning("No decoration called " + asset)
		return
	var sprite := Sprite2D.new()
	sprite.name = asset.validate_node_name()
	sprite.texture = tex
	sprite.offset = Vector2(0, -tex.get_height() / 2.0)  # Bottom-centre anchor.
	sprite.scale = Vector2(HOUSE_SCALE, HOUSE_SCALE)
	sprite.position = Vector2(cell.x * TILE + TILE / 2.0, (cell.y + 1) * TILE) + offset
	parent.add_child(sprite, true)
	sprite.owner = root


# --- Creatures -------------------------------------------------------------------

func _place_creatures(root: Node, parent: Node, slots: Array[Vector2i]) -> void:
	if slots.is_empty():
		return
	# Bottom row first (where the player usually arrives), then left to right.
	slots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y > b.y if a.y != b.y else a.x < b.x)
	var ids := Bestiary.all_ids()
	if slots.size() != ids.size():
		push_warning("%d E slots for %d creatures" % [slots.size(), ids.size()])
	for i in mini(slots.size(), ids.size()):
		var feet := Vector2(slots[i].x * TILE + TILE / 2.0, (slots[i].y + 1) * TILE)
		_spawn_creature(root, parent, ids[i], feet)


func _spawn_creature(root: Node, parent: Node, id: String, feet: Vector2) -> void:
	var movement := BestiaryEnemy.movement_for(id)
	var pos := feet
	if movement == BestiaryEnemy.Movement.FLY:
		pos.y -= FLYER_HEIGHT
	var enemy := _spawn(root, parent, _scenes["E"], pos)
	enemy.name = id.to_pascal_case()
	enemy.set("creature_id", id)
	enemy.set("movement", movement)
	if movement == BestiaryEnemy.Movement.FLY:
		enemy.set("move_speed", 30.0)

	var label := Label.new()
	label.name = enemy.name + "Label"
	label.text = id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(feet.x - 48, feet.y - 112)
	label.size = Vector2(96, 12)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	_add(root, parent, label)


func _spawn(root: Node, parent: Node, scene: PackedScene, pos: Vector2) -> Node2D:
	var node: Node2D = scene.instantiate()
	node.position = pos
	parent.add_child(node, true)
	node.owner = root
	return node


func _add(root: Node, parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = root


func _get_or_build_tileset() -> TileSet:
	if ResourceLoader.exists(TILESET_PATH):
		return load(TILESET_PATH)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()  # 0: world (layer 1)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()  # 1: one-way platforms (layer 7)
	ts.set_physics_layer_collision_layer(1, 64)
	ts.set_physics_layer_collision_mask(1, 0)

	var source := TileSetAtlasSource.new()
	source.texture = load(ATLAS_PATH)
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(SOLID)
	source.create_tile(ONE_WAY)
	ts.add_source(source, 0)

	var h := TILE / 2.0
	var solid := source.get_tile_data(SOLID, 0)
	solid.add_collision_polygon(0)
	solid.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	var one_way := source.get_tile_data(ONE_WAY, 0)
	one_way.add_collision_polygon(1)
	one_way.set_collision_polygon_points(1, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 4), Vector2(-h, -h + 4)]))
	one_way.set_collision_polygon_one_way(1, 0, true)

	DirAccess.make_dir_recursive_absolute("res://resources/tilesets")
	var err := ResourceSaver.save(ts, TILESET_PATH)
	print("Built tileset ", TILESET_PATH, ": ", error_string(err))
	return ts
