@tool
class_name Bestiary
extends AnimatedSprite2D

## Plays one BESTIARY creature.
##
## Drop this script on an AnimatedSprite2D, set `creature_id`, and call
## attack() / hurt() / die(). The SpriteFrames resources under
## engine/godot/sprite_frames/ already carry the authored fps (10) and the loop
## flags -- idle and move loop, attack / hit / death play once -- so there is
## nothing else to configure.
##
## Pixel art: by default this node forces TEXTURE_FILTER_NEAREST on itself, so the
## sprites stay crisp even if your project default is linear. Leave the PNGs on
## Lossless compression with mipmaps off; see engine/USAGE.md.

signal state_finished(state: StringName)
signal died

## Where the pack folder sits in your project. The .tres files name their frames
## absolutely, as "res://BESTIARY/frames/...". If you put the pack somewhere else,
## find-and-replace "res://BESTIARY/" inside engine/godot/sprite_frames/*.tres and
## change this constant to match.
const PACK_ROOT := "res://BESTIARY"
const SPRITE_FRAMES_DIR := PACK_ROOT + "/engine/godot/sprite_frames"
const MANIFEST := PACK_ROOT + "/creatures.json"

const LOOPING: Array[StringName] = [&"idle", &"move"]
const ONE_SHOT: Array[StringName] = [&"attack", &"hit", &"death"]

@export var creature_id := "slime_green":
	set(v):
		creature_id = v
		_reload()
## Which state to play on _ready(). Ignored in the editor.
@export var start_state: StringName = &"idle"
## Go back to idle when attack or hit finishes. death always holds its last frame.
@export var auto_return_to_idle := true
## Force TEXTURE_FILTER_NEAREST on this node. Turn it off only if you want the
## node to inherit filtering from its parent.
@export var force_nearest_filter := true

var _state: StringName = &""


func _ready() -> void:
	_apply_filter()
	if sprite_frames == null:
		_reload()
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)
	if not Engine.is_editor_hint():
		play_state(start_state)


func _apply_filter() -> void:
	if force_nearest_filter:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _reload() -> void:
	var sf := load_frames(creature_id)
	if sf != null:
		sprite_frames = sf
		_apply_filter()
		if _state != &"" and sf.has_animation(_state):
			animation = _state
		else:
			animation = &"idle"


## Play a state by name: "idle", "move", "attack", "hit" or "death".
func play_state(state: StringName) -> void:
	if sprite_frames == null or not sprite_frames.has_animation(state):
		push_warning("Bestiary: %s has no state %s" % [creature_id, state])
		return
	_state = state
	play(state)


func idle() -> void:
	play_state(&"idle")


func move() -> void:
	play_state(&"move")


func attack() -> void:
	play_state(&"attack")


func hurt() -> void:
	play_state(&"hit")


func die() -> void:
	play_state(&"death")


func current_state() -> StringName:
	return _state


## True for idle and move, false for attack, hit and death.
static func loops(state: StringName) -> bool:
	return state in LOOPING


func is_dead() -> bool:
	return _state == &"death" and not is_playing()


func _on_animation_finished() -> void:
	# AnimatedSprite2D only emits this for non-looping animations, so idle and move
	# never reach here.
	state_finished.emit(_state)
	if _state == &"death":
		died.emit()
		return
	if auto_return_to_idle and _state in ONE_SHOT:
		play_state(&"idle")


# ------------------------------------------------------------------ data ----

## Load one creature's SpriteFrames without instancing a node.
static func load_frames(id: String) -> SpriteFrames:
	var p := SPRITE_FRAMES_DIR + "/" + id + ".tres"
	if not ResourceLoader.exists(p):
		push_error("Bestiary: no SpriteFrames at " + p)
		return null
	return load(p) as SpriteFrames


## The whole of creatures.json as a Dictionary.
static func manifest() -> Dictionary:
	var f := FileAccess.open(MANIFEST, FileAccess.READ)
	if f == null:
		push_error("Bestiary: cannot open " + MANIFEST)
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


## All 53 creature ids, in the pack's own order.
static func all_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for c in manifest().get("creatures", []):
		out.append(String(c.get("id", "")))
	return out


## The ids in one family: Aberrations, Crawlers, Flyers, Slimes, Undead.
static func ids_in_family(family: String) -> PackedStringArray:
	var out := PackedStringArray()
	for c in manifest().get("creatures", []):
		if String(c.get("family", "")) == family:
			out.append(String(c.get("id", "")))
	return out


## Add a creature to the scene at a position and return it.
static func spawn(parent: Node, id: String, pos := Vector2.ZERO) -> Bestiary:
	var b := Bestiary.new()
	b.creature_id = id
	b.position = pos
	parent.add_child(b)
	return b
