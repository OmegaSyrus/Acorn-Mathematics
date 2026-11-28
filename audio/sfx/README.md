# Sound effects

The game's sounds are played by id (`Beeper.play("gem")`, `game/beeper.gd`).

- **`audio/sfx/builtin/`**: the built-in sounds. Made by `tools/sfx/make_sfx.py`
  (synthesized from noise, sweeps and decaying partials; no samples, no
  third-party audio, nothing to license). Rerun it to remake them:
  `python3 -I tools/sfx/make_sfx.py` (or `... make_sfx.py roll gem` for some).
- **`audio/sfx/`** (this folder): drop-in replacements. A file named by the id
  replaces the built-in sound, e.g. `audio/sfx/win.mp3`. Several takes of one sound:
  `roll.ogg`, `roll_2.ogg`, `roll_3.ogg` (one is picked at random, never the same
  twice running). When an id has any file here, all its built-in takes are
  replaced. `.ogg`, `.wav` and `.mp3` all work; upper or lower case doesn't matter.
  Keep them short, mono and quiet at the start (no silence before the sound).

Rebuild the APK after adding a file.

## The ids

| id | takes | what it is | where it plays |
| --- | --- | --- | --- |
| `roll` | 3 | two dice tumbling in a wooden tray | every dice roll (`Beeper.roll()`) |
| `hop` | 3 | a soft cartoon spring up | the dragon hops (not wired yet) |
| `land` | 2 | a padded landing on stone | the dragon lands (not wired yet) |
| `stone_pick` | 2 | a bright wooden tick | a stone is chosen; shop tabs and items |
| `tap` | 1 | a soft button pop | buttons: difficulty, level, toggles, PIN keys, Back |
| `nope` | 1 | a low muted knock | a button with nothing else to pick |
| `sink` | 1 | a wobbly gulp and two bubble pops | a wrong stone, the slime sinks (`Beeper.blorp()`) |
| `chest_open` | 1 | a creak, a clunk, a little shimmer | a chest opens |
| `gem` | 1 | a crystal chime (C6; climbs per gem) | each gem from a chest (`Beeper.gems(n)`) |
| `coin` | 1 | a small bright clink (climbs per gem) | each gem poured into the boss bucket |
| `bucket` | 1 | a wooden thunk with gems clattering | the boss bucket starts filling |
| `heart` | 1 | a sparkling run up and a warm swell | a heart picked up |
| `heart_land` | 1 | a soft pop and a warm ding | the heart lands in the row |
| `block` | 2 | a round shield clang | a shield blocks, a shield bash |
| `hit` | 2 | a friendly padded bonk | a hit (not wired yet) |
| `poof` | 1 | a puff of smoke and a sparkle | a monster beaten (not wired yet) |
| `win` | 1 | a bright jingle up to a held chord | a level or boss won (not wired yet) |
| `good` | 1 | three quick rising notes | right answers (`Beeper.good()`) |
| `wrong` | 1 | two soft notes stepping down, never a buzz | `Beeper.bad()`; can't buy yet |
| `door` | 1 | a creak, a breath of air, a rising shimmer | the fight door (not wired yet) |
| `peg` | 4 | a small glassy tok | the boss ball bounces off a wall or bumper |
| `peg_mod` | 1 | a quick twinkle up | the ball goes through a +1 / -1 peg |
| `whiff` | 1 | a faint airy whoosh | the ball ghosts through a peg |
| `launch` | 1 | a springy thwip | the boss ball is launched (not wired yet) |
| `buy` | 1 | coins clink, then a ta-da | bought something in the shop (not wired yet) |
| `select` | 1 | a bright little ding | an item picked in the shop |
| `crack` | 1 | small brittle snaps over a thunk | a shield cracks; a heart breaks |
| `miss` | 1 | a swish of air | a swing misses |
| `peek` | 1 | a tiny glint | a die peeks |
| `lantern` | 1 | a soft puff | the lantern goes out |
| `reveal` | 1 | a rising shwing | a hidden space shows what it holds |
| `count` | 1 | one marimba note, A4 | counting: climbs a major scale per number (`Beeper.count(n)`), boss peg pops |
| `mallet` | 1 | a soft mallet note, A4 | any other `Beeper.tone(freq, ...)`, at that pitch |
| `warble` | 1 | a falling, wobbling note | the last boss heart, time slows (`Beeper.warble()`) |

A replacement for `count`, `gem`, `coin` or `mallet` should be one clear note at
the pitch named above (A4 = 440 Hz, C6 = 1046 Hz): the game plays it higher for
each number or gem.

"Not wired yet" means the sound is ready but no screen plays it yet.
