# BESTIARY - Animated Pixel Enemy Sprites
**26 creature designs · 53 palette variants · 265 animation clips · 5 states each · v1.1**

26 creature designs shipped as 53 palette variants, each animated across five states --
idle, move, attack, hit and death. Every clip ships three ways: loose PNG frames,
horizontal sprite strips, and the same strips at an exact 2x.

---

## Drop it straight into your engine - `engine/`

**New in v1.1.** There is nothing to slice and nothing to hand-configure.

| Engine | What ships | Path |
|---|---|---|
| **Godot 4** | 53 ready-made `SpriteFrames`, one per creature -- all five animations, `speed = 10`, `loop` true on idle and move, false on attack / hit / death | `engine/godot/sprite_frames/<creature>.tres` |
| **Godot 4** | `Bestiary` node script: `move()`, `hurt()`, `die()`, a `died` signal, and `all_ids()` / `ids_in_family()` read from `creatures.json` | `engine/godot/Bestiary.gd` |
| **Unity 2021.3+** | editor importer, menu **Tools > BESTIARY** -- slices every sheet into square cells, sets Point filter, mipmaps off, uncompressed RGBA, Full Rect | `engine/unity/Editor/BestiaryImporter.cs` |
| **Unity 2021.3+** | runtime player: `Move()`, `Hurt()`, `Die()`, a `Died` event, 10 fps and the loop flags baked in as defaults | `engine/unity/BestiaryAnimator.cs` |

57 files under `engine/` in total: 53 `.tres`, one `.gd`, two `.cs`, and `USAGE.md`.

The Godot resources point at the real PNGs in `frames/` by absolute `res://BESTIARY/...`
path -- **all 1,166 references, every one of them resolving to a file in this download**.
Godot cannot store those relatively, so the folder has to keep the name `BESTIARY` and sit
at your project root. Unity does not care where you put it; the importer goes and finds it.

**Read `engine/USAGE.md` before you import.** It has the install path for both engines, the
texture import settings that actually matter at this size, and the find-and-replace that
moves the pack if `res://BESTIARY/` does not suit your project layout.

---

## Contents

| | |
|---|---|
| States | idle (4) · move (6) · **attack (4)** · hit (2) · death (6) |
| Animation clips | 265 |
| PNG frames | 1,166 |
| Sprite PNGs in total | 1,696 -- 1,166 frames + 265 sheets + 265 sheets at 2x |
| Families | Slimes 8 · Flyers 10 · Crawlers 14 · Undead 12 · Aberrations 9 |
| Size | 45 creatures at 32x32, 8 at 48x48, transparent background |
| Rate | 10 fps |

Every one of the 53 creatures has the same five clips at the same frame counts, so a spawn
table never has to special-case anything.

| Folder | What it is |
|---|---|
| `frames/<creature>/<state>/` | the 1,166 loose PNGs, one per frame, zero-padded in play order |
| `sheets/` | 265 horizontal strips, one per creature per state |
| `sheets_2x/` | the same 265 strips at an exact 2x nearest-neighbour scale, pixel for pixel |
| `gif/` | 53 per-creature preview reels, plus `gif/states/` with 265 single-state GIFs |
| `catalog/` | `CATALOG.gif` -- all 53 creatures animating at once -- and 5 per-family contact sheets |
| `engine/` | Godot 4 and Unity integration, plus `USAGE.md` |
| `creatures.json` | the manifest: family, cell size and fps per creature, and per state the frame count, sheet path, frames directory and loop flag |

`gif/` and `catalog/` are preview material -- for picking a creature without opening a
sheet, or for your own store page and design docs. Nothing in them is needed at runtime.

## What the count means

There are **26 distinct creature designs**. 25 of them ship in two or more palette
variants -- a green slime and a blood slime, an ember skull and a void skull -- for 53
sprite ids in total; `cube_gel` is the only design that ships on its own. The variants
differ in palette and in small geometry (a crest, a cracked shell, a
missing jaw), but a variant pair is still recognisably the same creature. If you need
53 visually unrelated monsters, this is not that pack; if you need a coherent
bestiary you can recolour by tier, it is.

## Animation

`creatures.json` gives, per creature, every state with its frame count, sheet path and
frames directory, and a `loop` flag: **idle and move loop, attack / hit / death play once**.
Intended rate is 10 fps.

Sheets are horizontal strips, frames left to right, one strip per creature per state. Every
strip is a single row of square cells, so **cell = image height** and **frames = width /
height** -- that is how the Unity importer sizes them, and it is how you should too rather
than hardcoding 32. The same frames are also written individually under
`frames/<creature>/<state>/`.

## Rules the whole pack keeps

Binary alpha -- every pixel fully opaque or fully transparent, checked across all 1,166
frames, so these colour-key cleanly and stay crisp at integer scale. **Nearest-neighbour
only.** One light direction. Every sprite is drawn to sit legibly on a dark dungeon tile,
not on white.

## Changelog

**v1.1** -- integration and previews. No art changed: all 1,696 sprite PNGs and
`creatures.json` are byte-for-byte identical to v1.0.

* `engine/godot/sprite_frames/*.tres` -- 53 Godot 4 `SpriteFrames` resources, one per
  creature, each carrying all five animations at `speed = 10` with the loop flag already
  set per state. Their 1,166 texture references are absolute `res://BESTIARY/frames/...`
  paths and every one resolves to a shipped PNG.
* `engine/godot/Bestiary.gd` -- an `AnimatedSprite2D` subclass that plays one creature:
  `idle()` / `move()` / `attack()` / `hurt()` / `die()`, `state_finished` and `died`
  signals, optional auto-return to idle, and static `all_ids()` / `ids_in_family()` that
  read `creatures.json` so you never hardcode 53 names.
* `engine/unity/Editor/BestiaryImporter.cs` -- editor-only, under an `Editor/` folder and
  wrapped in `#if UNITY_EDITOR`, so it can never break a player build. Three menu items
  under **Tools > BESTIARY**: slice `sheets/` and `sheets_2x/`, configure the loose
  `frames/`, and fill a selected animator's clips. Cell size comes from each PNG's own
  IHDR header, not from a constant, and sprite GUIDs are reused by name so scene and
  prefab references survive a re-import.
* `engine/unity/BestiaryAnimator.cs` -- runtime player with `Move()` / `Hurt()` / `Die()`,
  a `Died` event, and `LoadFromResources()` for the no-editor-step path.
* `engine/USAGE.md` -- where the folder has to go in each engine, and the texture import
  settings that matter.
* `gif/` -- 53 per-creature reels, 32 frames each on a transparent background at 4x
  (128x128, or 192x192 for the 48px creatures), plus `gif/states/` with 265 single-state
  GIFs.
* `catalog/` -- `CATALOG.gif`, all 53 creatures animating at once at 864x576, and five
  per-family contact sheets.

**v1.0** -- 53 creatures, 265 clips, 1,166 frames, sheets and 2x sheets.

## How this was made

Every pixel is placed by geometric rule at **native resolution** -- nothing was rendered
large and downsampled, which always shows at this size.

**No generative AI models. No training data. No stock art. No hand-drawn source.**

## License

Commercial use included, no credit required, no resale of the raw files. The `engine/`
scripts are MIT, so you can paste them into a commercial codebase. See `LICENSE.txt`.
