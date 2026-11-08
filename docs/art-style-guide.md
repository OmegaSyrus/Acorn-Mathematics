# Acorn Mathematics art style guide (all worlds)

Written 2026-11-06 for the new-world art pass. It matches what is already in the
game (Lava Caves, boss art, heroes). Status: proposed, waiting on Terrence's yes.

## 1. The grid (same in every world)

The game frame is 960 x 540 units. There are only two grids:

| What | Grid | Sizes in the game today |
|---|---|---|
| Characters, monsters, minibosses, bosses, props, path stones, chests, icons | **1 art pixel = 1 unit**, never scaled (Look.CHAR_PX = 1) | hero 93x115, Surtling 85x120, Blorp 192 cell (~160 tall), Craggy 176x175, Surtling Chief 168x172, mimic 118x113, chest 96x96, rock 136x76, gem/markers 40x40, boss skull 400x400, bone arm 320x240, board 500x500 |
| Backgrounds | **1 art pixel = 3 units** | fight room 320x180, treasure room 320x180, crossing strip 1920x180 |

The half-size crossing view (every level after Lava 1, Terrence's choice) shrinks the
whole crossing at draw time. Art is still made on the 1-unit grid above. Fights, duels
and the boss stay 1:1.

Size bands for new characters, measured as the visible body height:
- small monster 90 to 120, big monster 150 to 180, miniboss 170 to 190
- boss: a 400x400 main piece plus one 320x240 limb or weapon piece, laid out like the
  Skeleton Dragon (big piece top right past the board, limb gripping the board's right wall)

## 2. Look rules (from v0.19 and the Lava set)

- One palette per world of 24 colors, plus the shared UI 8. Generation passes the
  world palette as PixelLab's color image so colors hold.
- Characters: single dark outline, medium shading, highly detailed, side view, facing
  left (toward the hero). Tiles and backgrounds: no outline.
- Light from the top left. Flat bands, no noise dither.
- Monsters are real monsters and may be scary. Bosses are a bit spooky.
- Backgrounds stay darker and lower in contrast than the dice and stones, so the
  numbers always win.
- Shared across worlds and reused for free: dice, pegs, bumper, hearts, ball, shields,
  markers, chest and mimic (unless Terrence wants a chest per world).

## 3. Making art

- PixelLab pixflux (REST v1), subscription generations only. Two takes per asset,
  seeds written down. Free hand edits after: flood-fill the background away, spur
  cleanup, uniform 1 px outline, recolor by brightness.
- Each world's art waits for Terrence's yes on its list. Files go to
  `sum-dungeon/art-<world>/` with a README of prompts, sizes and seeds, and `raw/`
  for every take.
- PixelLab init images do not add detail to old art (the chunky pixels come back).

## 4. What each world needs

Same kit in every world. About 30 generations per world at 2 takes.

| Piece | Size | Lava (done) | Crystal Mines | The Bog | Mushroom Forest | Space |
|---|---|---|---|---|---|---|
| Crossing strip | 1920x180 (3x) | lava cave | mine tunnel, timber props, crystal veins | fen at dusk, black water, mist | greenwood, dappled light | indigo sky, Yggdrasil branches |
| Path stones x3 | 136x76 | basalt rocks | rail stops on minecart track | tussock, sunken log, peat stone | mushroom caps | star platforms |
| Small monster | ~90-120 | Surtling | knocker | wispling, nixie | pixie, hobgoblin with acorn shield | Ratatoskr squirrel, moon hobgoblin |
| Big monster | ~150-180 | Blorp, Craggy | Gem Dwarf, Svartalf lantern-bearer | bog-draugr, Tiddy Mun | boggart | Fenrir's pup |
| Miniboss | ~170-190 | Surtling Chief | Svartalf Lantern Lord | Wisp King and Queen (two) | the Hedley Kow | Ratatoskr |
| Boss main + limb | 400x400 + 320x240 | Skeleton Dragon skull + bone arm | Knocker King + great hammer | Jenny Greenteeth + long weedy arm | the Green Man's face in an oak + branch arm | Fenrir + paw |
| Fight room | 320x180 (3x) | lava cave | mine gallery | fen pool | oak glade | moonlit branch |
| Treasure room | 320x180 (3x) | gold hoard | crystal hoard | bog finds | leaf hoard | star hoard |
| Currency icon | 40x40 | gem | crystal | brooch (plan says code drawn) | mushroom or leaf | feather |
| Boss board | 500x500 | crag board | recolor of the crag board (free) | recolor | recolor | recolor |

## 5. World palettes

Each world gets a 24-color `palette-<world>-24.hex` in its folder, from v0.19's
palette words:
- Lava Caves: basalt plum, soot brown, ember glow, gold (art-starters/palette-lava-caves-24.hex)
- Crystal Mines: cool slate, timber, lantern amber, crystal violet (art-crystal-mines/palette-crystal-mines-24.hex, proposed)
- The Bog: peat brown, duckweed green, black water, mist blue-grey
- Mushroom Forest: moss green, oak bark, dappled sun, dusty-rose caps
- Space: deep indigo, star gold, moon cream
