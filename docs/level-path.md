# The Level path (Phase 1 of the ship plan, 2026-11-16)

Level N is one pass of the five worlds: Lava, Crystal, Bog, Mushroom and Space, each
at Level N. Beating Space at Level N opens Level N+1, which starts again at Lava.
A grown-up may pick the Level on the Grown-ups panel (Terrence 2026-11-17); the worlds
inside a Level still open only by play.

## How it works

- **Opening.** `logic/path/area_flow.gd`: Level 1 is always open; Level N once every
  world is beaten at Level N-1 (`level_open`, `level_reached`). At a Level, Lava is
  open, and each world after it once the world before it is beaten there
  (`world_unlocked(save, worlds, i, level)`). It is all worked out from the marks the
  save keeps (`save["marks"][world] = [level ids]`) and the Level a grown-up picked
  (`grown_up_level`, below). Debug's "Map: all open" still opens every world at every
  Level.
- **Menu and map.** The main menu says "Level: N" (was "Difficulty"). It starts on the
  child's Level; a tap steps back through the Levels reached, to replay one. The map's
  title is the Level, and it shows what is open and done at it.
- **Moving on.** When a boss finishes a Level (every world now beaten at it, and it
  wasn't before) and the next Level is open, the child moves on: the menu's Level
  becomes N+1 and the map opens there with Lava's lock popping off
  (`AreaFlow.move_on_level`). This holds when a grown-up picked a higher Level too: a
  child picked to 5 who then beats every world at Level 2 moves on to Level 3. A
  replay of a Level already beaten stays put.
- **Grown-ups panel.** No world switches. Under the title it names the child it
  changes (the one playing now), with their picture. The Level buttons 1 to 6 pick the
  Level the child plays (`AreaFlow.pick_level`): that Level and the ones before it open,
  each at Lava only; the other worlds there still open by beating the one before.
  Picking a lower Level than one earned keeps everything earned and only moves the menu
  back. A run saved at another Level (a crossing mid-way, or its duel or boss) is
  dropped, so the next play starts fresh at the picked Level. Each child's pick is in
  their own save. Below, each world is Done, Next or Locked at the Level.
- **The ladder.** `content/levels.json` lists the 30 steps in order (`step`), each with
  the one thing it adds (`new`, `adds`). Level ids never change (Lava 1 = 1, the rest
  world x 10 + Level), so old marks, stars and play records still line up by world and
  Level number; the math under each id was re-sorted.
- **Warm-ups.** Every crossing opens with 3 guesses at the step before's math and fight
  (`Content.levels()` builds a 2-stage `ramp`; Lava 1 warms up on one die to 3). The
  step that brings in the rails or the star track keeps it off for its warm-up.
- **Fights.** As before, a monster asks the step before's fight (now along this path)
  and the miniboss duel the level's own. Phase 2 decides what fights finally ask.
- **Misses.** Every crossing has room for 3 misses: three hearts and one heart stone.
  Lava has 7 guesses; the other four worlds 8 (were 9), each with three monsters. The
  Bog gave up its second heart stone and Tiddy Mun (back to the chest it replaced), so
  every world asks about the same number of questions (27 to 28 for a clean try).
- **Bonuses.** The boss's gem bucket pays 10 the first time a world is beaten at a
  Level, 30 for the clear that finishes a Level, and 3 on a replay
  (`content/bounce/tuning.json` `win_gems`, `pass_gems`, `replay_gems`;
  `AreaFlow.boss_bonus`).
- **Bot check.** `tests/test_clear_chance.gd`: a bot answering 85% right (stones and
  fights) clears every crossing in one try 55% to 70% of the time. Today 57% to 66%.

## Save format

- `grown_up_level`: the Level a grown-up picked on the Grown-ups panel, 0 or missing
  for none. It opens that Level and the ones before it (`AreaFlow.level_open`); play can
  still take the child past it. Reset wipes it with the rest of the save.
- `difficulty` keeps the Level picked on the menu (or on the Grown-ups panel), clamped
  to the Levels reached.
- `parent_open` (the old Grown-ups world switches) is gone: a new profile no longer has
  it, and an old save drops it on load.

## The 30 steps

Fight is grade and top (1 one die, 2 two-dice sum, 3 die + ? = target). Boss 1 match,
2 sum, 4 difference.

| Step | Level | Id | Adds | Stones | World | Fight | Boss |
|---|---|---|---|---|---|---|---|
| 1 | Lava 1 | 1 | one die | `+` to 6 |  | 1 6 | 1 |
| 2 | Crystal 1 | 21 | two dice, adding to 6 | `++` to 6 |  | 2 6 | 2 |
| 3 | Bog 1 | 31 | two dice to 8 | `++` to 8 |  | 2 8 | 2 |
| 4 | Mushroom 1 | 41 | two dice to 10 | `++` to 10 |  | 2 10 | 2 |
| 5 | Space 1 | 51 | two dice to 12 | `++` to 12 |  | 2 12 | 2 |
| 6 | Lava 2 | 12 | a take-away die (red) with two dice | `++` `+-` to 12 |  | 2 12 | 1 |
| 7 | Crystal 2 | 22 | three dice, to 9 | `++` `+-` `+++` to 9 |  | 2 9 | 2 |
| 8 | Bog 2 | 32 | three dice to 11 | `++` `+-` `+++` to 11 |  | 2 11 | 2 |
| 9 | Mushroom 2 | 42 | three dice to 14 | `++` `+-` `+++` to 14 |  | 2 12 | 2 |
| 10 | Space 2 | 52 | the star track: stones show their place | `++` `+-` `+++` to 14 | track | 2 12 | 2 |
| 11 | Lava 3 | 13 | a take-away among three dice | `++` `+-` `+++` `++-` to 14 |  | 2 12 | 1 |
| 12 | Crystal 3 | 23 | the rails: only 1, 5, 10 and 15 numbered | `++` `+-` `+++` `++-` to 14 | rails | 2 12 | 2 |
| 13 | Bog 3 | 33 | three dice to 16 | `++` `+-` `+++` `++-` to 16 |  | 2 12 | 2 |
| 14 | Mushroom 3 | 43 | three dice to 18 | `++` `+-` `+++` `++-` to 18 |  | 2 12 | 2 |
| 15 | Space 3 | 53 | two take-aways among three dice | `++` `+-` `+++` `++-` `+--` to 18 | track | 2 12 | 4 |
| 16 | Lava 4 | 14 | four dice, to 12 | `+++` `++-` `+--` `++++` to 12 |  | 2 12 | 1 |
| 17 | Crystal 4 | 24 | four dice to 14 | `+++` `++-` `+--` `++++` to 14 | rails | 2 12 | 2 |
| 18 | Bog 4 | 34 | four dice to 16 | `+++` `++-` `+--` `++++` to 16 |  | 2 12 | 2 |
| 19 | Mushroom 4 | 44 | four dice to 18 (often a double) | `+++` `++-` `+--` `++++` to 18, pairs |  | 2 12 | 2 |
| 20 | Space 4 | 54 | four dice to 20 | `+++` `++-` `+--` `++++` to 20 | track | 2 12 | 4 |
| 21 | Lava 5 | 15 | the hidden die: find the missing number | hidden: `++` last |  | 3 12 | 1 |
| 22 | Crystal 5 | 25 | a hidden take-away die | hidden: `++` last, `+-` last | rails | 3 12 | 2 |
| 23 | Bog 5 | 35 | a hidden die among three | hidden: `++` last, `+-` last, `+++` last |  | 3 12 | 2 |
| 24 | Mushroom 5 | 45 | the hidden die can be any of the three | hidden: `++` last, `+-` last, `+++` any |  | 3 12 | 2 |
| 25 | Space 5 | 55 | a hidden die among four | hidden: `++` last, `+-` last, `+++` any, `++++` any | track | 3 12 | 4 |
| 26 | Lava 6 | 16 | take away across ten | `++-` to 9, across_ten |  | 2 12 | 1 |
| 27 | Crystal 6 | 26 | across ten with four dice | `++-` `+++-` to 9, across_ten | rails | 2 12 | 2 |
| 28 | Bog 6 | 36 | across ten with two take-aways | `++-` `+++-` `++--` to 9, across_ten |  | 2 12 | 2 |
| 29 | Mushroom 6 | 46 | mixed: adding to 20 and across ten | mix of 54, 36 |  | 3 12 | 2 |
| 30 | Space 6 | 56 | everything mixed | mix of 54, 55, 36 | track | 3 12 | 4 |
