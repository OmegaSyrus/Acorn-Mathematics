# Logic spec v1: RNG, problem generator, area run, save

This is the contract the Godot prototype and the C++20/SDL3 port both implement.
Reference implementation: `tools/ref/*.py`. Test vectors: `tests/vectors/*.json`
(regenerate with `python3 -I tools/ref/make_vectors.py`). Any change to the draw
order below changes the vectors, so bump this spec's version when you do it.

## 1. RNG: xorshift32

All values are unsigned 32-bit.

```
reseed(seed):   state = seed & 0xFFFFFFFF; if state == 0: state = 0x6D2B79F5
                then call next_u32() 8 times (warm-up)
next_u32():     x = state; x ^= x << 13; x ^= x >> 17; x ^= x << 5; state = x; return x
randi_range(lo, hi):  lo + next_u32() % (hi - lo + 1)        (inclusive)
shuffle(a):     for i = len-1 down to 1: j = randi_range(0, i); swap a[i], a[j]
get_state / set_state(s): raw state; set_state does no warm-up (0 maps to 0x6D2B79F5)
```

Only game logic draws from this RNG. Cosmetic randomness (die spin axis, sparkle)
uses a separate engine RNG and never touches it.

## 2. Grades (content/grades.json)

| id | name    | rule       | dice                     | answer        | choices in |
|----|---------|------------|--------------------------|---------------|------------|
| 1  | Acorn   | single     | one move die 1..6        | the die       | 1..8       |
| 2  | Sprout  | sum        | two move dice 1..6       | a + b         | 1..14      |
| 3  | Sapling | missing    | not implemented yet      |               |            |
| 4  | Oak     | difference | not implemented yet      |               |            |

`available: false` grades are hidden on the map. Every grade has 4 choices.

## 3. Problem generator

`generate(kind, grade, rng)`, kind is `path`, `door` or `chest`.

1. Roll each die in `grade.dice` order: `randi_range(min, max)`.
2. Answer per rule. `singles` = the dice for `sum`, empty for `single`.
3. Wrong choices = `near_misses(answer, singles, min_choice, max_choice, choices - 1)`:
   - near list: `singles` then `answer - 1`, `answer + 1`, keeping each value that is in
     range, not the answer and not already in the list. Shuffle it. Take the first `count`.
   - while short: for k = 2, 3, ...: the pair `answer - k`, `answer + k` (same filter). If
     both are valid and only one slot is left, take `pair[randi_range(0, 1)]`; otherwise take
     the whole pair. Stop when there are `count`.
4. `choices = wrong + [answer]`. Path: sort ascending (they are rocks in a row, by distance).
   Door and chest: shuffle (keys).
5. Return `{kind, grade, dice, answer, choices, answer_index}`.

Properties the fuzz test checks over 100,000 problems per grade: dice in range, answer
correct, 4 distinct choices in range, exactly one right, at least one near miss (a single
die or answer ±1), no wrong choice further than 3 unless it is a single die, path choices
sorted, key slots used evenly (within 2%).

## 4. Area run

An area (content/areas/*.json) is 6 to 10 tasks of type `path`, `door`, `chest` or `fight`.

Phases: `await_chest` (a chest: open it or walk past), `await_roll`, `await_choice`,
`await_fight` (fights are resolved by the fight layer), `cleared`.

| input                | outcome                                                           |
|----------------------|-------------------------------------------------------------------|
| decide_chest(false)  | `walk_past`, next task                                            |
| decide_chest(true)   | `chest_try`, phase becomes await_roll                             |
| roll()               | generate the task's problem (draws from the run RNG)              |
| choose(i) right      | path `hop`, door `door_open`, chest `chest_open` + sticker (one draw `randi_range(0, n-1)` over content/stickers.json); next task |
| choose(i) wrong      | path `fall`, door `trap`: **restart** (attempt + 1, task 0). Chest `chest_shut`: next task, nothing lost |
| choose(i) on a mimic | `mimic` with `first_strike = right`; phase becomes await_fight on the same task (chest task with `"mimic": true`, set when the area is built) |
| resolve_fight(won)   | `fight_won` next task, `fight_lost` restart. Used by fight tasks (`{"type": "fight", "monster": "<id>"}`) and mimics. `current_monster()` gives the id, or `mimic` |

A restart keeps the same RNG stream, so the new attempt gets fresh problems.
Each outcome is logged as `{attempt, task, type, result, dice?, choices?, pick?, sticker?}`
with attempt/task as they were when the task was answered.

## 5. Save (one JSON per profile, written after every task)

```
{ "version": 1, "profile": "1", "stickers": [...], "marks": {"lava_1": [1, 2]},
  "run": null | {"area", "grade", "seed", "attempt", "task_index", "rng_state"} }
```

Store fields (2026-11-05; a save without them loads with these defaults):
`"currencies": {}` (balances by currency id; gems stay in the top-level `"gems"`),
`"owned": []` (bought item ids; unpriced catalog items are always owned), `"hero":
"robodragon"`, `"dice": "classic"` (equipped; an id that is missing, of the wrong kind or
not owned falls back to the kind's first unpriced item). Rules: logic/core/store.gd over
content/store.json; an item priced in a currency whose `open` is false cannot be bought.

Resume = new run from `seed`, then set attempt, task_index and rng_state. The current
task starts over and regenerates the same problem. Stickers and marks only ever grow.

## 6. Scroll areas and move problems (spec v1.1, added 2026-10-26)

A scroll area (`"type": "scroll"` in content/areas) is a row of `length` spaces crossed
left to right, with `spaces` entries `{at, type: "chest" | "monster", monster?}`. It lists
the grades it is built for (`grades`); each needs a `move` config in grades.json.
Acorn: `{"ops": ["add", "sub"], "max_answer": 5, "die_max": 6}`.

`generate_move(grade, rng, room)`, room = spaces left before the goal:

1. `m = min(max_answer, room)`. `ops` = the config's ops, without `add` when `m < 2`.
2. `op = ops[0]` if there is one op, else `ops[randi_range(0, len - 1)]`.
3. add: `answer = randi_range(2, m)`, `a = randi_range(1, answer - 1)`, `b = answer - a`.
   sub: `answer = randi_range(1, m)`, `a = randi_range(answer + 1, die_max)`, `b = a - answer`.
   The answer is drawn first so every distance is equally likely.
4. `choices = [1 .. m]` (the next m spaces), `answer_index = answer - 1`.
5. Return `{kind: "move", grade, op, dice: [a, b], answer, choices, answer_index}`.

Optional `lo`, `hi` (hi > 0) narrow the answer only (2026-11-07): `top = clamp(hi, 1, m)`,
`bottom = clamp(lo, 1, top)`; `add` is dropped when `top < 2`; add draws
`randi_range(max(2, bottom), top)`, sub `randi_range(bottom, top)`. Choices stay `[1 .. m]`.

Run (`logic/path/scroll_run.gd`, reference `tools/ref/scroll_run.py`), phases
`await_roll`, `await_choice`, `await_fight`, `cleared`.

**Guesses (Terrence 2026-11-07, lava_scroll):** an area with `guesses: n` has no fixed
`length` or `spaces`. When a run is made, and again on every restart, it draws `answers`
= n times `randi_range(1, max_answer)` (before any other draw of that attempt); `length`
is their sum. `steps: [{after: k, type, monster?}]` put a chest or monster on the space
the first k answers reach (k from 1 to n - 1). roll() then uses `lo = hi = answers[rolls]`,
so a clean run takes exactly n rolls. `looted` holds a chest's `after` (its step), so an
opened chest stays empty in the next attempt's new layout. The save adds `answers`; a
guesses save without them (from the fixed 40 stones) starts a fresh attempt at space 0
with the gems and attempt kept. Areas with `length` and `spaces` work as below.

| input | outcome |
|---|---|
| roll() | `generate_move(grade, rng, length - pos, lo, hi)`, then `rolls + 1`. With the area's `rolls: [min, max]` (lava_scroll 10 to 12, Terrence 2026-11-07): `lo = max(1, room - max_answer * (max - rolls - 1))`, `hi = min(max_answer, room - max(0, min - rolls - 1))`, hi raised to lo; without it `lo = 1, hi = 0` (no limit). A clean crossing then takes min to max rolls |
| choose(i) wrong | `sink`: **restart** (attempt + 1, pos 0, rolls 0) |
| choose(i) right | `target = pos + answer`, then walk one space at a time; every space walked onto triggers (2026-11-04): an unopened chest gives gems in one draw (`chest_gems` `{common, rare, rare_in}`: `rare` if `randi_range(1, rare_in) == rare_in`, else `common`; an old `[lo, hi]` pair draws `randi_range(lo, hi)`; lava_scroll is 1, rarely 2, rare_in 6, since 2026-11-06) and the walk goes on; a monster stops the walk there (`monster`, await_fight); the last space is `goal` (cleared). Reaching the target: `chest` if it was an unopened chest, else `hop`. The outcome carries `to` (where it stopped), `chests: [{at, gems}]` in order and `gems` (their total, when any) |
| resolve_fight(won) | `fight_won` (await_roll) or `fight_lost` (restart). A win with `target > pos` finishes the walk the same way; its outcome is under `walk` and logged as its own event |

Opened chests stay empty after a restart (`looted`), so gems can't be farmed; monsters come
back. Events: `{attempt, pos, result, op?, dice?, pick?, gems?}`. Save:
`{area, grade, seed, attempt, pos, target, looted, gems, rolls, phase, rng_state}` (a save without
`target` loads with `target = pos`, without `rolls` with 0); a run saved in
`await_choice` resumes at the roll (and `rolls - 1`). Vectors: `tests/vectors/scroll.json`.
