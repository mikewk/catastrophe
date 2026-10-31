extends SceneTree
## Builds resources/sprites/cat_frames.tres (SpriteFrames) from the sheets in
## assets/sprites/player/. Re-run after replacing or adding sheets:
##   godot --headless --script res://tools/build_cat_frames.gd
##
## Each sheet is one row of 80x64 frames with the cat facing left and its
## feet at y=48.

const FRAME := Vector2i(80, 64)
const DIR := "res://assets/sprites/player/"
const OUT := "res://resources/sprites/cat_frames.tres"

## animation name: [sheet file, fps, loops]. fps 0 = frames picked in code.
const ANIMATIONS := {
	"idle": ["IDLE.png", 8.0, true],
	"walk": ["WALK.png", 14.0, true],
	"run": ["RUN.png", 14.0, true],
	"attack": ["ATTACK 1.png", 20.0, false],
	"hurt": ["HURT.png", 12.0, false],
	"jump": ["JUMP.png", 0.0, false],
	"running_jump": ["RUNNING JUMP.png", 0.0, false],
}


func _init() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim_name: String in ANIMATIONS:
		var spec: Array = ANIMATIONS[anim_name]
		var sheet: Texture2D = load(DIR + spec[0])
		if sheet == null:
			push_error("Missing sheet " + spec[0])
			quit(1)
			return
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, maxf(spec[1], 1.0))
		frames.set_animation_loop(anim_name, spec[2])
		for i in sheet.get_width() / FRAME.x:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * FRAME.x, 0, FRAME.x, FRAME.y)
			frames.add_frame(anim_name, atlas)
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err := ResourceSaver.save(frames, OUT)
	print("Saved ", OUT, ": ", error_string(err))
	quit(0 if err == OK else 1)
