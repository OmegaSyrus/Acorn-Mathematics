# Match Bounce (Phase 3 logic, started)

The boss fight from plan section 07, Option A: the boss shows a number and only pegs
that make it with the ball pop. Pure GDScript like the rest of `logic/`: `RefCounted`,
no nodes, no timers, all randomness from the injected `SeededRng`. Ports to C++ line
by line, physics included (plain circles and line segments, fixed 120 Hz step).

## The rule, by grade

| Grade | Rule | Ball | The boss shows | Pops |
|---|---|---|---|---|
| Acorn | `match` | takes the boss's roll | a die, 1 to 3 | pegs showing that numeral (1 to 3 in three colours) |
| Sprout, Sapling | `sum` | a die | the target | pegs where ball + peg = target |
| Oak | `difference` | a die, bigger than the peg | the target | pegs where ball - peg = target |

At Acorn (`auto_name` and `peg_labels: "numerals"` in tuning.json, from the children's
mother, 2026-10-28) there is no naming step: the boss rolls its die, the ball becomes that
many dots, and the pegs show numerals, so the child aims the dots at the matching number.
The choices are still drawn so the random draw order is the same.

One shot: **name the peg** (tap the face that completes the target; Acorn offers 1, 2
and 3, other grades four faces from 1 to 6), **aim** (drag from the board, a fixed 70 px
stub shows direction only), **fire** (let go). A wrong name still flies, but every peg
is a ghost: nothing pops and the boss laughs. The ball is spent either way.

- Live pegs are solid: they pop on touch and the ball bounces off them. Every other
  peg is a ghost the ball passes through (a "whiff" event, the screen wobbles it).
- Walls, bumpers and ±1 pegs are always solid. A ±1 peg changes the ball's die once
  per shot, so different pegs become live mid-flight.
- Damage = pegs popped + 1 for each ±1 peg followed by a pop.
- The needed face is drawn only from faces with at least `min_live` pegs left; when no
  face has enough, the board fills up again ("New pegs!").
- Balls: 8 at Acorn, 6 above. Out of balls with hearts left is the fail screen (Try, Map).
- The last heart: `fight.is_lethal()` turns true mid-flight; the screen slows to 30% (`screen.last_heart_time_scale` in tuning.json) and the ball and pegs warble.

Draw order per shot (the C++ port must match): refill check, needed face
(`randi_range` over eligible faces), the ball die if the rule has one, then the
choice shuffle. The flight itself uses no randomness.

## Files

| Path | What |
|---|---|
| `bounce_rules.gd` | the math: needed face, rolling a shot, name-the-peg choices |
| `bounce_sim.gd` | one shot's flight: `step()` at 120 Hz returns pop, whiff, mod, bounce, end events |
| `bounce_fight.gd` | the fight: hearts, balls, board state, `name_peg()`, `fire()`, `end_shot()` |
| `content/bounce/tuning.json` | physics numbers and per-grade rule, board, balls, boss hearts |
| `content/bounce/boards/*.json` | peg positions and faces, ±1 pegs, bumpers, walls |
| `game/bounce/bounce_screen.gd` | the graybox screen (tablet first) |
| `tests/bounce/` | rule tests, Gate 3 bots, a smoke run that saves screenshots |

## Run it

```
godot --path . res://scenes/bounce.tscn -- --grade=1          # Acorn; --grade=2 for Sprout
godot --path . res://scenes/bounce.tscn -- --grade=1 --seed=42
xvfb-run godot --path . res://tests/bounce/bounce_smoke.tscn -- --grade=1 --out=/tmp/shots
```

F1 shows the debug line (target, answer, live pegs). Controller: d-pad names, left and
right aim, A fires. Not linked from the map yet.

## Gate 3 bots (tests/bounce/test_bounce_bots.gd)

At the current tuning (2026-10-26):

| | Acorn (10 hearts, 8 balls) | Sprout (12 hearts, 6 balls) |
|---|---|---|
| random name, random aim | wins 0% | wins 0% |
| right name, random aim | about 1.0 pops a ball, wins about 25% | about 0.8 pops a ball, wins about 3% |
| right name, best of 27 aims | about 3.5 pops a ball, wins 100% | about 2.4 pops a ball, wins 100% |

The gate wants the right-name random-aim bot at 1 to 2 pops a ball; Acorn sits at the
bottom edge and Sprout just under. Tune with ball speed, clusters and ball count in
play, never with hints.

## Not done yet

Boss art and states (boss kit), the practice tray, real sounds, the map link, a Python
reference with replay vectors for the C++ port, and boards for the other worlds.
