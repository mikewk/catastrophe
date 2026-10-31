# Cat-astrophe

A 2D metroidvania in Godot 4.7 starring a cat. Abilities gate progress across
seven zones (Alley, Basement, Sewer, House, Barn, Rooftop, Park); combat is a
scratch attack plus energy-powered specials.

## Running

Open the folder in Godot 4.7 and press **F5**. The game currently starts in a
test room containing every mechanic. Controls are listed in the room's
on-screen hint.

| Action | Controller (Xbox) | Keyboard |
|---|---|---|
| Move | Left stick / D-pad | WASD / arrows |
| Jump | A | Space / Z |
| Scratch (+up, +down in air) | X | J / X |
| Special (25 energy) | Y | K / C |
| Sprint (needs Dash) | B / RT (hold) | Shift / L |
| Pause | Start | Esc |

Specials: **Spin** (press Special), **Pounce** (down + Special in the air),
**Dash attack** (Special while sprinting).

Debug keys (debug builds only): **F1** unlock all abilities, **F2** remove
abilities, **F3** refill hearts and energy.

## Layout

```
assets/          art and audio packs (see assets/README.md)
scenes/          player, enemies, world objects, rooms, UI, main game scene
scripts/
  autoload/      GameState: abilities, hearts, energy
  combat/        Hitbox / Hurtbox
  player/        cat controller and sprite animation
  enemies/       Enemy base class and enemy types
  world/         rooms, soft blocks, spikes, pickups
tools/           project setup and room-baking tools
tests/           scripted playtest
```

## Tools

Rooms can be sketched as text maps in `tools/rooms/<name>.txt` (legend at the
top of `tools/bake_room.gd`) and baked into scenes:

```
godot --headless res://tools/bake_room.tscn -- test_room
```

`tools/configure_project.gd` rewrites the project settings and input map.
`tools/build_cat_frames.gd` rebuilds the cat's animations from the sheets in
`assets/sprites/player/` (run it after adding or replacing a sheet):

```
godot --headless --script res://tools/build_cat_frames.gd
```

## Tests

A scripted playtest drives the cat through every mechanic and reports
pass/fail:

```
godot --headless res://tests/smoke_test.tscn
```
