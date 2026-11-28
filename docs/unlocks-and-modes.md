# Unlocks and modes (Phase 6 of the ship plan, 2026-11-28)

What a child earns besides the next Level, and the play it opens. Only play moves
anything on: no grown-up switch, Level pick or Debug toggle gives a hero, a card or a
trophy.

## Unlocks

### Level heroes

The first full pass of a Level (every world beaten at Level N, `AreaFlow.level_beaten`)
wins a hero. No new art: three heroes that were waiting for the never-earnable Sprout and
Sapling stars, and Bolt painted in code (`Look.painted`, like Red and Green Bolt).

| Level | Hero | Art |
|---|---|---|
| 1 | Leo | `art/heroes/lion.png` |
| 2 | Sir Tam | `art/heroes/templar.png` |
| 3 | Blaze | `art/heroes/phoenix.png` |
| 4 | Black Bolt | Bolt, painted |
| 5 | Plum Bolt (purple) | Bolt, painted |
| 6 | Pink Bolt | Bolt, painted |

- **Catalog.** An item in `content/store.json` with `"reward": {"level_pass": N}` has no
  price. The star currencies are gone; the gold dice moved to 30 gems and the purple gem
  dice to 30 crystals. Old saves still load: nothing could ever hold stars.
- **Rules** (`logic/core/store.gd`). `Store.grant_level_rewards(cat, save, worlds)` adds
  every reward whose Level has had its full pass to `save["owned"]` and returns the new
  ids. It runs after each boss (`game/main.gd` `_start_stage`, the map step) and on every
  save load (`game/save_store.gd`), so a save that beat a Level before this build gets its
  heroes too. A reward is given once; a replay gives nothing.
- **Store.** A third tab, a gold cup, holds the Level heroes. A hero not won yet shows dim,
  with a lock and "Level N" where a price would be, and shakes when tapped
  (`Store.LEVEL`). Once won it is a normal owned hero: "Use", then the check mark.
- **"New hero!"** When a boss finishes a Level, the world map opens with a pop: the hero at
  1:1 on a panel with turning stars. A tap goes on to the map (and the lock popping off
  the next Level's Lava).

### The monster book

- **Data** (`logic/core/book.gd`). `save["book"] = {monster id: [Level numbers]}`.
  `Book.record` runs when a crossing fight is won (`game/scroll_screen.gd`, the level's
  `num`), when the miniboss duel is won (`game/main.gd` `_start_duel`) and on the old
  ten-task path (`game/area_screen.gd`, which has the mimic). Bosses are not stored: a
  boss beaten is the world's mark, and `Book.trophy_at(save, world, n)` reads it.
- **Book screen** (`game/book_screen.gd`), from the main menu's Book button. A page per
  world, picked from the tabs at the top (each tab shows a dot per fighter, gold once
  beaten, and a cup once the world's boss is beaten). A card per monster and miniboss in
  `Monsters.ROSTER` order: once beaten the fighter at 1:1 and its name, before that a
  black shape and a "?". A fighter bigger than its card shows its top part, cut to the
  card (characters are never scaled). Minibosses have a gold frame. Under the cards, the
  boss's face (a black shape until beaten) and six cups, one per Level, gold once the boss
  is beaten at that Level.
- **Map trophies.** The world map puts a gold cup (`game/ui/trophy.gd`, drawn in whole
  pixels) by each world whose boss is beaten at the map's Level. It replaced the gold
  star there.
- **Save.** `book` is optional in `acorn.save` v2 (`docs/contract/games/acorn-math/`);
  `SaveData.merge` unions it like marks and stars. The contract's source of truth is
  OmegaSyrus/Acorn-Backend `docs/contract/`, which needs the same schema change.
- **Main menu.** The Level box moved up 30 to make a row of small buttons under its marks
  (`MapScreen.ROW_Y`): Book (`BOOK_RECT`, x 396), with room for two more at x 544 and 692.

Stills: `res://tools/stills/unlock_stills.tscn` (same command as the other stills).
Tests: `tests/test_unlocks.gd`.

## Modes

Two modes on the main menu, in the row of small buttons between the Level
marks and Play (after the Book): **Arena** and **Bounce**. Both open as the
child meets them on the path and pay small, so the path stays the way forward
and the big bonuses stay on the path (a boss bucket pays 10 for the first
clear of a world at a Level, 30 for the clear that finishes a Level and 3 on a
replay; a crossing banks about 6 of the world's currency).

- **Opening.** `logic/core/book.gd`: the Arena opens once 3 plain monsters
  have a card in the book (`Book.arena_open`), Bounce once any boss is beaten
  (`Book.bounce_open`). A locked button is grey with a padlock and a tap gives
  a soft "no" beep. A mode that has just opened wears a red "New!" until it is
  first tapped (`save["modes_seen"]`, `logic/modes/modes.gd`).
- **Level.** Both play at the menu's Level (the child's Level, or one before it
  they picked to replay). The math follows the Level only: no adaptive math.

### Arena (fights only)

`logic/modes/arena_run.gd` (pure), `game/arena_screen.gd`, `game/modes_flow.gd`.

- A round is 5 fights, drawn with the round's seeded RNG from the monsters in
  the book (each once before any comes back, never the same one twice in a
  row). A monster no crossing holds any more is left out.
- Each fight asks what the path asks for that monster: its world's level at the
  child's Level, the stage where the crossing meets it, and the Debug fight
  switch ("step before" or "own"), through the same helper the crossing uses
  (`ScrollRun.monster_fight` / `fight_of` / `stage_of`).
- The hero starts with 3 hearts and carries them from fight to fight, like the
  crossing, with no heart stones and no refills.
- **No gentle failing.** A lost fight ends the round: "Try" starts it over
  from fight 1 (same monsters, new dice, 3 hearts), "Back" goes to the menu.
  Nothing is paid.
- Winning all 5 pays **3 gems**, once per round. "Go" then starts a new round.
- The screen between fights shows the round's monsters in a row (beaten ones
  dimmed with a tick, the next one framed in gold), the hearts, a big "Go" and
  "Back".
- Play log: area `arena`, the world and level of the fight; events
  `arena_start` (monsters, try), `arena_win` (gems, hearts_left, try) and
  `arena_lost` (fight, monster, try). Answers are logged by the fight as
  `where: fight`. No contract change was needed (`area` and `event` are free
  strings).

Bot check (`tests/test_arena.gd`, 400 rounds a Level, a book of all 15
monsters):

| Level | always right | 85% right | random |
|---|---|---|---|
| 1 | 100% | 67% | 0% |
| 2 | 100% | 62% | 0% |
| 3 | 100% | 67% | 0% |
| 4 | 100% | 68% | 0% |
| 5 | 100% | 64% | 0% |
| 6 | 100% | 64% | 0% |

Gates: always right clears every round, 85% right clears 45% to 85%, a random
guesser at most 3%.

### Bounce (bosses only)

`logic/modes/modes.gd`, `game/bounce_picker_screen.gd`, `game/modes_flow.gd`.

- The picker shows a card for each boss beaten at any Level (the boss's face
  and the world's name). A tap plays that boss's board with the boss grade of
  that world's level at the child's Level (`Modes.bounce_board`).
- A win pays **2 of the world's currency** (`content/bounce/tuning.json`
  `screen.mode_gems`, `BounceScreen.set_bonus("mode")`) and goes back to the
  picker. It adds no mark or star, does not move the Level and leaves the saved
  run alone.
- A loss offers "Try" (the same boss again) and "Back" (the picker).
- Play log: area `bounce`, the boss's world and level; event `bounce_start`,
  then the boss's own `boss_won` / `boss_lost` and answers.

### Save

- `modes_seen`: the modes tapped since they opened (`["arena", "bounce"]`), so
  "New!" shows once. Not merged across devices; the newest snapshot's copy
  wins, like any field `SaveData.merge` does not know.

Stills: `res://tools/stills/modes_stills.tscn` (same command as the others).
