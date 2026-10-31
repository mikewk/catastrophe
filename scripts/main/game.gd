extends Node
## Root of a play session. Owns the cat and the HUD, which persist while rooms
## are swapped underneath them.

@export var start_room: PackedScene

var current_room: Room

@onready var rooms: Node2D = $World/Rooms
@onready var player: Player = $World/Player
@onready var hud: Hud = $HUD


func _ready() -> void:
	GameState.new_game()
	load_room(start_room)


func load_room(room_scene: PackedScene, spawn_name: StringName = &"Default") -> void:
	if current_room:
		current_room.queue_free()
	current_room = room_scene.instantiate()
	rooms.add_child(current_room)
	player.set_camera_limits(current_room.get_bounds())
	player.place_at(current_room.get_spawn(spawn_name))
	hud.set_hint(current_room.hud_hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_tree().paused = not get_tree().paused
		hud.set_paused(get_tree().paused)
