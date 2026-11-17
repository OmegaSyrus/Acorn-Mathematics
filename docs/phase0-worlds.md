# Phase 0 of the ship plan: the five worlds finished (2026-11-16)

The plan's Phase 0 asks that every world reaches Lava's standard: its own
music, its miniboss and boss done with a rule of its own per miniboss, and its
currency open in the shop. Build 0.24.0 (version code 43).

## Music

`game/music.gd` now has `WORLD_SONGS`, one list per world, and the game calls
`Music.play_world(world)` for the crossing, the duel and the boss. A world
with an empty list plays the Lava songs, as before. Adding a world's songs is
two steps: drop the mp3 files in `audio/music/` and list them under the world.
Worlds that share the Lava songs share one playlist, so moving between them
never restarts a song.

Still to come: the songs themselves for the Crystal Mines, the Bog, the
Mushroom Forest and Space (Terrence's own, or made with ElevenLabs Music).
If they don't arrive in Phase 0 they move to Phase 3.

## Minibosses: a rule each

All in `logic/fight/duel.gd`. The math is always the level's fight math; the
rule changes how the swing is shown, moving from dots toward written numbers
world by world.

| World | Miniboss | Rule |
| --- | --- | --- |
| Lava Caves | Surtling Chief | Total: the dice as dots, as in every fight |
| Crystal Mines | Svartalf Lantern Lord | Flash: the lantern lights the dice for 1.8 s, then they go dark; tapping a dark die lights it again |
| The Bog | Wisp King and Queen | Pair: two foes with their own hearts (3 and 2) who take turns; a bash hits the one who just swung |
| Mushroom Forest | The Hedley Kow | Count on: the first die is written as its number, the second stays as dots |
| Space | Ratatoskr | Numerals: every die (and a Sapling target) is written as its number; a tap shows the dots |

Rules that need two dice show dots when a swing has one die, since a numeral
against numeral shields would only be matching. When the answer is in, every
cover lifts so the dots and the number show together. The talk box opens each
duel with the rule's word: "Fight!", "Look fast!", "Two foes!", "Count on!",
"Read it!". Tests: `tests/fight/test_duel_rules.gd` (the perfect bot wins
every duel, a guessing bot wins under 1%).

## Bosses: a board each

Every boss already had its own art, room and gem bucket. Each now also plays
on a board of its own (`content/bounce/boards/`): `crystal_1` a crystal
lattice, `bog_1` two wavy rows of reeds, `mushroom_1` a mushroom cap,
`space_1` a ring of stars. Each keeps sprout_1's 16 pegs (four each of faces
2 to 5), the +1 and -1 mods and the bumper, and `tuning.json` "world_boards"
picks them. The bounce bot gates now run on every board: a bot that names
right and aims at random wins 63% to 79%, one that names at random wins 15%
or less, and the best-aim bot always wins.

## Currencies

Each world's chests and its boss's bucket pay its own currency
(`Store.currency_of_world`): gems in the Lava Caves, crystals in the Crystal
Mines, brooches in the Bog (new, Terrence's 6 November pick), leaves in the
Mushroom Forest and feathers in Space. All five are open. The crossing's
counter shows the world's currency with its icon. The shop shows every
balance at the top right. Shelly (a bog turtle) and the Night dice moved to
brooches, with new Moss dice, so each currency has two to five things to buy.
The brooch and feather icons are hand-drawn pixel art (`art/bog/brooch.png`,
`art/space/feather.png`).

Not touched: `content/levels.json` (Phase 1) and the save code (Phase 4).
Earnings use the save's existing `currencies` field through `Store.add`.

## Left for later phases

- Music for the four worlds still on the Lava songs: Phase 3, unless the songs
  arrive sooner.
- Ellwynn has no lines yet for the miniboss rules (for example "Look fast!"
  spoken): Phase 3.
- The sprout stars and sapling stars stay closed: Phase 6 decides what grade
  stars become.
- Boss tuning so aim matters less is Phase 2's job; these boards pass the
  same gates as the Lava board, so Phase 2 tunes five boards instead of one.
