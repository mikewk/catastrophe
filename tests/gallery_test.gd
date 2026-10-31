extends Node
## Checks the test room's bestiary gallery: every creature in creatures.json is
## placed, animates, stays in its pen, and can be defeated (death animation,
## then removed).
##   godot --headless res://tests/gallery_test.tscn

const PEN_HALF_WIDTH := 56.0

var _failures: Array[String] = []


func _ready() -> void:
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	game.player.global_position = Vector2(40, 672)  # Keep the cat out of the gallery.
	await _frames(5)

	var enemies: Array[BestiaryEnemy] = []
	var homes := {}
	for n in game.current_room.get_node("Entities").get_children():
		if n is BestiaryEnemy:
			enemies.append(n)
			homes[n] = n.global_position
	var ids := enemies.map(func(e: BestiaryEnemy) -> String: return e.creature_id)
	for id in Bestiary.all_ids():
		_check(id in ids, "%s is in the gallery" % id, true)
	_check(enemies.size() == Bestiary.all_ids().size(), "%d creatures placed" % enemies.size())

	await _frames(240)  # Let them patrol for four seconds.
	var stray := 0
	for e in enemies:
		var ok: bool = is_instance_valid(e) and e.sprite.is_playing() \
				and absf(e.global_position.x - homes[e].x) < PEN_HALF_WIDTH \
				and e.global_position.y <= homes[e].y + 8.0 and e.global_position.y > homes[e].y - 40.0
		if not ok:
			stray += 1
			_check(false, "%s stays in its pen and animates (at %s, home %s)" % [e.creature_id, e.global_position.round(), homes[e].round()], true)
	_check(stray == 0, "every creature stays in its pen and animates")

	# Defeat everything: each should play its death animation, then disappear.
	var hit := Hitbox.new()
	hit.damage = 99
	add_child(hit)
	for e in enemies:
		e.hurtbox.receive_hit(hit)
	await _frames(10)
	var dying := enemies.filter(func(e: BestiaryEnemy) -> bool:
		return is_instance_valid(e) and e.sprite.animation == &"death")
	_check(dying.size() == enemies.size(), "defeated creatures play their death animation (%d/%d)" % [dying.size(), enemies.size()])
	await _frames(60)
	var remaining := enemies.filter(func(e: Variant) -> bool: return is_instance_valid(e))
	_check(remaining.is_empty(), "creatures are removed after dying (%d left)" % remaining.size())

	print("\n%d check(s) failed" % _failures.size() if _failures else "\nAll checks passed")
	get_tree().quit(1 if _failures else 0)


func _check(ok: bool, what: String, quiet_when_ok := false) -> void:
	if not ok:
		_failures.append(what)
	if not (ok and quiet_when_ok):
		print(("  ok   " if ok else "  FAIL ") + what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
