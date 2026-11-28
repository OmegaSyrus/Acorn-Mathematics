# Art grid plan: one pixel grid, higher detail (2026-11-24)

Terrence: "we need to generate high quality replacements for as many assets as we
can ... we need to make the pixel resolutions and grid align."

The full list of every art file, its size, how it is drawn and what happens to it
is in [art-inventory.csv](art-inventory.csv) (140 files).

## What was wrong (measured, not guessed)

Stills were rendered at the Galaxy Tab A7 Lite's real screen size (1340x800).

1. **Uneven pixels on the tablet.** The game is laid out in 540-unit-tall design
   space and the tablet is 800 pixels tall, so 1 unit = 1.48 screen pixels. With
   plain nearest sampling, each art pixel came out either 1 or 2 screen pixels
   wide at random, so outlines wobbled and the background's big pixels were 4 or
   5 screen pixels wide in a staircase. This hit every piece of art.
2. **Three pixel sizes on one screen.** Characters, stones and icons are 1 art
   pixel = 1 unit, but every background was 320x180 stretched 3x, so behind a
   finely drawn monster sat a wall of 3-unit blocks.
3. **Small things drawn scaled.** Gems, currency icons, hearts, the ball, pegs
   and bumpers are stretched by odd amounts (x1.15, x1.2, by radius), so their
   pixels are off the grid too.
4. **Level crossings at half size.** Every crossing after Lava 1 draws the
   world at 0.5 (Lava 1 at 0.8), smoothed, so 1-unit sprites lose half their
   pixels there.

## The target grid

| What | Art pixel = | Canvas | Status |
|---|---|---|---|
| Characters, monsters, minibosses, bosses, limbs | 1 unit | as today (hero 93x115 ... boss 400x400) | keep, already 1:1 |
| Path stones, chests, props | 1 unit | as today (stones 136x76) | 12 redrawn (P2); crystal and space kept |
| Backgrounds: fight rooms, treasure rooms, crossing backdrops, menu | **2 units** (was 3) | **480x270** (was 320x180) | done (menu oak swapped 2026-11-28) |
| Icons, hearts, ball, pegs, bumpers, shields | 1 unit, drawn 1:1 | one file per drawn size | done (P3), bumper still scaled |
| Half-size crossing sprites | 1 unit at half size | half of each crossing sprite, in art/<world>/half/ | done |

Why 2 units for backgrounds and not 1: PixelLab's best model (Pro) tops out at
688x384 for a 16:9 picture, so a native 960x540 scene is not possible in one
piece. 480x270 is the largest size that divides the frame exactly (2 units per
pixel), and it has 2.25 times the pixels of the old backgrounds. A bonus: on a
half-size crossing the 2x backdrop draws at exactly 1 unit, the same grid as the
sprites.

And for every screen: a **sharp-pixels shader** (game/ui/sharp_pixels.gdshader)
on every canvas item draws each art pixel as an even square at any screen scale,
blending only the one screen pixel where two art pixels meet. Smaller-than-1:1
drawing (the half-size crossing) falls back to the smooth look it had.

## Priority order (most visible first)

| # | Work | Files | PixelLab cost | State |
|---|---|---|---|---|
| P0 | Sharp-pixels shader, project filter to linear | code | 0 | done |
| P1 | All 16 backgrounds remade at 480x270 (Pro, current art as the layout reference); crossing backdrops made seamless | 16 | about 450 plan generations | done, in review |
| P2 | Path stones (22): richer detail, same canvases | 22 | Pro 10 a call, 4 candidates (about 220) | next |
| P3 | Icons and board pieces redrawn at their drawn size, drawn 1:1 | 17 | about 150 | done: currency 40 + 24, pegs, ball, shield, chests, markers; bumper left |
| P4 | Half-size crossing: small 1-unit twins in art/<world>/half/ for 12 heroes, 17 crossing monsters, 24 stones/ceilings/chests (game/ui/half_art.gd) | 53 | about 290 | done (Terrence picked it 2026-11-24) |
| P5 | Selective character upgrades (lowest detail first: wispling, star squirrel, mimic, Blorp) | ~6 | about 60 | later |
| - | Ellwynn | 5 | - | locked, not touched |
| - | Unused files (old slime frames, Blorp alt) | 7 | - | can be deleted |

All PixelLab work uses the subscription's plan generations (10,000 a month on
Tier 3), no paid credits. RetroDiffusion is not used.

## Tools

- `/mnt/project-files/sum-dungeon/art-hq/tools/pl_pro.py`: PixelLab Pro text to
  image with labelled references.
- `pl_seam.py`: makes a backdrop tile loop (roll by half, inpaint the middle,
  feather and snap to the tile's own colours).
- `pl_fix.py`: inpaint one box and keep the rest pixel-exact.
- Raw takes and contact sheets: `/mnt/project-files/sum-dungeon/art-hq/`.
