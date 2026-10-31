extends Node
## Checks that every creature in BESTIARY/creatures.json imports and loads:
## its SpriteFrames exists, has the five states with the right frame counts,
## loop flags and fps, and every frame texture loads at the stated cell size.
##   godot --headless res://tests/verify_bestiary.tscn

const STATES := ["idle", "move", "attack", "hit", "death"]


func _ready() -> void:
	var problems: Array[String] = []
	var manifest := Bestiary.manifest()
	var creatures: Array = manifest.get("creatures", [])
	if creatures.is_empty():
		problems.append("creatures.json could not be read")
	var frames_checked := 0

	for c: Dictionary in creatures:
		var id: String = c["id"]
		var sf := Bestiary.load_frames(id)
		if sf == null:
			problems.append("%s: no SpriteFrames" % id)
			continue
		var cell := Vector2i(c["cell_px"][0], c["cell_px"][1])
		for state: String in STATES:
			var spec: Dictionary = c["states"][state]
			if not sf.has_animation(state):
				problems.append("%s: missing animation %s" % [id, state])
				continue
			var count := sf.get_frame_count(state)
			if count != int(spec["frames"]):
				problems.append("%s/%s: %d frames, manifest says %d" % [id, state, count, spec["frames"]])
			if sf.get_animation_loop(state) != bool(spec["loop"]):
				problems.append("%s/%s: loop flag differs from manifest" % [id, state])
			if not is_equal_approx(sf.get_animation_speed(state), float(c["fps"])):
				problems.append("%s/%s: speed %s, manifest fps %s" % [id, state, sf.get_animation_speed(state), c["fps"]])
			for i in count:
				var tex := sf.get_frame_texture(state, i)
				frames_checked += 1
				if tex == null:
					problems.append("%s/%s frame %d: texture missing" % [id, state, i])
				elif Vector2i(tex.get_size()) != cell:
					problems.append("%s/%s frame %d: size %s, expected %s" % [id, state, i, tex.get_size(), cell])

	print("Checked %d creatures, %d frames" % [creatures.size(), frames_checked])
	if Bestiary.all_ids().size() != creatures.size():
		problems.append("Bestiary.all_ids() returned %d ids" % Bestiary.all_ids().size())
	for p in problems:
		print("  FAIL ", p)
	print("All creatures load correctly" if problems.is_empty() else "%d problem(s)" % problems.size())
	get_tree().quit(0 if problems.is_empty() else 1)
