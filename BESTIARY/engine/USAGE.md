# Using BESTIARY in your engine

Every number in this file was measured off the files in this pack -- frame counts and
cell sizes come from the PNGs themselves, not from a spec -- and re-checked against
the shipped files after they were written.

Everything under `engine/` -- the three scripts and the 53 `.tres` resources -- is **MIT
licensed**, so paste it into a commercial codebase, edit it and ship it without
attribution. The art keeps the pack's asset licence. Both are in `LICENSE.txt`.

## What is here

| | |
|---|---|
| Creatures | **53** |
| States each | idle, move, attack, hit, death |
| Frames per creature | idle 4 + move 6 + attack 4 + hit 2 + death 6 (22 PNGs) |
| Animation clips | 265 |
| Frame PNGs | 1,166 |
| Cell sizes | 45 creatures at 32x32, 8 creatures at 48x48 |
| Rate | 10 fps, from `creatures.json` |
| Loop | idle and move loop; attack, hit and death play once |
| Families | Aberrations 9 / Crawlers 14 / Flyers 10 / Slimes 8 / Undead 12 |

Every frame is **binary alpha** -- 1,166 PNGs checked, zero semi-transparent
pixels -- so they colour-key cleanly, atlas with no bleed and stay exact at any
integer scale. **Nearest-neighbour only. Never resample these with a smoothing
filter.**

| Folder | What it is |
|---|---|
| `frames/<creature>/<state>/` | the loose PNGs, one per frame, zero-padded in play order |
| `sheets/` | one horizontal strip per creature per state, 265 files |
| `sheets_2x/` | the same strips, an exact 2x nearest-neighbour copy, pixel for pixel |
| `gif/` | 53 creature reels + `gif/states/` with 265 single-state GIFs |
| `catalog/` | `CATALOG.gif` and 5 per-family contact sheets |
| `engine/godot/` | `Bestiary.gd` and 53 ready-made `SpriteFrames` `.tres` |
| `engine/unity/` | `BestiaryAnimator.cs` (runtime) and `Editor/BestiaryImporter.cs` (editor-only) |

Sheets are a single row of square cells, so **cell = image height** and
**frames = width / height**. That is how the Unity importer sizes them; it never
hardcodes 32.

`gif/` and `catalog/` are preview material -- for your store page, your design doc or
just for picking a creature. Nothing in them is needed at runtime.

## Preview files

`gif/<creature>.gif` is a 32-frame reel of that creature -- idle twice,
move twice, then attack, hit and death with a beat held on each last frame -- on a
**transparent background** at 4x nearest-neighbour (128x128 and 192x192).

Frame 0 of each reel is that creature's densest idle frame, not idle frame 0. Sites
and file browsers show the first frame as the poster, so it has to be the fullest
pose rather than whichever frame the animation happens to start on.

`gif/states/<creature>_<state>.gif` is one state on its own, 4x like the reels. Every
frame runs 100ms, except that in the one-shot states -- attack, hit and death -- the last
frame is held for 800ms so the GIF can loop and still read as a one-shot; in-engine they
play once.

`catalog/CATALOG.gif` is all 53 creatures animating at once, 864x576,
20 frames, 2.0s. Each cell is phase-rotated so its densest move
frame lands on frame 0.

---

## Where the pack has to go -- read this once

The download unpacks to a single folder called **`BESTIARY`** -- that is measured from the zip itself, not assumed. Drag that folder in exactly as it comes out, without renaming it.

**The folder's name is load-bearing in both engines.** Godot resource files can only
hold absolute `res://` paths, so all 1,166 texture references across the 53
`.tres` files are spelled `res://BESTIARY/frames/...`. Put the pack somewhere else and
every one of them misses: the SpriteFrames still loads, every frame texture comes
back null, and you get an invisible sprite plus one *Resource file not found* error
per frame. Unity is the same story with a friendlier failure -- the importer looks
for `Assets/BESTIARY` and reports that it found nothing.

| Engine | Put the folder here | So that this exists |
|---|---|---|
| Godot 4 | project root | `res://BESTIARY/creatures.json` |
| Unity | `Assets/` | `Assets/BESTIARY/creatures.json` |

If you must keep it elsewhere in Godot, the `.tres` files are plain text: a
find-and-replace of `res://BESTIARY/` across `engine/godot/sprite_frames/*.tres` plus a
matching change to `Bestiary.PACK_ROOT` moves the whole pack. Unity needs nothing --
the importer searches for the folder.

---

## Godot 4

**1.** Put the `BESTIARY` folder in your project root so the path is `res://BESTIARY/`
(see above -- the name matters).
**2.** Copy `engine/godot/Bestiary.gd` anywhere in the project.

`engine/godot/sprite_frames/<creature>.tres` is a ready-made **SpriteFrames** for each
creature, with all five animations, `speed = 10` and the right `loop` flag on each.
They reference the real frame PNGs under `res://BESTIARY/frames/`.

```gdscript
# AnimatedSprite2D with Bestiary.gd attached, creature_id = "slime_green"
@onready var enemy: Bestiary = $Enemy

func _ready() -> void:
    enemy.died.connect(_on_enemy_died)
    enemy.move()

func take_hit(dmg: int) -> void:
    hp -= dmg
    if hp <= 0:
        enemy.die()        # holds the last death frame, emits died
    else:
        enemy.hurt()       # plays once, then falls back to idle
```

Without the helper script it is just a SpriteFrames:

```gdscript
var spr := AnimatedSprite2D.new()
spr.sprite_frames = load("res://BESTIARY/engine/godot/sprite_frames/slime_green.tres")
spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
spr.play(&"idle")
```

There is deliberately no animation called `default`; the five are `idle`, `move`,
`attack`, `hit`, `death`.

`Bestiary.all_ids()` and `Bestiary.ids_in_family("Slimes")` read
`creatures.json`, so you can build a spawn table without hardcoding 53 names.

### Godot import settings

Set **Project Settings > Rendering > Textures > Canvas Textures > Default Texture
Filter** to **Nearest** once and every 2D node in the project is correct. `Bestiary.gd`
also forces `texture_filter` to nearest on itself, so it stays crisp either way --
untick `force_nearest_filter` if you would rather it inherit from its parent.

Per texture, in the Import dock: **Filter off**, **Mipmaps off**, **Compress Mode:
Lossless**. VRAM compression puts visible blocking on hard pixel edges.

---

## Unity 2021.3+

**1.** Drag the `BESTIARY` folder from the download into `Assets/`, so the pack sits
at `Assets/BESTIARY/`. Both scripts ride along inside it and need no moving:

| File | Where it lands | Why there |
|---|---|---|
| `engine/unity/Editor/BestiaryImporter.cs` | `Assets/BESTIARY/engine/unity/Editor/` | it is an editor script -- Unity keeps any folder named `Editor` out of player builds, so its `using UnityEditor;` can never break your build. It is wrapped in `#if UNITY_EDITOR` as well, belt and braces |
| `engine/unity/BestiaryAnimator.cs` | `Assets/BESTIARY/engine/unity/` | runtime script, no editor references, compiles into your player |

**2.** Run **Tools > BESTIARY > Import sheets (slice + Point + no compression)**.

The importer does not assume where you put the pack. It looks for `Assets/BESTIARY`,
then `Assets/Resources/BESTIARY`, then any folder named `BESTIARY` under `Assets/` that
holds both `sheets/` and `creatures.json`, and logs the one it used -- so step 1 has
no wrong answer and there are no constants to edit. It then reads each PNG's real
width and height out of the file header, slices it into `width / height` square cells
named `<creature>_<state>_00`, and sets:

| Setting | Value | Why |
|---|---|---|
| Filter Mode | **Point** | nearest neighbour; bilinear smears a 32px sprite |
| Mip Maps | **off** | mips are wrong for 2D sprites and blur at distance |
| Compression | **Uncompressed / RGBA32** | DXT and ASTC block artefacts sit right on hard pixel edges |
| Mesh Type | Full Rect | tight meshes crop transparent edges and shift frames relative to each other |
| Alpha Is Transparency | on | the frames are binary alpha |
| Wrap Mode | Clamp | |
| Pixels Per Unit | the cell size | one cell is one world unit |
| Pivot | Center | change `spriteAlignment` in the importer for bottom-pivot enemies |

That one menu item does both `sheets/` and `sheets_2x/`, so the 2x strips arrive sliced and
Point-filtered as well and you can swap to them for a chunkier look without a second pass.

Re-running the menu item is safe: sprite GUIDs are reused by name, so references from
scenes and prefabs survive.

There is a third menu item, **Tools > BESTIARY > Import loose frames (Point + no
compression)**, for anyone who would rather use `frames/` than the strips. It applies the
same texture settings to the 1,166 loose PNGs and slices nothing, since they are already
one frame per file.

**3.** Add `BestiaryAnimator` to a GameObject with a `SpriteRenderer`, type a
`creatureId` from `creatures.json` into the inspector (`slime_green`, say), select the
GameObject and run **Tools > BESTIARY > Fill selected BestiaryAnimator clips from the
pack**. That fills all five `clips` from the sliced sheets, with `loop` already ticked
on idle and move.

The sprite references are serialised into your scene or prefab, so this survives into
a build with nothing under `Resources/`. Then it is just:

```csharp
var anim = GetComponent<BestiaryAnimator>();
anim.Died += () => Destroy(gameObject, 1f);
anim.Move();

// later
anim.Hurt();     // plays once at 10 fps, then back to idle
anim.Die();      // plays once and holds the last frame
```

### Loading by id at runtime instead

`LoadFromResources()` builds the same clips by name with no editor step:

```csharp
var anim = gameObject.AddComponent<BestiaryAnimator>();
anim.creatureId = "slime_green";
if (anim.LoadFromResources())    // false + an explanatory warning if it finds nothing
    anim.Move();
```

`Resources.LoadAll` can only see assets under `Assets/Resources/`, so this one path
needs the pack at **`Assets/Resources/BESTIARY/`** rather than `Assets/BESTIARY/` -- the
importer finds it in either place, so nothing else changes. Be deliberate about it:
everything under `Resources/` is force-built into your player, and that is
1,166 frame PNGs plus 265 sheets and 265 more at 2x. Moving just
`sheets/` under `Assets/Resources/BESTIARY/sheets/` is usually the better trade.

Third option, no scripts at all: drag the sliced sprites into the `clips` list in the
inspector by hand -- one `Clip` per state, `loop` ticked for idle and move.

---

## Any other engine

`creatures.json` has, for every creature: `family`, `cell_px`, `fps`, and for each of
the five states a `frames` count, a `sheet` path, a `frames_dir` path and a `loop`
flag. The sheets are a single row of square cells read left to right from cell 0.
Advance one cell every `1 / fps` seconds; at the end, restart if `loop`, otherwise
hold the last cell.
