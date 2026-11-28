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
