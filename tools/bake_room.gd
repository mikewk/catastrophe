extends Node
## Turns a text map in tools/rooms/<name>.txt into scenes/rooms/<name>.tscn.
##   godot --headless res://tools/bake_room.tscn -- test_room
## (Runs as a scene rather than with --script so autoloads like GameState exist.)
##
## Map legend (one character per 16x16 tile):
##   #  solid ground          -  one-way platform
##   S  soft block (Dig)      ^  spikes
##   P  default spawn point   R  rat
##   1-5  ability pickup: 1 Dash, 2 Double Jump, 3 Wall Jump, 4 Wall Climb, 5 Dig
##   E  bestiary creature slot: slots are filled with every creature in
##      BESTIARY/creatures.json, in the pack's order, bottom row first and left
##      to right, each labelled with its id. Flyers hover above their slot.
## An optional tools/rooms/<name>.hint.txt becomes the room's HUD hint text.
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
	"R": preload("res://scenes/enemies/rat.tscn"),
	"pickup": preload("res://scenes/world/ability_pickup.tscn"),
	"E": preload("res://scenes/enemies/bestiary_enemy.tscn"),
}
## How far above its slot a flying creature hovers.
const FLYER_HEIGHT := 56.0


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
					_spawn(root, entities, _scenes[c], feet)
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
