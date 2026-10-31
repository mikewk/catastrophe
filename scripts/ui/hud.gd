class_name Hud
extends CanvasLayer
## Hearts, energy, ability-unlock messages, room hint text and the pause label.

@onready var toast: Label = $Toast
@onready var hint: Label = $Hint
@onready var paused_label: Label = $Paused

var _toast_timer := 0.0


func _ready() -> void:
	GameState.ability_unlocked.connect(_on_ability_unlocked)
	toast.visible = false
	paused_label.visible = false


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		toast.modulate.a = clampf(_toast_timer, 0.0, 1.0)
		toast.visible = _toast_timer > 0.0


func set_hint(text: String) -> void:
	hint.text = text
	hint.visible = not text.is_empty()


func set_paused(is_paused: bool) -> void:
	paused_label.visible = is_paused


func _on_ability_unlocked(ability: StringName) -> void:
	toast.text = "Unlocked: %s" % GameState.ability_display_name(ability)
	_toast_timer = 2.5
	toast.visible = true
