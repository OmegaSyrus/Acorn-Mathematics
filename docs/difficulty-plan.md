# Lava Caves difficulty plan: tiers by age, more dice, more stones

Status: plan for review (2026-11-05). Nothing below is built yet except the store fix
noted at the end. Asked for by Terrence after the 0.11.0 tablet test: the current Acorn
crossing is "a viable first pass" but too easy for his 4.5 year old, so the lava needs
harder levels, more dice and more stones, with tiers named by age (Acorn 1, Acorn 2...).

The Sum Dungeon flow stays as it is: map, crossing (roll, pick the safe stone, walk,
chests and fights on the way, a wrong stone sinks and the crossing starts again), exit
door, boss later. Only the math layer, the number of stones and the stone layout change.
Same art, same bosses, same fail rule.

## 1. The tier ladder

Four bands named by age, three levels in each. The band is the old grade name; the level
is the step inside it. A parent picks the band by age; the child climbs the levels.

| Tier | Age | Dice | Question | Answers (stones) | Crossing |
|---|---|---|---|---|---|
| **Acorn 1** (today's Acorn) | 4 | 2 dice | a + b or a − b | 1 to 5 | 40 spaces |
| **Acorn 2** | 4 to 5 | 2 dice | a + b up to 10, a − b | 1 to 10 | 60 spaces |
| **Acorn 3** | 5 | 2 dice | a + b, a − b, plus doubles bonus | 1 to 12 | 80 spaces |
| **Sprout 1** | 5 to 6 | 3 dice | a + b + c | 3 to 12 (stones 1 to 12) | 80 |
| **Sprout 2** | 5 to 6 | 3 dice | a + b − c (one red die) | 1 to 12 | 80 |
| **Sprout 3** | 6 | 3 dice | any mix of + and − | 1 to 15 | 100 |
| **Sapling 1** | 6 to 7 | 4 dice | a + b + c + d | 4 to 20 (stones 1 to 20) | 120 |
| **Sapling 2** | 6 to 7 | 3 or 4 dice | mixed, one or two red dice | 1 to 20 | 120 |
| **Sapling 3** | 7 | 2 dice | missing die: the stone number is given, one die is hidden, pick its face | 1 to 6 | 60 |
| **Oak 1 to 3** | 7 to 8 | 2 to 4 dice | doubles and near doubles, make ten, take away across ten | to 20 | later |

Why this order:

- **Acorn 2 is the step for Terrence's son.** Today's Acorn caps every answer at 5, so
  the dice are always small and only five stones are on screen: a 1 in 5 guess, and
  most sums can be read off by subitizing. Acorn 2 keeps two dice but lets them be much
  bigger (sums to 10 here, any two dice up to 12 at Acorn 3) and shows 10 stones, so counting on is
  needed and guessing drops to 1 in 10.
- **Sprout adds a third die** before bigger numbers: three small dice exercise adding
  in steps (a + b, then + c) with sums that stay near 12.
- **Red dice stay "take away"** in every tier (the store already keeps the take-away die
  red in every skin).
- **Sapling 3 (missing die) is placed after the 20s**, as the earlier review found a
  missing addend is harder than take-away for this age.
- Oak is a placeholder band; it gets detail after Sapling has been played.

Each level keeps the no gentle failing rule: one wrong stone sinks and the crossing
restarts. Crossings get longer with bigger moves so a run stays about 12 to 14 moves
(about 3 to 5 minutes) at every tier: length is about 13 times the average answer.

### Answer draws

The generator keeps today's contract: **the answer is drawn first, then the dice**, so
every stone distance is about as likely and the child can't learn that "it's usually a
small one". New rules per tier:

- `n_dice` 2, 3 or 4; `signs` lists which dice may be red (`"+"`, `"-"`, `"±"`).
- `min_answer`, `max_answer` and `die_max` (always 6: dice only, d6 pips).
- Draw the answer in range, then draw dice one at a time so the rest can still reach the
  answer (each die in `max(1, rest - 6 × dice left)` .. `min(6, rest - dice left)` for
  adds; take-away draws the red die first, then the adds). Every draw is part of the spec
  so the C++ port and the Python reference roll the same dice.
- Doubles bonus (Acorn 3): when both dice match, the walk shows a little cheer; nothing
  changes in the math. Optional, cut if it slows the turn.

## 2. More stones on screen: zoom first, scroll when the numbers get big

Today: stones are 120 units apart, the dragon stands at screen x 220, and the next five
stones (x 340 to 820) fit inside what a 4:3 tablet shows (x 120 to 840). That is why the
answers stop at 5.

The plan uses **both** asks, in this order:

1. **Zoom out up to 10 stones (Acorn 2).** The world is drawn smaller: stone step 66,
   rock and characters drawn at 0.55, and the dragon stands at screen x 150 instead of
   220. Ten stones then span x 216 to 810, inside the 4:3 area. A rock is about 64 units wide, about 0.64 inch on the 10 inch tablet (the
   1 inch = 100 units rule from the Go button work), still above the usual 0.4 inch
   touch minimum, and the two step pick with the Go button already protects against a
   slipped finger. The strip art is the same image drawn at the zoom scale, so no new
   art.
   - One thing to settle: the one pixel grid rule says characters are never scaled. A
     zoomed camera scales the whole world, characters included, by the same factor, so
     they stay on one grid with each other. If Terrence wants pixels kept exact, the
     fallback is integer zoom only (1x for up to 5 stones, 0.5x for up to 10).
2. **Scroll for 11 and up (Acorn 3 onward).** Zoom stays at the 10 stone level and the
   stones past the edge are reached by dragging the lava sideways with a finger (the same
   flick the dice tray uses, so it is learned already). After a stone is picked and Go
   is pressed, the camera follows the walk as it does now. Helpers so a child can find
   stone 12:
   - **Landmark stones** at 5, 10, 15 and 20: a little bigger, with a gold rim, so the
     child can count on from 10 instead of from 1 (number line landmarks).
   - The numbers on the stones keep their meaning: **the number on a stone is how far
     away it is**, so the answer is the stone with that number.
   - A soft arrow at the right edge while more stones are off screen; it fades once the
     child drags.
   - The dragon never walks off the left edge: the drag is clamped so the dragon and at
     least stone 1 stay in view.
3. Stone count shown = `min(max_answer, spaces left)`, as today.

The dice tray (390 units wide today) holds two 96 px dice. Three and four dice use 72 px
dice in one row (die, sign, die, sign, die, =) and the sum numeral under each die stays.
The talk box keeps "Which stone is safe?".

## 3. Content and save changes

- `content/grades.json`: each tier is an entry with `band` (acorn, sprout, sapling,
  oak), `level` (1 to 3), `age` (for the parent), `name` ("Acorn 2") and a `move` block:
  `{n_dice, signs, min_answer, max_answer, die_max, stones_on_screen, zoom}`.
- Tier ids: band × 10 + level (Acorn 1 = 11, Acorn 2 = 12, Sprout 1 = 21...). The save
  stores grade ids in `marks` and `run`, so loading a save maps the old ids
  (1 → 11 Acorn 1, 2 → 21 Sprout 1). One small migration in `SaveData.from_text`.
- `content/areas/lava_scroll.json`: `length` and `spaces` per band
  (`"by_band": {"acorn": {...}, "sprout": {...}}`), so longer crossings get their own
  chest and monster places spread through the run. Chests per crossing stay 5 so a run
  banks the same gems (the shop's 40 gem slime price holds at every tier), unless we
  decide harder tiers should pay more (see open questions).
- Map: the grade buttons become a band row (Acorn, Sprout, Sapling) and the levels 1 to 3
  of the chosen band, each with its cleared mark. Default: every level open so a parent
  can start their child at the right one; a level's mark shows when it is beaten.

## 4. Code that changes

| File | Change |
|---|---|
| `content/grades.json` | tier table above |
| `logic/core/grades.gd` | tier ids and names, band of a tier |
| `logic/core/move_gen.gd` | N dice, signs per die, min/max answer, answer first |
| `tools/ref/move_gen.py`, `tools/ref/make_vectors.py` | the Python reference and new vectors |
| `spec/logic-spec.md` section 6 | spec v1.2 for the N dice draw |
| `logic/path/scroll_run.gd` (+ `tools/ref/scroll_run.py`) | length and spaces by band |
| `logic/core/save_data.gd` | old grade ids mapped to tier ids |
| `logic/fight/attack_gen.gd` | fight math by band (Acorn keeps dots to numeral; Sprout fights add two dice; Sapling three) instead of only `ACORN` vs the rest |
| `game/scroll_screen.gd` | zoom, stone step per tier, drag to scroll, landmark stones, edge arrow, 3 and 4 dice in the tray |
| `game/ui/choice_widget.gd` | targets that move with the drag; ignore a drag as a pick |
| `game/ui/die_view.gd`, `dice_draw.gd`, `dice_skins.gd` | 72 px dice for 3 and 4 dice |
| `game/map_screen.gd` | band and level picker |
| `content/store.json` | open `sprout_stars` when Sprout ships (`"open": true`, no code) |
| `tests/` | vectors for every tier, fuzz (every answer reachable, dice all 1 to 6, answer equally likely), save migration, a perfect bot clears every tier, run length 12 to 14 moves |
| `tools/demo/` | demo bot can pick off screen stones (drag, then tap) |

## 5. Milestones

Each milestone ends with tests green, an APK on the project folder, and a short video,
as for the earlier builds. Nothing goes on the tablet without Terrence.

1. **Tier data and the N dice generator** (logic only): grades.json tiers, move_gen,
   Python reference, spec v1.2, vectors, save migration. No screen changes; Acorn 1 plays
   exactly as today (its vectors must not change).
2. **Acorn 2 on the tablet**: zoom to 10 stones, 60 space crossing, map shows Acorn 1
   and Acorn 2. This is the build for Terrence's son, so it comes first.
3. **Acorn 3**: drag to scroll, landmark stones, answers to 12, 80 spaces.
4. **Map band and level picker** for all tiers that exist; marks per tier.
5. **Sprout 1 to 3**: three dice in the tray, red die mixes, fights by band, opens Sprout
   stars in the shop (Leo and Sir Tam become buyable).
6. **Sapling 1 to 3**: four dice, answers to 20, missing die; opens Sapling stars.
7. Oak, after Sapling has been played.

## 6. Open questions for Terrence

- Pixel grid: is the zoomed out crossing OK (whole world scaled the same), or only
  whole number zoom?
- Should a level unlock only after the one before is cleared, or all open (the plan's
  default)?
- Should harder tiers pay more gems per chest, which would make the slime cheaper there?
  Default: same 5 chests of 2 to 4 gems at every tier.
- Acorn 3 doubles cheer: keep or cut.

## Store check (2026-11-05)

On branch `claude/project-thread-ielg89` (PR #12, which holds the shop from PR #11):
the headless suite runs 70 tests and all pass, including the 10 store tests (catalog,
only the slime buyable at 40 gems, about three crossings to afford it, buy and equip,
locked currencies, old saves, red take-away die in every skin).

One bug found in the game layer and fixed here: chest gems went into the save when the
chest opened on screen, but the run (with that chest marked opened) was only written at
the end of the turn. Leaving through the menu during the walk and pressing Go on the map
replayed the same move and opened the same chest again, so gems could be doubled. The
walk's gems and the run are now written together before the walk plays, and the counter
still climbs as each chest opens (`game/scroll_screen.gd`, `gems_unshown`).
