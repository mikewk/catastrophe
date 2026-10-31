class_name Room
extends Node2D
## One room of a zone. The camera is limited to the area covered by the
## Terrain tilemap. Spawn points are Marker2D children of "Spawns"; "Default"
## is used when entering without a specific door.
##
## Rooms are at most 3 screens wide and 4 screens tall (1920x1440 px).

const MAX_SIZE := Vector2(1920, 1440)

## Text shown in the HUD while in this room (used by the test room for controls).
@export_multiline var hud_hint := ""

@onready var terrain: TileMapLayer = $Terrain


func get_bounds() -> Rect2:
	var used := terrain.get_used_rect()
	var tile := Vector2(terrain.tile_set.tile_size)
	return Rect2(Vector2(used.position) * tile, Vector2(used.size) * tile)


func get_spawn(spawn_name: StringName = &"Default") -> Vector2:
	var marker := get_node_or_null(NodePath("Spawns/" + String(spawn_name))) as Marker2D
	if marker == null:
		push_warning("Room %s has no spawn named %s" % [name, spawn_name])
		return Vector2.ZERO
	return marker.global_position
