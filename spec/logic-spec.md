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

Resume = new run from `seed`, then set attempt, task_index and rng_state. The current
task starts over and regenerates the same problem. Stickers and marks only ever grow.
