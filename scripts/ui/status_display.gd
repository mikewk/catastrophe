extends Control
## Draws the heart row and the energy bar. The bar is split into 25-energy
## segments, one per special attack.

const HEART_FULL := Color("e5484d")
const HEART_EMPTY := Color("4a3a46")
const ENERGY := Color("7fd8ff")
const ENERGY_BG := Color("2a3340")
const DENIED := Color("e5484d")
const PX_PER_ENERGY := 1.2

var _denied_timer := 0.0


func _ready() -> void:
	GameState.hearts_changed.connect(func(_c: int, _m: int) -> void: queue_redraw())
	GameState.energy_changed.connect(func(_c: float, _m: float) -> void: queue_redraw())
	GameState.energy_denied.connect(func() -> void: _denied_timer = 0.3)


func _process(delta: float) -> void:
	if _denied_timer > 0.0:
		_denied_timer -= delta
		queue_redraw()


func _draw() -> void:
	for i in GameState.max_hearts:
		_draw_heart(Vector2(8 + i * 13, 8), HEART_FULL if i < GameState.hearts else HEART_EMPTY)

	var bar := Rect2(8, 22, GameState.max_energy * PX_PER_ENERGY, 6)
	draw_rect(bar.grow(1), Color.BLACK)
	draw_rect(bar, ENERGY_BG)
	var fill := bar
	fill.size.x = GameState.energy * PX_PER_ENERGY
	draw_rect(fill, DENIED if _denied_timer > 0.0 else ENERGY)
	var segment := GameState.SPECIAL_COST
	while segment < GameState.max_energy:
		var x := bar.position.x + segment * PX_PER_ENERGY
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color.BLACK, 1.0)
		segment += GameState.SPECIAL_COST


func _draw_heart(pos: Vector2, color: Color) -> void:
	# 11x10 pixel heart.
	draw_rect(Rect2(pos + Vector2(1, 0), Vector2(3, 1)), color)
	draw_rect(Rect2(pos + Vector2(7, 0), Vector2(3, 1)), color)
	draw_rect(Rect2(pos + Vector2(0, 1), Vector2(11, 4)), color)
	draw_rect(Rect2(pos + Vector2(1, 5), Vector2(9, 2)), color)
	draw_rect(Rect2(pos + Vector2(3, 7), Vector2(5, 2)), color)
	draw_rect(Rect2(pos + Vector2(5, 9), Vector2(1, 1)), color)
