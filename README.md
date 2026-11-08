# Acorn Mathematics: Godot graybox (Phase 1, the path)

Prototype only, never shipped (plan 0.18, section 15). Placeholder shapes, no art.
One area, Lava Caves 1: 10 tasks (6 path steps, 2 doors, 2 chests) at Acorn or Sprout,
with the real fail rule.

## The lava crossing (default area)

`lava_scroll` is the first round at Acorn: a run of 9 guesses across rocks in the lava,
left to right. The crossing has as many rocks as the 9 answers add up to (Terrence,
2026-11-07), so each run is drawn first and its length follows; a wrong rock starts a new
run with new answers. Every guess lands on a chest or a monster except the last, which
reaches the far shore. After a wrong guess Ellwynn says the right answer (1 to 6,
`audio/voice/ellwynn/answer-*.mp3`) while the music dips; fights do the same.
Tap the dice tray to roll two dice (add, or subtract with a red die), then tap the rock
that many spaces ahead (always 1 to 5). A right rock resolves its space: a chest gives 1
gem (2 one time in 6), a monster starts a fight. A wrong rock sinks the slime with a blorp and the
crossing starts again. Art is in `art/lava/` (PixelLab, see the project's art folders).
Every hero and enemy sits on one pixel grid: one art pixel is one unit of the 960x540
frame (`Look.CHAR_PX` in `game/ui/look.gd`). Characters are never scaled; a character that
needs another size gets art made at that size.
The old ten-task path is still there: `godot --path . -- --area=lava_1`.

### Through the door (Terrence, 2026-11-07)

The door at the end of the crossing leads on: the Surtling Chief miniboss duel (numerals,
a loss restarts only the duel), then the Skeleton Dragon boss (Match Bounce; a win pours
the gem bucket, a loss offers Try or Map), then the mini map of the five worlds
(`content/worlds.json`, `game/world_map_screen.gd`). Only worlds with an area are open;
the rest show a lock until they are built. Tapping an open world opens its main menu.
An area file names its `miniboss` and `boss`; `logic/path/area_flow.gd` orders the steps
and saves the one in progress as the run (`{"area", "grade", "stage"}`), so closing the
app after the door opens the duel or boss again from the main menu's Go.

## Reset

The main menu's small grey Reset button (top right) asks "Reset all?". No keeps
everything; Yes only works when held down for 3 seconds, so a child tapping around
can't wipe the save. It clears gems, purchases, marks, the saved run and Ellwynn's intro.

### Fights, hearts, menu and map (Terrence, 2026-11-07, version 0.15.0)

- The main menu says "Difficulty: Acorn" (tap the difficulty to step through
  the open ones) and its Play goes to the map. Tapping an open world plays it;
  a crossing, duel or boss in progress there picks up again.
- The map unlocks a world once the one before it is beaten (the lock pops off
  the first time). An unlocked world with no area yet says "Soon".
- On the crossing the picked answer goes after the "=": green when right (the
  dragon jumps 4 times), red when wrong.
- A heart stone (step 3, the stone just past Blorp) adds a heart. The hero's
  hearts show under the talk box and carry into and out of each fight, up to
  5; a restart gives back 3 and the heart stone.
- Fights take turns: "Block!" first (the monster attacks; a wrong shield
  costs a hero heart), then "Shield bash!" (a right shield costs the monster a
  heart; a wrong one is a miss, no heart lost). The duel works the same way.
- The Surtling Chief has 5 hearts. Beating it leaves a door with a GO! arrow
  where it stood; tapping the door leads to the boss.
- The boss fight's aim is a dashed line along the ball's real path up to the
  first thing it hits (ghost pegs don't stop it).
- 3 lives on the crossing (Terrence 2026-11-08, 0.15.1): a wrong stone costs a
  heart. The dragon hops onto it, starts to sink, hops back, a heart breaks, and
  the same guess is rolled again with new dice. Losing the last heart sinks it
  and the crossing starts over with 3. The hearts are bottom left, above the
  progress bar, and are the same hearts the fights use.
- Stills: `res://tools/stills/rework_stills.tscn` (same command as the others).

## The store

The main menu's Shop button opens the store (`game/store_screen.gd`): heroes and dice
skins on two tabs, priced in currencies listed in `content/store.json` with their rules
in `logic/core/store.gd`. Gems buy Red Bolt (10), Green Bolt (15) and the helmet slime
(25): a cleared Acorn crossing banks about 6 gems, and beating the Skeleton Dragon pours
out a 10 gem bucket. Red and Green Bolt are the robot dragon recolored in code
(`Look.painted`). The others need
currencies from areas and grades still to come, so they show a lock. A later area opens
its currency by setting `"open": true` in the catalog. Equipped hero and dice show in
the crossing, fights and the boss fight (`game/ui/look.gd`); dice skins are drawn in code
(`game/ui/dice_skins.gd`) and the take-away die stays red in every skin. Hero art:
PixelLab, `art/heroes/`. Stills: `res://tools/stills/store_stills.tscn` (same command as
the other stills).

## Run it

Godot 4.4 (standard build, not .NET). Open `project.godot`, press Play.
Window is 1280x720; F11 toggles fullscreen.
Another area file: `godot --path . -- --area=lava_1_fights` (default `lava_scroll`).
A repeatable run: add `--seed=123` after the `--`.

| | Tablet / mouse | Controller | Keyboard |
|---|---|---|---|
| Roll | flick (or tap) the die tray | A | Space / Enter |
| Move highlight | | d-pad or left stick | arrows / WASD |
| Pick | tap the rock, key or button | A | Space / Enter |
| Count dots | tap each dot on a landed die | | |
| Hear the question again | tap Ellwynn | Y | R |
| Menu (pause, back to the main menu) | tap the button with three bars, top right | | Esc |
| Debug overlay (seed, dice, answer) | hold the top-left corner 1.5 s | Back / Select | F1 |

Music: the main menu loops `audio/music/menu-welcome-to-math-land.mp3`; the Lava Caves
play the five `audio/music/lava-*.mp3` songs in a random order (`game/music.gd`, autoloaded
as `Music`). The songs are Terrence's.

Choices ignore input for 300 ms after they appear, and only a fresh press picks.

## Record a demo video

`tools/demo/` plays the game by itself with real touch events and a finger dot,
and Godot's Movie Maker writes the video (works headless in the cloud with xvfb):

```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
    --write-movie crossing.avi --fixed-fps 30 res://tools/demo/demo.tscn -- --demo=crossing --seed=2
... --write-movie bounce.avi ... -- --demo=bounce --seed=11
```

The crossing demo picks a wrong rock on turn 2 and one wrong shield in the first
fight, then goes through the door, the duel (one wrong shield) and the boss to the mini
map; `--demo=door` starts at the door. The bounce demo names one wrong face. `tools/demo/find_seed.gd` lists seeds
whose crossing meets two or more fights. Delete the profile save first for a clean map.

## Tests

```
python3 -I tools/ref/test_ref.py              # reference: 100k fuzz per grade, bots, replay, resume
python3 -I tools/ref/make_vectors.py          # regenerate tests/vectors/*.json
godot --headless --path . --import            # once, builds the class cache
godot --headless --path . --script tests/run_tests.gd   # all Godot tests, incl. tests/fight/
FUZZ_COUNT=20000 godot ...                     # smaller fuzz for quick runs
```

Godot tests: RNG, problem and replay vectors (must match the Python reference exactly),
100k-problem fuzz per grade, 1000-run perfect and random bots per grade (gate 1: perfect
always clears, random under 1 in 100), resume at every task boundary, fall and chest
rules, 300 ms lockout, content checks.

## Layout

| Path | What | Ports to C++? |
|---|---|---|
| `spec/logic-spec.md` | the contract: RNG, generator, area run, save | yes, the spec |
| `content/` | grades, areas, stickers as plain JSON | yes, unchanged |
| `logic/core`, `logic/path` | pure GDScript (RefCounted, no nodes, no timers) | yes, line by line |
| `tools/ref/` | Python reference + vector generator | the C++ tests use the same vectors |
| `game/` | Godot scenes, drawing, input, sound, file IO | no, rewritten on SDL3 |
| `logic/fight`, `tests/fight` | owned by the fights thread | |
| `logic/bounce`, `content/bounce`, `tests/bounce` | Match Bounce boss fight; see `logic/bounce/README.md` | yes, physics included |

## Screen

The base viewport is 720x540 (the safe area) with stretch aspect `expand`, so a 16:9
screen shows 960x540, 16:10 shows 864x540 and 4:3 iPads show 720x540, all at the same
height. `game/main.gd` centers the 960x540 design space. Stretch mode is `canvas_items`
for crisp shapes; switch to `viewport` with integer scaling when pixel art arrives.

## Export notes

- Add `*.json` to "Filters to export non-resource files" in each export preset, or the
  content files are left out of the build.
- Android/iOS: landscape (sensor) is set; renderer is GL Compatibility for older tablets.

## Not in this phase

Match Bounce is played after the miniboss (and on its own with
`godot --path . res://scenes/bounce.tscn -- --grade=1`). Real art and voice,
Sapling and Oak generators, the parent area. The die is a real 3D cube projected in 2D
(`game/ui/die_view.gd`); pre-rendered tumble frames can replace its `_draw` later.

## Tablet build (Android)

`tools/android/build_apk.sh` exports a signed, sideloadable APK (arm64 and
armv7, landscape, touch only) from `export_presets.cfg`. The header of the
script lists what it needs. Always sign with the same keystore so a new APK
installs over the old one and keeps the save. The launcher icon is the robot
dragon, in `art/icon/`.

`tools/touch_check/touch_check.tscn` plays map, Roll and a rock pick (tap a
rock to select it, tap another to change, then tap Go) with
synthetic finger taps only and saves a still after each step:

    xvfb-run godot --path . --rendering-driver opengl3 --resolution 1024x768 \
        res://tools/touch_check/touch_check.tscn -- --out=/tmp/touch
