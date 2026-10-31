extends SceneTree
## One-off tool that writes project settings and the input map through Godot's
## own serializer. Run from the project folder:
##   godot --headless --script res://tools/configure_project.gd
## Safe to re-run: it overwrites the same keys.

const STICK_DEADZONE := 0.3


func _init() -> void:
	_set_general()
	_set_display()
	_set_physics_layers()
	_set_input_map()
	var err := ProjectSettings.save()
	print("Saved project settings: ", error_string(err))
	quit(0 if err == OK else 1)


func _set_general() -> void:
	ProjectSettings.set_setting("application/config/name", "Cat-astrophe")
	ProjectSettings.set_setting("application/run/main_scene", "res://scenes/main/game.tscn")
	ProjectSettings.set_setting("autoload/GameState", "*res://scripts/autoload/game_state.gd")


func _set_display() -> void:
	# 640x360 base resolution: 40x22.5 tiles of 16px, scaled up by whole numbers.
	ProjectSettings.set_setting("display/window/size/viewport_width", 640)
	ProjectSettings.set_setting("display/window/size/viewport_height", 360)
	ProjectSettings.set_setting("display/window/size/window_width_override", 1280)
	ProjectSettings.set_setting("display/window/size/window_height_override", 720)
	ProjectSettings.set_setting("display/window/stretch/mode", "viewport")
	ProjectSettings.set_setting("display/window/stretch/aspect", "keep")
	ProjectSettings.set_setting("display/window/stretch/scale_mode", "integer")
	ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", 0)
	ProjectSettings.set_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", true)
	ProjectSettings.set_setting("rendering/environment/defaults/default_clear_color", Color("1d1b26"))


func _set_physics_layers() -> void:
	var names := ["world", "soft_blocks", "player", "enemies", "player_hurtbox",
			"enemy_hurtbox", "one_way"]
	for i in names.size():
		ProjectSettings.set_setting("layer_names/2d_physics/layer_%d" % (i + 1), names[i])


func _set_input_map() -> void:
	# Controller first (Xbox layout), keyboard as fallback.
	_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _pad(JOY_BUTTON_DPAD_LEFT),
			_axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _pad(JOY_BUTTON_DPAD_RIGHT),
			_axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("move_up", [_key(KEY_W), _key(KEY_UP), _pad(JOY_BUTTON_DPAD_UP),
			_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("move_down", [_key(KEY_S), _key(KEY_DOWN), _pad(JOY_BUTTON_DPAD_DOWN),
			_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("jump", [_key(KEY_SPACE), _key(KEY_Z), _pad(JOY_BUTTON_A)])
	_action("attack", [_key(KEY_J), _key(KEY_X), _pad(JOY_BUTTON_X)])
	_action("special", [_key(KEY_K), _key(KEY_C), _pad(JOY_BUTTON_Y)])
	_action("dash", [_key(KEY_SHIFT), _key(KEY_L), _pad(JOY_BUTTON_B),
			_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action("pause", [_key(KEY_ESCAPE), _pad(JOY_BUTTON_START)])


func _action(action_name: String, events: Array) -> void:
	for ev: InputEvent in events:
		ev.device = -1  # All devices, so any controller works.
	ProjectSettings.set_setting("input/" + action_name,
			{"deadzone": STICK_DEADZONE, "events": events})


func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	return ev


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev
