# Assets

Drop downloaded asset packs here. Keep each pack's original licence file
alongside it, and add a line to `CREDITS.md` for every pack you use.

## Where things go

| Folder | Contents |
|---|---|
| `sprites/player/` | The cat: sprite sheets for idle, run, jump, fall, wall slide, climb, scratch, spin, pounce, dig, hurt, death |
| `sprites/enemies/` | Bug, Rat, Bird, Spider (one subfolder each, e.g. `enemies/rat/`) |
| `sprites/bosses/` | Only if a pack has dedicated boss art. Otherwise bosses reuse the enemy sprite, scaled up |
| `sprites/collectibles/` | Heart and energy upgrades, food pickups, ability pickups |
| `sprites/props/` | Breakables, checkpoints, soft (diggable) blocks, moving crusher block, doors |
| `tilesets/<zone>/` | Terrain tiles for each zone. `tilesets/common/` is for tiles shared between zones |
| `backgrounds/` | Parallax background layers (subfolder per zone) |
| `ui/` | Heart and energy HUD icons, menu frames, controller button prompts |
| `fonts/` | Pixel fonts |
| `audio/music/` | One track per zone, plus menu and boss music |
| `audio/sfx/` | Jump, scratch, hit, hurt, pickup, dig, and other sound effects |

Unzip packs into the matching folder rather than committing the .zip.
If a pack covers several categories, put it in its main folder and say so
in `CREDITS.md`; it will be sorted when it's wired into the game.

## Art spec

- Pixel art, ideally **16×16 tiles** with a **32×32 cat**, so packs mix cleanly.
- PNG with transparency.
- The game renders at 320×180 or 640×360 and scales up with nearest-neighbour filtering.

## Recommended sources

Check each pack's licence before using it. Prefer CC0 or "free for
commercial use", and avoid packs that forbid modification.

**Cat (player)**
- [Cat Player Asset, jumpbutton](https://jumpbutton.itch.io/cat-player-asset): free (pay what you want), 32×32, 18 animations including against-wall and spinning. Credit required for commercial use.
- [Cat 2D Pixel Art, xzany](https://xzany.itch.io/cat-2d-pixel-art): free version, or $3 for the full pack, 32×32, includes wall slide, climb, and two attacks. Credit appreciated.
- [Black Cat Sprites, carysaurus](https://carysaurus.itch.io/black-cat-sprites): free version has only run and idle; the $2 paid pack adds pounce, attack, hurt, and more. Credit required.

**General sources**
- [Kenney.nl](https://kenney.nl/assets): everything is CC0. Good for UI, prompts, and placeholder tiles.
- [OpenGameArt.org](https://opengameart.org): filter by CC0 or CC-BY licences.
- [itch.io game assets, pixel-art tag](https://itch.io/game-assets/free/tag-pixel-art): the largest selection; licences vary.
- [Sewerage Platformer Tileset](https://free-game-assets.itch.io/sewerage-platformer-tileset-pixel-art) for the Sewer zone.
- [Freesound.org](https://freesound.org) for sound effects (filter by CC0).
