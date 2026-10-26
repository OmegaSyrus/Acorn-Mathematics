# Fights, chests, mimics and the miniboss duel (Phase 2 logic)

Pure GDScript: `RefCounted`, no nodes, no timers, all randomness from the injected
`SeededRng`. Ports to C++ line by line. Python reference and vectors in `tests/fight/`.

## Using it from the game

```gdscript
const Fight = preload("res://logic/fight/fight.gd")
const Duel = preload("res://logic/fight/duel.gd")
const Chest = preload("res://logic/fight/chest.gd")
const Monsters = preload("res://logic/fight/monsters.gd")

var fight = Fight.new(rng, grade, "blorp", Monsters.hearts_of("blorp"))
# fight.attack.dice / .target / .kind  -> what the monster swings with
# fight.attack.choices                 -> four values; show as dice faces
#                                         (fight.choice_style == DICE) or numerals
var out = fight.choose(tapped_index)   # on a tap; no timer, the wind-up waits
# out.right        parry + riposte (monster "blocked" then "hurt") or the hit lands ("strike")
# out.answer       fade the numeral in beside the dots
# out.state        RESOLVING, WON (monster "collapse") or LOST (hero collapses)
fight.next_exchange()                  # when the reaction has finished playing
```

On `LOST`, read `fight.on_loss`: `RESTART_AREA` for monsters and mimics (call the path
layer's fail), `RESTART_DUEL` for the duel (call `duel.restart()`, nothing else is lost).

Chests: `Chest.resolve(is_mimic, answered_right)` gives `OPENED`, `STAYS_SHUT` or
`MIMIC_FIGHT`; for a mimic, `Chest.mimic_fight(rng, grade, answered_right)` starts the
fight one heart down when the lock was answered right. Mimic-ness is set when the area is
built, never by a wrong answer.

Duel: `Duel.new(rng, grade, "lava_miniboss")`. Same exchange, big plain numerals, 3 fresh
hearts each, `restart()` on a loss. A win leads straight into the boss (not built here).

Placeholder states each fighter needs: `Monsters.STATES` (idle, wind_up, blocked, hurt,
strike, collapse, gloat). Mimic tells: `Monsters.MIMIC_TELLS`.

## The attack, by grade

| Grade | Monster shows | Right choice | Choice range |
|---|---|---|---|
| Acorn | one die | the same count | 1 to 6 |
| Sprout | two dice | the total | 1 to 12 |
| Sapling | a die and a target | the missing number (die + ? = target) | 1 to 12 |
| Oak | move die and red slip die (move is always bigger) | the difference, 1 to 5 | 1 to 12 |

Wrong choices are near misses: first an attack die on its own, the answer plus or minus
one, and at Sapling the target; then plus or minus two, and at Oak the dice added; plus or
minus three only as filler when nothing nearer fits on that side. The answer's position
among the four (smallest to largest) is drawn evenly first, then the dice are rerolled
until the near misses fit, so "tap the biggest" is no better than guessing.

## Tests

`godot --headless --path . --script tests/run_tests.gd` runs these with everything else;
`tests/fight/run_fight_tests.gd` runs only these (about 2.5 minutes). `python3 -I
tests/fight/ref/fight_ref.py --check` runs the reference fuzz and bot (10 s), and without
`--check` rewrites `tests/fight/vectors/fights.json`.

Gate 2 numbers (5,000 fights per grade): the random bot beats a 3-heart monster 10 to 11%
of the time (gate: 15%), a 4-heart monster about 4%, the duel 10 to 11%; the perfect bot
never loses. Pattern bots (biggest, smallest, middle of a run, never the middle) stay
at 14% or under.

## The graybox fight screen

`game/fight/fight_screen.gd`: `setup(rng, grade, monster_id, first_strike, duel, show_debug)`,
add it as a child, `await done` for `won`. The area screen does this for `fight` tasks and
mimics (`_fight()` in `game/area_screen.gd`) with `run.rng`, so replays stay seeded. The
monster is a labelled box that names the reaction it is playing; the attack dice tumble in
and their dots can be tapped to count; shields show dice faces (numerals in the duel).

Play the test area: `godot --path . -- --area=lava_1_fights` (a fight, a mimic chest with
its tells, a 4-heart Craggy). Headless smoke run, which loses the first fight on purpose,
fumbles the mimic's lock, then clears:
`godot --headless --path . res://tests/fight/smoke_fights.tscn -- --grade=2`
(it puts back any existing save when it finishes).
