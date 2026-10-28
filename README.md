# Acorn Mathematics: Godot graybox (Phase 1, the path)

Prototype only, never shipped (plan 0.18, section 15). Placeholder shapes, no art.
One area, Lava Caves 1: 10 tasks (6 path steps, 2 doors, 2 chests) at Acorn or Sprout,
with the real fail rule.

## The lava crossing (default area)

`lava_scroll` is the first round at Acorn: 40 rocks in the lava, crossed left to right.
Tap the dice tray to roll two dice (add, or subtract with a red die), then tap the rock
that many spaces ahead (always 1 to 5). A right rock resolves its space: a chest gives 2
to 4 gems, a monster starts a fight. A wrong rock sinks the slime with a blorp and the
crossing starts again. Art is in `art/lava/` (PixelLab, see the project's art folders).
The old ten-task path is still there: `godot --path . -- --area=lava_1`.

## Run it

Godot 4.4 (standard build, not .NET). Open `project.godot`, press Play.
Window is 1280x720; F11 toggles fullscreen.
Another area file: `godot --path . -- --area=lava_1_fights` (default `lava_scroll`).

| | Tablet / mouse | Controller | Keyboard |
|---|---|---|---|
| Roll | flick (or tap) the die tray | A | Space / Enter |
| Move highlight | | d-pad or left stick | arrows / WASD |
| Pick | tap the rock, key or button | A | Space / Enter |
| Count dots | tap each dot on a landed die | | |
| Hear the question again | tap Elfwynn | Y | R |
| Debug overlay (seed, dice, answer) | hold the top-left corner 1.5 s | Back / Select | F1 |

Choices ignore input for 300 ms after they appear, and only a fresh press picks.

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

Match Bounce is started (`godot --path . res://scenes/bounce.tscn -- --grade=1`) but not
linked from the map. Real art and voice,
Sapling and Oak generators, the parent area. The die is a real 3D cube projected in 2D
(`game/ui/die_view.gd`); pre-rendered tumble frames can replace its `_draw` later.
