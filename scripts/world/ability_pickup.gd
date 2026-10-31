class_name AbilityPickup
extends Area2D
## Grants a traversal ability when the cat touches it. Removes itself if the
## ability is already unlocked.

const COLOR := Color("ffd166")
## One-character placeholder labels until there are pickup sprites.
const LABELS := {"dash": ">", "double_jump": "2", "wall_jump": "W", "wall_climb": "C", "dig": "D"}

@export_enum("dash", "double_jump", "wall_jump", "wall_climb", "dig") var ability := "dash"

var _bob := 0.0


func _ready() -> void:
	if GameState.has_ability(StringName(ability)):
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_bob += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		GameState.unlock_ability(StringName(ability))
		queue_free()


func _draw() -> void:
	var y := -10.0 + sin(_bob * 3.0) * 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, y - 7), Vector2(6, y), Vector2(0, y + 7), Vector2(-6, y)]), COLOR)
	var font := ThemeDB.fallback_font
	var label: String = LABELS.get(ability, "?")
	draw_string(font, Vector2(-3, y + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)
