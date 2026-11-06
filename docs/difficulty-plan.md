# Difficulty plan v4: levels world by world, more dice, more stones

Status: plan (2026-11-06, v4). Nothing below is built yet except the store fix noted at
the end. History: v1 (2026-11-05) was checked by a Fable review and against the existing
plans (design doc v0.19, the 2026-10-29 review, the repo content), which gave v2; four
Opus reviews gave v3 (their notes are in `docs/plan-reviews/`); Terrence answered v3's
questions on 2026-11-06, which gives this version (section 9).

Asked for by Terrence after the 0.11.0 tablet test: his 4.5 year old had no trouble with
today's Acorn crossing (two dice, add or take away, answers 1 to 5, five stones), so the
game needs harder levels, more dice, more stones (zoom out or scroll sideways), named by
age, and six or more levels in each world. On 2026-11-06 he added: **levels get harder
from world to world.**

Labels used below: **[built]** is in the repo today, **[decided]** is settled in the
design doc v0.19 or by Terrence, **[proposal]** is new in this plan.

## Summary

- **Each world has its own six levels, and each world picks up where the one before
  left off**: Lava Caves is the easiest, Space the hardest. 30 levels in all, named by
  world and number (Lava 1 to Lava 6, Crystal 1 to 6, Bog 1 to 6, Mushroom 1 to 6,
  Space 1 to 6), each tagged with its age band (Acorn, Sprout, Sapling, Oak) as the
  parent's hint. [decided structure, proposal for the levels]
- **Lava 1 is today's crossing** [built]. **Lava 2 is the son's next step**: two dice,
  answers to 8, 8 stones, 46 spaces (about 11 moves). [decided]
- **Each world's idea fits its math**: Lava adds and takes away with two dice, then a
  third; the Crystal Mines count along the rails to 18 and make ten; the Bog takes away
  and hides a die; the Mushroom Forest adds four dice in pairs and takes away across ten;
  Space numbers its track by place and starts times with equal dice.
- **Worlds open as v0.19 says**: beating a world's boss at any of its levels opens the
  next world, and every level of an open world is open, with marks. [decided]
- **Stones**: Lava 1 stays at today's 1x view. Every other level shows the crossing at
  half size, smoothed (filtered), with the stones spread to fill the screen. Levels whose
  stones run past the screen edge add **drag to scroll**, with landmark stones.
  [decided: smoothing]
- **Generator v1.2**: answer first, then a sign pattern that can make it, then the dice;
  new kinds for the hidden die, equal dice and mixed rolls. Lava 1 keeps today's draw
  exactly.
- **Crossings are about 13 moves** (Lava 2 about 11; Space at most 99 spaces). Always 5
  chests, and **treasure grows with the level**: 2 to 4 per chest at levels 1 and 2 of a
  world, 3 to 5 at levels 3 and 4, 4 to 6 at levels 5 and 6.
- **Fights use the level's own question** from Lava 2 up; Lava 1 keeps today's one die
  fight; the old Sprout, Sapling and Oak fight rules stay for the graybox. [decided]
- **Bolt's colors**: the store sells red, black, green, purple and pink for the robot
  dragon, recolored in code, priced in gems. [decided idea, proposal for prices]
- **Save v2**: level ids are world x 10 + level (Lava 1 = 11, the old Acorn id 1
  migrates to it). The graybox grades 2 to 4 stay.

## 1. The levels

### 1.1 Names, bands and ids

- **Name**: the world's short name and a number, 1 to 6: "Lava 1" ... "Space 6". The map
  shows the name big, and under it the band tag ("Acorn", "Sprout", "Sapling", "Oak") in
  the band's color with the age hint for the parent ("age 5").
- **Bands** stay the parent's guide to age: Acorn 4 to 5, Sprout 5 to 6, Sapling 6 to 7,
  Oak 7 to 8. A world can hold two bands (the Bog moves from Sprout to Sapling).
- **Ids**: world x 10 + level. Lava 11 to 16, Crystal Mines 21 to 26, the Bog 31 to 36,
  Mushroom Forest 41 to 46, Space 51 to 56. Lava 1 is 11, as in v3.

### 1.2 How a child moves through

- **Inside a world every level is open** [decided], each with its cleared mark. A
  parent starts the child at the level that fits; the game never changes it by itself.
- **The next world opens when the world's boss is beaten at any of its levels**
  [decided, v0.19]. The boss run is played at the level the child picked.
- **A child who outgrows Lava** plays Lava 5 or 6, beats Fafnir's Bones there, and the
  Crystal Mines open with all six levels. To reach harder math they go world by world,
  one boss at a time (whether a parent may open a later world directly is in "Still
  open").
- **Each step is small.** One new thing per level: a bigger range, one more die, a red
  die, a new way of reading the stones, or a hidden die. The first level of each world
  is a short step from the last level of the world before.

### 1.3 The 30 levels: math and view

Signs: `+` is a plain die added, `-` is a red die taken away; red dice sit at the right
end. "Stones" is how many numbered stones are offered (fewer near the far shore).
"Step" is the screen distance between stones (section 3.2). "Hidden" means one die lies
face down and the stone to pick is its face (the tray shows the total as a numeral).

**Lava Caves: add and take away with two dice, then a third** (Acorn)

| Level | Age | Dice and signs | Answers | Stones | View, step | New at this level |
|---|---|---|---|---|---|---|
| Lava 1 [built] | 4 | `++` or `+-` | 1 to 5 | 5 | 1x, 120 | today's crossing |
| Lava 2 | 4 to 5 | `++`, `+-` | 1 to 8 (red: 1 to 5) | 8 | half, 82 | sums to 8, counting on |
| Lava 3 | 4 to 5 | `++`, `+-` | 1 to 10 | 10 | half, 66 | within ten; landmark 5 and 10 |
| Lava 4 | 5 | `++`, `+-` | 1 to 12 | 12 | half, 60 | every two dice total; drag on 4:3 |
| Lava 5 | 5 | `+++` | 3 to 9 | 9 | half, 73 | a third die, small sums |
| Lava 6 | 5 | `+++` | 3 to 11 | 11 | half, 60 | three dice to 11 |

**Crystal Mines: count along the rails to 18 and make ten** (Sprout). On every Crystal
level only stone 1, the landmarks (5, 10, 15) and the far shore carry a number; the
stops between are blank rail stops (rail markers).

| Level | Age | Dice and signs | Answers | Stones | View, step | New at this level |
|---|---|---|---|---|---|---|
| Crystal 1 | 5 | `+++` | 3 to 11 | 11 | half, 60 | rail markers: count on from 1, 5, 10 |
| Crystal 2 | 5 | `+++` | 3 to 14 | 14 | half, 60, drag | past the screen edge |
| Crystal 3 | 5 | `+++` | 3 to 18 | 18 | half, 60, drag | every three dice total |
| Crystal 4 | 5 to 6 | `+++`, ten pair | 3 to 18 | 18 | half, 60, drag | make ten (6 + 4 + 3), half the time it fits |
| Crystal 5 | 5 to 6 | `++-` | 1 to 11 | 11 | half, 60 | a red third die |
| Crystal 6 | 5 to 6 | `+++`, `++-`, ten pair | 1 to 18 | 18 | half, 60, drag | add or take away, to 18 |

**The Bog: the bog takes away and hides a die** (Sprout, then Sapling). Every stone is
numbered again.

| Level | Age | Dice and signs | Answers | Stones | View, step | New at this level |
|---|---|---|---|---|---|---|
| Bog 1 | 6 | `+++`, `++-`, red preferred | 1 to 18 | 18 | half, 60, drag | the bog takes away: red 2 in 3 when either fits |
| Bog 2 | 6 | `+++`, `++-`, `+--`, red preferred | 1 to 18 | 18 | half, 60, drag | two red dice (answers 1 to 4) |
| Bog 3 | 6 | `++`, second die hidden | 1 to 6 | 6 | half, 110 | the missing die: `[4] + [?] = 9` |
| Bog 4 | 6 | `++` or `+-`, second die hidden | 1 to 6 | 6 | half, 110 | a hidden red die: `[6] - [?] = 2` |
| Bog 5 | 6 to 7 | `+++`, any die hidden | 1 to 6 | 6 | half, 110 | missing among three, total to 18 |
| Bog 6 | 6 to 7 | `++-`, any die hidden | 1 to 6 | 6 | half, 110 | missing among three with a red die |

**Mushroom Forest: four dice in pairs, then take away across ten** (Sapling, then Oak)

| Level | Age | Dice and signs | Answers | Stones | View, step | New at this level |
|---|---|---|---|---|---|---|
| Mushroom 1 | 6 to 7 | `++++`, pairs | 4 to 20 | 20 | half, 60, drag | four dice; the first two a double half the time it fits |
| Mushroom 2 | 6 to 7 | `++++`, `+++-`, pairs | 1 to 20 | 20 | half, 60, drag | a red die among four |
| Mushroom 3 | 7 | `++++`, `+++-`, `++--`, pairs | 1 to 20 | 20 | half, 60, drag | two red dice among four |
| Mushroom 4 | 7 | `++++`, any die hidden | 1 to 6 | 6 | half, 110 | missing among four, total to 24 |
| Mushroom 5 | 7 | `++-`, `+++-`, across ten | 5 to 9 | 9 | half, 73 | take away across ten: the plain dice make 11 or more |
| Mushroom 6 | 7 to 8 | `++-`, `+++-`, `++--`, across ten | 1 to 9 | 9 | half, 73 | across ten with two red dice |

**Space: the star track, within 20, and the start of times** (Oak). On every Space level
the star stones show their place on the track, not how far away they are (section 2).

| Level | Age | Dice and signs | Answers | Stones | View, step | New at this level |
|---|---|---|---|---|---|---|
| Space 1 | 7 | every three and four dice pattern | 1 to 20 | 20 | half, 60, drag | track places: "on 23, the dice make 7, find 30" |
| Space 2 | 7 | `+++-`, any die hidden | 1 to 6 | 6 | half, 110 | missing among four with a red die |
| Space 3 | 7 to 8 | two or three equal dice | 2, 3, 4, 6, 8, 9, 10, 12, 15, 18 | 18 | half, 60, drag | equal groups: three 4s make 12 |
| Space 4 | 7 to 8 | two to four equal dice | as Space 3, plus 16 and 20 | 20 | half, 60, drag | four equal groups |
| Space 5 | 8 | three or four dice, all equal but the last | 4 to 15 | 15 | half, 60, drag | groups and one more: 4 + 4 + 4 + 3 |
| Space 6 | 8 | each roll one of Space 1, 2 or 5 | 1 to 20 | 20 | half, 60, drag | Fenrir's chase: everything mixed |

Space 3 to 6 go past v0.19's "within 20" toward its "times later" with dice only (equal
dice are repeated adding). [proposal; see "Still open"]

### 1.4 What each pattern can make, and the tells

| Pattern | Smallest | Largest | Notes |
|---|---|---|---|
| `++` | 2 | 12 | as a hidden pair (Bog 3, 4) the total is 2 to 12 and the answer 1 to 6 |
| `+-` | 1 | 5 | hidden red (Bog 4): 1 to 5 |
| `+++` | 3 | 18 | |
| `++-` | 1 | 11 | across ten: 5 to 9 only |
| `+--` | 1 | 4 | |
| `++++` | 4 | 24 | |
| `+++-` | 1 | 17 | across ten: 5 to 9 only |
| `++--` | 1 | 10 | across ten: 1 to 9 |

Tells that come from real math and are kept (the spec states them):

- Lava 1 to 4: answer 1 always has a red die; answers above 5 never do. The share of
  rolls with a red die falls as the range grows: 50 percent at Lava 1, 37.5 at Lava 2,
  30 at Lava 3, 25 at Lava 4.
- Lava 5, 6, Crystal 1 to 4, Mushroom 1: stones below the number of dice are never right
  mid-crossing (three dice make at least 3).
- Crystal 6, Bog 1 and 2: answers 12 to 18 are always all plain. Mushroom 2 and 3,
  Space 1: answers 18 to 20 are always all plain.
- Mushroom 5: stones 1 to 4 are never right mid-crossing (one red die takes at most 6
  from 11 or more). Mushroom 6: answers 1 to 4 always come as `++--`.
- Space 3 and 4: only products are right (5, 7, 11, 13, 14, 17, 19 never are).

### 1.5 One crossing at each level

Length is chosen so a perfect player's expected number of moves is about 13, worked out
exactly from the answer draw (including the short moves near the shore). Lava 2 is 46
by decision (about 11 moves). Space crossings stop at 99 spaces so every track place has
at most two digits. Monsters: 3 under 70 spaces, 4 from 70. Chests: always 5.

| Level | Mean answer | Length | Moves | Monsters | Chest | Fight swing | Fight top | Boss rule |
|---|---|---|---|---|---|---|---|---|
| Lava 1 | 3.25 | 40 [built] | 12.9 | 3 | 2 to 4 | one die, pick its numeral [built] | 6 | match 1 to 3 [built] |
| Lava 2 | 4.50 | 46 | 11.3 | 3 | 2 to 4 | Lava 2 question | 8 | match 1 to 3 |
| Lava 3 | 5.50 | 65 | 13.1 | 3 | 3 to 5 | Lava 3 question | 10 | match 1 to 6 |
| Lava 4 | 6.50 | 75 | 12.9 | 4 | 3 to 5 | Lava 4 question | 12 | match 1 to 6 |
| Lava 5 | 6.00 | 73 | 13.0 | 4 | 4 to 6 | three dice, 3 to 9 | 9 | match 1 to 6 |
| Lava 6 | 7.00 | 84 | 13.0 | 4 | 4 to 6 | three dice, 3 to 11 | 11 | match 1 to 6 |
| Crystal 1 | 7.00 | 84 | 13.0 | 4 | 2 to 4 | three dice, 3 to 11 | 11 | sum |
| Crystal 2 | 8.50 | 101 | 13.0 | 4 | 2 to 4 | three dice | 12 | sum |
| Crystal 3 | 10.50 | 123 | 13.0 | 4 | 3 to 5 | three dice | 12 | sum |
| Crystal 4 | 10.50 | 123 | 13.0 | 4 | 3 to 5 | three dice, ten pairs | 12 | sum |
| Crystal 5 | 6.00 | 70 | 13.0 | 4 | 4 to 6 | `++-` | 11 | sum |
| Crystal 6 | 9.50 | 107 | 13.0 | 4 | 4 to 6 | Crystal 6 question | 12 | sum |
| Bog 1 | 9.50 | 107 | 13.0 | 4 | 2 to 4 | Bog 1 question | 12 | sum |
| Bog 2 | 9.50 | 107 | 13.0 | 4 | 2 to 4 | Bog 2 question | 12 | sum |
| Bog 3 | 3.50 | 43 | 13.1 | 3 | 3 to 5 | missing die (die and target) | 12 | sum |
| Bog 4 | 3.50 | 43 | 13.1 | 3 | 3 to 5 | missing die, plain or red | 12 | sum |
| Bog 5 | 3.50 | 43 | 13.1 | 3 | 4 to 6 | missing among three | 12 | sum |
| Bog 6 | 3.50 | 43 | 13.1 | 3 | 4 to 6 | missing among three, red | 12 | sum |
| Mushroom 1 | 12.00 | 140 | 13.0 | 4 | 2 to 4 | four dice | 12 | sum |
| Mushroom 2 | 10.50 | 117 | 13.0 | 4 | 2 to 4 | four dice, one red | 12 | sum |
| Mushroom 3 | 10.50 | 117 | 13.0 | 4 | 3 to 5 | four dice, two red | 12 | sum |
| Mushroom 4 | 3.50 | 43 | 13.1 | 3 | 3 to 5 | missing among four | 12 | sum |
| Mushroom 5 | 7.00 | 85 | 13.1 | 4 | 4 to 6 | across ten | 9 | difference |
| Mushroom 6 | 5.00 | 59 | 13.0 | 3 | 4 to 6 | across ten | 9 | difference |
| Space 1 | 10.50 | 99 (cap) | 11.3 | 4 | 2 to 4 | Space 1 question | 12 | difference |
| Space 2 | 3.50 | 43 | 13.1 | 3 | 2 to 4 | missing among four, red | 12 | difference |
| Space 3 | 8.70 | 99 (cap) | 12.9 | 4 | 3 to 5 | equal dice | 12 | difference |
| Space 4 | 10.25 | 99 (cap) | 11.3 | 4 | 3 to 5 | equal dice | 12 | difference |
| Space 5 | 9.50 | 99 (cap) | 11.6 | 4 | 4 to 6 | groups and one more | 12 | difference |
| Space 6 | 8.67 | 90 | 13.0 | 4 | 4 to 6 | mixed | 12 | difference |

- **Fight swing** [decided: fights use the level's question]: from Lava 2 up a monster
  swings with a problem from the level's own generator, answer at most the fight top,
  and the child taps one of four shields (dots up to 6, two dice side by side for 7 to
  12, as v0.19 says). Lava 1 keeps today's one die fight (dots, then the numeral).
  Hearts and near misses as today [built].
- **Duel** [decided]: the same swing, answered with big numerals; miniboss 3 hearts,
  hero 3 fresh hearts; a lost duel restarts the duel only. A lost monster fight, like a
  wrong stone, restarts the crossing (no gentle failing) [decided].
- **Boss** (Match Bounce): "match 1 to 3" is today's Acorn board [built]; "match 1 to 6"
  is a new board file with six peg faces (data only); "sum" is ball + peg = target from
  the Crystal Mines on [decided: the Sprout boss is sum]; "difference" is
  ball - peg = target for the Oak levels (v0.19). Balls and boss hearts as
  `content/bounce/tuning.json` has them: match boards 8 balls and 10 hearts, the rest 6
  balls and 12 hearts.
- **Walk time**: every walk, the wrong-stone hop-along and the door hop take
  `hop_s = clamp(3.4 / d, 0.17, 0.34)` seconds per hop for d hops: up to 10 hops keep
  today's pace and 20 hops take 3.4 s. `Beeper.count` has 14 rising tones; hops 15 to 20
  repeat the top tone (or it gets 6 more). The camera follow rate goes from 6 to 12 while
  hops are under 0.3 s.

### 1.6 How many tries a clear takes

A clear needs every move right and every monster beaten. With p the chance a child gets
one question right (the same p in fights) and 3 monsters:

| p | Clear chance (13 moves) | Tries (13 moves) | Tries (11 moves, Lava 2) |
|---|---|---|---|
| 0.95 | 0.51 | about 2 | about 1.8 |
| 0.90 | 0.25 | about 4 | about 3.4 |
| 0.85 | 0.11 | about 9 | about 7 |
| 0.80 | 0.04 | about 23 | about 16 |

A fourth monster changes this by under 1 percent. At 13 moves and 90 percent a clear
takes about 4 tries, which is what today's Lava 1 already asks (and was fine on the
tablet). A level a child gets right only 80 percent of the time is too hard; the parent
picks a lower one (no adaptive math).

## 2. The worlds

v0.19 settles the five worlds, their order, their monsters and bosses, and that a world
opens when the one before is beaten. [decided] What changes with v4 is that each world
holds its own part of the math, and each world's twist is now part of that math rather
than a flat change laid over every level. The v3 twists that no longer fit (rail
markers outside the Crystal Mines, red-heavy and doubles as world-wide modifiers) are
dropped.

**Art is separate, costed work.** Each new world needs art (four monsters, path pieces,
background, miniboss, boss kit) from paid services (PixelLab and the like); each world's
art is its own job that needs Terrence's yes. This plan needs no new art: every world's
levels can be built and tested on the Lava art first.

**1. Lava Caves** (Lava 1 to 6, Acorn)

| | |
|---|---|
| Math | two dice add and take away to 12, then a third die to 11 |
| On the path | every stone numbered; gold landmarks at 5 and 10 on the half-size levels |
| Path | stepping rocks over lava [decided, built] |
| Fall | the rock tips into the lava and the hero sinks [built] |
| Monsters | Blorp the Ember Troll, Craggy the Stone Troll, Surtlings [decided, built]; on a crossing blorp, surtling, craggy, then a second surtling as the fourth [proposal] |
| Miniboss | the Surtling Chief [built, placeholder in `logic/fight/monsters.gd`] |
| Boss | Fafnir's Bones, the Skeleton Dragon [decided, built] |
| Chests | gems [built]; v0.19 chests also give a sticker (the area run does; the crossing does not yet) |

**2. Crystal Mines** (Crystal 1 to 6, Sprout)

| | |
|---|---|
| Math | three dice to 18 on the number line, making ten, a red third die |
| On the path | **rail markers** on every level: only stone 1, landmarks 5, 10, 15 and the far shore are numbered; the stops between are blank rail stops with a small code-drawn crystal, which look and tap exactly like numbered ones. The child counts on from a marker, the skill that big three dice sums need |
| Path | minecart rails [decided]; the stones are rail stops [proposal] |
| Fall | the hero slips off the rail into the dark [decided: "off the rail"] |
| Monsters | knockers, Gem Dwarves, Svartalf lantern-bearers [decided] |
| Miniboss | the Svartalf Lantern Lord, a tall dark elf whose lantern shows the dice [decided 2026-11-06] |
| Boss | the Knocker King [decided] |
| Chests | crystals [in store.json] |

**3. The Bog** (Bog 1 to 6, Sprout then Sapling)

| | |
|---|---|
| Math | take away with one and two red dice; the missing die, plain and red, among two and three dice |
| On the path | **the bog takes away**: at Bog 1 and 2 a red die is picked 2 times in 3 when an answer can be made either way. **The bog hides a die**: at Bog 3 to 6 the hidden die sinks into the water with a few bubbles (code drawn) and comes back up showing its face after the right stone |
| Path | grassy tussocks, sunken logs, peat stepping stones [decided] |
| Fall | the hero sinks into the black water [decided: "into the bog"] |
| Monsters | wisplings, nixies, bog-draugr, Tiddy Mun [decided] |
| Miniboss | the King and Queen of the Will-o'-the-wisps [decided] |
| Boss | Jenny Greenteeth [decided] |
| Chests | **brooches**, old brooches found in the bog like real bog finds [decided 2026-11-06; new currency, code drawn icon] |

**4. Mushroom Forest** (Mushroom 1 to 6, Sapling then Oak)

| | |
|---|---|
| Math | four dice to 20 with one and two red dice, missing among four, take away across ten |
| On the path | **mushroom pairs** at Mushroom 1 to 3: when the first two dice can be a double, a coin flip makes them one and a puff of spores cheers it (code drawn). Adding four dice is easier as two pairs |
| Path | mushroom caps [decided] |
| Fall | the cap bends and the hero tumbles into the leaf litter [proposal] |
| Monsters | hobgoblins with acorn shields, pixies, boggarts [decided] |
| Miniboss | the Hedley Kow, moved up from the monster list [decided 2026-11-06] |
| Boss | the Green Man [decided] |
| Chests | leaves [store.json says "from Mossy Woods": rename the source to Mushroom Forest] |

**5. Space** (Space 1 to 6, Oak)

| | |
|---|---|
| Math | within 20 with everything, missing among four with a red die, equal dice (repeated adding, the start of times), everything mixed |
| On the path | **the star track** on every level [decided 2026-11-06]: the star stones show their place on the track (1 to the length), not how far away they are, and the hero's own star stone shows its number too. "I'm on stone 23, the dice make 7, which stone is 30?" Landmarks are places 10, 20, 30 and so on. Crossings stop at 99 |
| Path | star platforms along the branches [decided], called star stones in play (so "stars" stays the band reward) |
| Fall | the hero drifts off the star stone into the dark and floats back to the start [proposal] |
| Monsters | Fenrir's pups, Ratatoskr squirrels, moon hobgoblins [decided] |
| Miniboss | Ratatoskr himself, the great messenger squirrel; the small squirrels stay as monsters [decided 2026-11-06] |
| Boss | Fenrir [decided] |
| Chests | feathers [store.json says "from Cloud Tops": rename the source to Space] |

## 3. Stone layout: half size and drag

### 3.1 Today [built]

`game/scroll_screen.gd`: `SPACE0_X` 190, `STEP` 120, `HERO_SCREEN_X` 220, `WATER_Y` 452,
rock art 136 x 76, rock tap rect 116 x 80 (`_rock_rect`), stone numbers at font 48 in a
100 wide box, Go button 150 x 84 placed 175 above the stone (`go_offset`), Go kept
inside x 132 to 822 (`go_area`, set once per question). Stone d sits at screen
220 + 120 d, so stones 1 to 5 are x 340 to 820, inside what a 4:3 tablet shows (x 120 to
840). That is why answers stop at 5. The background strip is 1920 x 180 drawn at 3x
(5760 x 540) from world x 0; the camera clamps to 0 .. `_world_w() - 960`.

Screen sizes: the design frame is 960 x 540 and always shows 540 tall. `look.gd` names
the tablet as 1340 x 800: there one unit is about 1.48 device pixels, 100 units is
about 0.83 inch, and the screen shows about x 28 to 932. A 4:3 tablet shows only x 120
to 840; this plan uses the 4:3 width as the worst case.

### 3.2 Half size, smoothed, for every level after Lava 1

[decided 2026-11-06] The world node is drawn at scale 0.5 with
`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` (the crossing art imports get mipmaps). Pixel art
goes a little soft but does not drop rows or shimmer on the hop. **This relaxes the one
pixel grid rule in `look.gd` ("characters are never scaled") on the zoomed crossing, by
Terrence's choice**: on those levels the hero, monsters, chests and rocks are all drawn
at half size and smoothed together. Lava 1, fights, duels, the boss and every other
screen keep the one pixel grid.

All **text and touch live in an unscaled screen layer**: stone numbers, monster names,
the Go button, the choice widget, arrows. One function
`world_to_screen(w) = (w - cam_x) x zoom + (0, 244)` places them, so fonts stay sharp
and the Go button keeps today's size.

**Stones are spread to fill the screen.** The screen step between stones is
`clamp(floor(660 / min(max_answer, 11)), 60, 110)`, fixed for the whole crossing, so the
offered stones run from the hero at x 150 to about x 810:

| Most stones offered | Screen step | World step | Tap width on the 1340 x 800 tablet | Levels |
|---|---|---|---|---|
| 6 | 110 | 220 | about 23 mm | the hidden die levels |
| 8 | 82 | 164 | about 17 mm | Lava 2 |
| 9 | 73 | 146 | about 15 mm | Lava 5, Mushroom 5 and 6 |
| 10 | 66 | 132 | about 14 mm | Lava 3 |
| 11 or more | 60 | 120 | about 12.6 mm | all others |

v0.19 asks for targets "about 15 mm across (guess)". At the 60 step the stones are a
little under that; the tap areas are 86 tall (about 18 mm) and the select-then-Go pick
protects against a slipped finger. If the 60 step proves too small, the fix is to drag
earlier (cap the step at 66), not smaller stones.

| Item | On screen at half size | Note |
|---|---|---|
| Hero | x 150; sprite 93 x 115 becomes 46 x 57, x 127 to 173 | new `HERO_SCREEN_X_ZOOM` |
| Stone d | x 150 + step x d | at step 60 stone 11 is at 810, stone 12 at 870 |
| Rock art | 68 x 38 | gaps between rocks at steps above 68 |
| Tap rect | step wide, 86 tall (y 395 to 481) | covers number and rock |
| Waterline | y 470 | screen y = 244 + 0.5 x world y |
| Stone numbers | font 40 at y 455, box 140 wide | landmarks 20 percent bigger, in gold; track places to 99 fit |
| Markers | `MARKER_Y` 320 world at half size, so y 389 to 419 | clear of the numbers |
| Monsters | 192 art becomes 96 | beside the hero at +42 |
| Monster names | font 22 in the screen layer | |
| Go button | 150 x 84, centre 175 above the tap rect middle (438), so y 221 to 305 | clear of the tray (bottom 168) |
| `go_area` | the visible screen width less 12 each side | recomputed every frame |

Things that change with the half size:

- **Camera**: `cam_x` is the world x at the screen's left edge. Following the hero:
  `cam_x = hero_x - 150 / zoom`. At space 0 the hero is at world 190, so `cam_x` is
  -110: the lower clamp allows it. `world.position = (-round(cam_x x zoom), 244)`. The
  upper clamp becomes `_world_w() - visible width / zoom`.
- **World width and edges**: the strip and the start ledge are drawn tiled from world
  x -960 to `_goal_x() + 1920` (a 140 space crossing ends near world x 17,000). If the
  strip's seam shows, every other copy is drawn mirrored. No new art.
- **Above and below the strip**: at half size the strip covers screen y 244 to 514.
  Above it, `tile-wall-basalt` is tiled as a cave roof with a dark fade; below 514 the
  lava fill continues to 540. No new art.
- **Exit door**: `exit_rect` maps the door with `world_to_screen`, then grows it by
  `INCH` in screen units.

### 3.3 Drag to scroll

Used only while the stones are offered, and only when the offered stones run past the
visible right edge: at the 60 step from stone 12 on a 4:3 tablet and from stone 13 on
the 1340 x 800 tablet (so Lava 4 needs a drag only on 4:3).

- **Drag lives in the choice widget.** On drag levels the stones and the Go button act
  on release: a touch selects a stone (or presses Go) only if it started while the
  widget was active, its press was accepted by the input gate, it is the same touch
  index, and it moved less than 24 screen units (viewport units). A touch that moves 24
  or more is a drag: it moves the camera and never selects or presses Go. A touch that
  began before the widget was active (the tray flick that rolled the dice) is ignored.
- **Camera with a drag**: the drag offset is part of `_cam_target()`. The camera can
  move right until the last offered stone is at screen x 780 and left until the hero is
  back at x 150.
- **The hero can scroll off to the left** on long drags. A small "back" chevron at the
  visible left edge, y 498, appears while the hero is off screen; tapping it glides
  back. After Go the camera glides back to the hero (0.3 s) and follows the walk.
- **Selection survives a drag**: the Go button stays over its stone, clamped into the
  visible area.
- **Edge arrow**: a soft code-drawn chevron at the visible right edge minus 18, y 498,
  while offered stones are off to the right; it fades after the first drag in a
  crossing. It points at stones, never at an answer.
- **Landmarks**: distances 5, 10, 15, 20 (track places 10, 20, 30... in Space) have
  their number in gold, 20 percent bigger, with a gold ring under the rock.
- **Controller**: left and right move the highlight; the camera keeps it in view.

### 3.4 The dice tray with more dice

The tray stays `Rect2(300, 8, 390, 160)`, and its contents stay at x 670 or less so the
gem count stays clear. Signs fit their slot; "=" drops from font 72 to 56 when there are
more than two dice or a total. A level that mixes dice counts picks the layout per roll.

| Dice | Die size | Centres | Sign slots (size) | "=" at | Total numeral |
|---|---|---|---|---|---|
| 2 [built] | 96 | 370, 530 | 450 (44) | 630 (font 72) | |
| 3 | 72 | 356, 460, 564 | 408, 512 (26) | 628 | |
| 4 | 60 | 343, 429, 515, 601 | 386, 472, 558 (22) | 652 | |
| 2 with one hidden | 80 | 356, 476 | 416 | 548 | 610 |
| 3 with one hidden | 60 | 340, 426, 512 | 383, 469 | 572 | 628 |
| 4 with one hidden | 52 | 334, 410, 486, 562 | 372, 448, 524 (20) | 608 | 646 |

- **Dice faces at the new sizes**: build every skin's faces at the size in use (80, 72,
  60 and 52 are all even, so the 2 px chunks fit), draw the classic face like the plain
  skin at those sizes, and make `HALF` in `die_view.gd` a variable. The 52 px die is
  about 0.43 inch on the tablet: small but still a die; only the four-dice hidden levels
  use it.
- **Counting pips**: the pip tap radius becomes about 0.21 x the die size and a tap goes
  to the nearest pip.
- `scroll_screen.gd` makes as many `DieView`s as the roll has dice (it hard-codes 2).
- The numeral under each die still appears after the dice land. A red die has the
  take-away look in every skin [built]. The hidden die is a face-down die with a "?"
  (red if it is a take-away die); it turns over after the right stone is picked.

## 4. Generator spec v1.2 (`logic/core/move_gen.gd`, `spec/logic-spec.md` section 6)

### 4.1 Level config

```json
"move": {
  "draw": "patterns",
  "patterns": ["+++", "++-"],
  "min_answer": 1,
  "max_answer": 18,
  "constraint": "ten_pair",
  "fallback": [],
  "length": 107
}
```

- `draw` is one of:
  - `"op_first"`: Lava 1 only, today's v1.1 draw; its config keeps `ops`, `max_answer` 5
    and `die_max` 6 unchanged.
  - `"patterns"`: answer first, then a pattern, then the dice (section 4.2).
  - `"hidden"`: one die face down; `options` lists `[pattern, slot]` pairs, slot
    `"last"` or `"any"`.
  - `"equal"`: all dice equal; `counts` lists the dice counts (Space 3: [2, 3]).
  - `"equal_plus_one"`: all dice equal but the last; `counts` [3, 4].
  - `"mix"`: `parts` lists level ids whose configs are drawn from, one per roll.
- The number of dice comes from the pattern.
- `constraint`: `"none"`, `"ten_pair"`, `"pairs"` (Mushroom 1 to 3), `"red_heavy"` (Bog
  1 and 2), `"across_ten"`. These are now level settings, not world twists.
- `fallback`: patterns added when no answer fits the room left (section 4.2 step 4):
  `["++-"]` for three plain dice, `["+++-"]` for Mushroom 1, `["++--"]` for Mushroom 5,
  `["++", "+-"]` for the equal levels.
- `generate_move(level, rng, room)`. Rail markers and track places are screen only.

### 4.2 The draw

`randi(lo, hi)` is today's inclusive range (`lo + next_u32() % (hi - lo + 1)`); it uses
one rng call even when `lo == hi`. When calls happen is part of the spec:

- every `randi` written below is called, even over a range of one value;
- **the last die of a group takes what is left, with no call**;
- **picking from a list with one entry takes it, with no call**.

`can_make(p, a)`: with `k` plain and `j` red dice in `p`, if `j == 0` then
`k <= a <= 6k` (and never under `across_ten`). If `j > 0`, let `lo = max(j, k - a)` (and
also `11 - a` under `across_ten`) and `hi = min(6j, 6k - a)`: `p` can make `a` exactly
when `lo <= hi`.

**`patterns`:**

1. `m = min(max_answer, room)`.
2. `pats` = the level's patterns. Under `red_heavy` each pattern with a red die is
   listed twice (the copy right after the original).
3. `A` = every answer from `min_answer` to `m` that some `p` in `pats` can make.
4. **Near-goal rule**: if `A` is empty, add the level's `fallback` patterns and rebuild
   `A` from 1. This happens only in the last one or two moves of a crossing.
5. `answer` = the one entry of `A`, else `A[randi(0, len(A) - 1)]`.
6. `P` = the entries of `pats` that can make `answer`; `p` by the list rule
   (`P[randi(0, len(P) - 1)]` when there are two or more).
7. If `j > 0`, the red total `M = randi(lo, hi)` from `can_make` (always called, as
   v1.1 does), else `M = 0`. The plain total is `S = answer + M`.
8. Plain dice, left to right:
   - `ten_pair`: if `k >= 2` and `S - 10` can be made by the other `k - 2` plain dice, a
     coin `randi(0, 1)`; on 1 the first die is `randi(4, 6)` and the second 10 minus it.
   - `pairs`: `X` = the faces x with `S - 2x` makeable by the other `k - 2` dice. If `X`
     is not empty, a coin `randi(0, 1)`; on 1 both first dice are x, from `X` by the
     list rule.
   - The remaining plain dice split what is left of `S`: each but the last is
     `randi(max(1, rest - 6 x left), min(6, rest - left))`; the last takes the rest.
9. Red dice split `M` the same way.
10. Return `{kind: "move", grade: level id, op: "sub" if j > 0 else "add", signs: p,
    dice: plain then red, answer, choices: [1..m], answer_index: answer - 1}`.

**`hidden`:** expand `options` (slot `any` becomes one option per die place). An option
can make answer `a` when the hidden die is plain, or when it is red and
`a <= 6k - j`. `A` = answers 1 to `min(6, m)` that some option can make; `answer` and
the option are picked by steps 5 and 6. The other dice are drawn left to right, each
`randi(1, 6)`; if the result (with the hidden die set to the answer) is below 1, all of
them are drawn again in the same order until it is 1 or more. The result adds
`hidden: place` and `total` (the result, shown as a numeral). The hidden die's face is
the answer, so the stone to pick is that face.

**`equal`:** `A` = every `n x f` up to `m` with n in `counts` and f from 1 to 6 (empty
means the fallback); `answer` by step 5; `n` from the counts that divide it with
`answer / n <= 6`, by the list rule; every die is `answer / n`.

**`equal_plus_one`:** options are every (n, f, g) in that order with n in `counts`, f
and g from 1 to 6, g not f, and `(n - 1) f + g` up to `max_answer`. `A` = their values up
to `m`; `answer` by step 5; the option by the list rule; dice are f repeated n - 1 times,
then g.

**`mix`:** `part = randi(0, len(parts) - 1)`, then that part's draw with this crossing's
room. Space 6 mixes Space 1, 2 and 5.

**Lava 1 stays byte for byte.** `op_first` is v1.1 unchanged and returns exactly v1.1's
keys (no `signs`), so `test_scroll_run` keeps matching. For two dice, steps 7 to 9 draw
the same dice with the same calls as v1.1 for the same op and answer, so only the order
of op and answer differs, and only for the new levels.

**A finding about v1.1**: section 6 says the answer is drawn first "so every distance is
equally likely", but the code draws the op first. At Lava 1 stone 1 is right 10 percent
of the time and stones 2 to 5 22.5 percent each. Kept for Lava 1 [decided: Acorn 1
unchanged]; the spec text is corrected and the new levels are even.

### 4.3 Bias that is stated, not fixed

- Uniform answers make faces uneven: answer 3 from three dice is always 1 + 1 + 1. The
  fuzz tests must not assert even faces.
- The pattern follows the answer (the tells in section 1.4).
- The red total `M` is drawn evenly over its range, then split.
- The ten pair cannot show for 17 or 18.

### 4.4 Tests (Godot and the Python reference)

- **Vectors**: `tests/vectors/scroll.json` and new `tests/vectors/moves_v12.json` with
  every level and rooms 1 to max + 3. Regenerating the Lava 1 vectors may change only
  the grade id (1 to 11); a one-off diff in the PR shows that.
- **Fuzz** (every level, rooms 1 to 25, many seeds): every die is 1 to 6;
  `len(dice) == len(signs)`; signs from the level's patterns, or the fallback only when
  step 4 applied; the dice read left to right equal the answer (or the total, with the
  hidden die set to the answer) and never go below 1 on the way; the answer is in 1 to
  `m` and in `A`; `choices` is 1 to `m`; constraints hold (ten pair adds to 10 when used,
  across ten has plain total 11 or more and answer 9 or less, equal dice are equal).
- **Evenness**: a fixed sample (seeds 1 to 12,000, room 99, one draw each) per level:
  every reachable answer appears and counts pass a chi-square test at 1 percent
  (`mix` levels test each part).
- **Two dice property**: for every op and answer up to 5, steps 7 to 9 give the same
  dice as v1.1 from the same rng state, with the same number of calls.
- **Lengths**: the exact expected-moves calculation (`E[0] = 0`,
  `E[r] = 1 + sum of P(a | r) E[r - a]`) gives 12.5 to 13.5 for every level's length;
  Lava 2 (46) 11 to 11.5; capped Space levels at least 11.
- **Bots**: a perfect bot clears every level; a random bot clears a crossing less than
  1 time in 10,000.

## 5. Screen code checklist (`game/scroll_screen.gd` unless named)

- Zoom per level, smoothed; `world_to_screen`; world position rounded; camera clamps,
  `_world_w` and the drag offset in `_cam_target()`.
- Screen layer for stone numbers (font 40, box 140), landmark numbers, monster names,
  the Go button and the stone choice widget, with rects recomputed every frame.
- Step per level; tap rects; markers at `MARKER_Y` 320 world when zoomed.
- Strip and start ledge tiled from world -960; cave roof above the strip; lava below.
- `exit_rect` through `world_to_screen`, grown by `INCH` in screen units.
- Drag in `game/ui/choice_widget.gd`: act on release on drag levels, gate and touch
  index, 24 viewport units, a drag never selects or presses Go.
- Edge arrow and back chevron at the visible edges, y 498; camera glide back; controller
  scroll.
- Rail markers (Crystal Mines) and track places (Space, with the hero's own star stone)
  from the level's world.
- Tray layouts for 2 to 4 dice and the hidden die; as many `DieView`s as dice; faces
  built at size, `HALF` a variable, pip tap radius by size and nearest pip
  (`die_view.gd`, `dice_draw.gd`, `dice_skins.gd`); the sinking die in the Bog; the
  spore puff on a Mushroom double.
- `hop_s` for every walk; camera follow rate 12 on fast hops.
- Fall per world (rock tips, slip off rail, sink in water, cap bends, drift off a star
  stone), code driven on existing art until the world's art exists.
- Bolt's color applied wherever the hero is drawn (section 6.5).
- `tools/touch_check` and `tools/stills` at a half-size level and with a drag; the demo
  bot (`tools/demo/`) can drag before tapping an off-screen stone.

## 6. Content and save

### 6.1 `content/grades.json` (version 2)

```json
{
  "version": 2,
  "bands": [
    {"key": "acorn", "name": "Acorn", "age": "4 to 5"},
    {"key": "sprout", "name": "Sprout", "age": "5 to 6"},
    {"key": "sapling", "name": "Sapling", "age": "6 to 7"},
    {"key": "oak", "name": "Oak", "age": "7 to 8"}
  ],
  "grades": [
    {
      "id": 12, "world": "lava_caves", "level": 2, "name": "Lava 2",
      "band": "acorn", "age": "4 to 5", "available": true,
      "move": {"draw": "patterns", "patterns": ["++", "+-"], "min_answer": 1,
               "max_answer": 8, "constraint": "none", "fallback": [], "length": 46},
      "view": {"zoom": 0.5, "landmarks": [5]},
      "chest": [2, 4],
      "fight": {"kind": "move", "max": 8},
      "boss": "match_3"
    }
  ]
}
```

- **Lava 1** (id 11) keeps its old fields (`rule`, `dice`, `choices`, `min_choice`,
  `max_choice`, and `move` with `ops`, `max_answer`, `die_max`) so the graybox area run
  and the old vectors still work; it adds `world`, `length` 40, `view` 1x, `chest`
  [2, 4], `fight: {"kind": "one_die", "max": 6}`, `boss: "match_3"`.
- **The graybox grades 2, 3 and 4 stay** with their ids and fields (`rule` sum, missing,
  difference), named "Sprout (graybox)" and so on, with no `world`. `ProblemGen`,
  `AreaRun`, `tools/ref/make_vectors.py`, `problems.json` and `replays.json` use them.
- `available` false hides a level until its milestone (section 8).
- `fight.kind`: `one_die` (Lava 1), `move` (all new levels; hidden levels swing die and
  target), and the old kinds `two_dice`, `die_and_target`, `move_and_slip` for the
  graybox grades [decided: kept].
- `boss`: `match_3`, `match_6`, `sum`, `difference`; `content/bounce/tuning.json` keys
  its rules by these names (`bounce_fight.gd` reads `tuning["grades"][str(grade)]`
  today).

### 6.2 Area files, one per crossing

```json
{
  "version": 2,
  "id": "lava_scroll", "type": "scroll", "world": "lava_caves",
  "grades": [11, 12, 13, 14, 15, 16],
  "layout": {
    "chests": [100, 325, 450, 675, 775],
    "monsters_3": [225, 550, 875],
    "monsters_4": [200, 400, 625, 875],
    "monsters": ["blorp", "surtling", "craggy", "surtling"]
  },
  "max_length": null
}
```

- An area lists its world's six levels. The length comes from the level, capped by the
  area's `max_length` (99 for Space areas). The chest amounts come from the level
  (`chest`), so `chest_gems` leaves the area file; the currency comes from the world.
- Event spaces are placed by thousandths of the length: `at = (length x p + 500) div
  1000`, integers only. 3 monsters under 70 spaces, 4 from 70. At length 40 this gives
  exactly today's spaces (chests 4, 13, 18, 27, 31; monsters 9, 22, 35); a content test
  asserts it.
- Old area files with an explicit `spaces` list still load (that list wins).
- The graybox area files `lava_1.json` and `lava_1_fights.json` get `"grades": [11, 2]`.
- Content tests: every event space is distinct and between 1 and length - 1, for every
  level of every area.
- Files: `lava_scroll.json` now; later three crossings per world (`crystal_rails_1.json`,
  `bog_1.json`, `mushroom_1.json`, `space_1.json`...).

### 6.3 Level ids and save migration

- Ids = world x 10 + level (section 1.1). The graybox ids 2 to 4 stay.
- `SaveData.VERSION` goes from 1 to 2. `from_text` reads the version first (missing
  means 1) and migrates **before** it fills defaults: on a version 1 save it maps grade
  id 1 to 11 in `marks` and in `run.grade`, leaves 2 to 4 alone, adds `paint`
  ("classic", section 6.5) and sets version 2. On a version 2 save it changes nothing.
- **The run remembers its length.** `ScrollRun.to_save` adds `length` (a save without it
  means 40). If it differs from what the level and area give now, the saved run is
  dropped and the map offers a fresh start; marks and gems stay.
- A kept test save from version 1 (a mark and a mid-run save at Lava 1) must load as
  version 2 and resume the same roll.
- `spec/logic-spec.md` sections 2 (grades) and 5 (save) are updated with this.

### 6.4 Fights (`logic/fight/attack_gen.gd` and friends)

- `generate(rng, level)` switches on `level.fight.kind`, not on the `Grade` enum.
- `one_die` and the three old kinds: today's paths, unchanged.
- `move`: `MoveGen.generate_move(level, rng, level.fight.max)`. Near misses: first tier
  answer plus or minus 1 and each shown die (and the total for a hidden die); second
  tier plus or minus 2 and, with a red die, the plain total; filler plus or minus 3.
  Choices 1 to `fight.max`; near misses above it are dropped. The answer's place among
  the four is still drawn first.
- `max_value(level)` = `fight.max`. The numeral choice style in `fight.gd` is keyed on
  `one_die` instead of the Acorn grade.
- `Fight`, `Duel`, `logic/fight/chest.gd`, `game/fight/fight_screen.gd`,
  `game/bounce/bounce_screen.gd`, `logic/bounce/bounce_fight.gd` and
  `tools/demo/find_seed.gd` take the level id; `game/scroll_screen.gd` passes it. The
  fight screen learns to show two to four dice, a red die, a hidden die and shields up
  to 12.
- `tests/fight/ref/fight_ref.py` and `tests/fight/vectors/fights.json` follow.
- Fuzz: four distinct choices in range, exactly one right; a random tapper loses a 3
  heart fight about 9 times in 10.

### 6.5 Treasure, currencies, stars and the store

**Treasure grows with the level** [decided idea, proposal for the numbers]. Every world
uses the same table for its own currency:

| Level in the world | Per chest | Per clear (5 chests, average) | One clear of each level |
|---|---|---|---|
| 1 and 2 | 2 to 4 | 15 | 30 |
| 3 and 4 | 3 to 5 | 20 | 40 |
| 5 and 6 | 4 to 6 | 25 | 50 |
| world total | | | about 120 |

Lava 1 keeps 2 to 4, so its vectors and the store test "about three crossings for the
slime" hold. At Lava 5 or 6 the slime takes about 2 clears.

**Currencies by world**: Lava gems [built], Crystal Mines crystals, the Bog **brooches**
[decided], Mushroom Forest leaves, Space feathers. In `content/store.json`: leaves
`from` "Mossy Woods" becomes "Mushroom Forest", feathers `from` "Cloud Tops" becomes
"Space", and `brooches` is added (closed). Each currency opens when its world ships.

**Bolt's colors** [decided idea, proposal for prices]. The robot dragon (Bolt, today's
steel blue-grey with teal lights) can be painted red, black, green, purple or pink.

- **How**: a code recolor at load time, no paid art. The sprite has 39 colors; the
  body's blue-grey ramp is mapped to the new color's ramp by keeping each pixel's
  brightness and setting its hue and saturation; the near-black outline and the teal
  eye lights stay. Black uses a dark ramp with a light rim so the outline still reads.
  Each paint is a few numbers in store.json (`hue`, `sat`, `value_scale`).
- **Store**: a new item kind `paint`, shown as a "Bolt's colors" row in the heroes tab:
  six small Bolts (classic plus the five). Classic is owned from the start. A bought
  paint is equipped like a dice skin, and shows on Bolt everywhere the hero is drawn
  (crossing, fights, boss, store), by way of `Look.hero_texture()`. It applies only
  while Bolt is the hero; other heroes are unchanged. Save: `paint` (default
  "classic").
- **Prices, in gems** (so Lava has more to buy after the slime): red 25, green 25,
  black 35, purple 45, pink 45. All five cost 175; with the 40 gem slime, the gem shop
  is 215, about two rounds of the six Lava levels (about 120 each), or fewer for a child
  who replays the later Lava levels.

**Does every shop still make sense** with the treasure table (about 120 per world
round)?

| Currency | Items (price) | Total | Rounds of the world |
|---|---|---|---|
| gems | Sir Blob 40, five paints 175 | 215 | about 2 |
| crystals | steel 20, Pip 50, blue gem 40, night 30 | 140 | about 1.2 |
| brooches | Shelly the turtle 30 (moved from crystals); no new dice skins (Terrence 2026-11-06) | 30 | under 1 (more Bog items later) |
| leaves | mint 15, Spike 30, Nutkin 40, green gem 40, Rusty 50 | 175 | about 1.5 |
| feathers | sky 15, pink 25, Talon 30, Griff 50 | 120 | about 1 |

The cheapest item in each currency takes one or two clears, the dearest about a round.

**Stars**: the first clear of an area at a level gives one star of the level's band:
Sprout levels (Crystal 1 to 6, Bog 1 and 2) a Sprout star, Sapling levels (Bog 3 to 6,
Mushroom 1 to 4) a Sapling star, Oak levels a Sapling star until Oak items exist; Acorn
levels give treasure and the mark only. With one area per world that is 8 Sprout stars
(Leo 3 and Sir Tam 5; the gold dice 4 need a second area) and 8 Sapling stars (Blaze 5
and the purple gem 3). `sprout_stars` opens with Crystal 1, `sapling_stars` with Bog 3.

### 6.6 Map

The world map shows the open worlds; an area shows its world's six levels as two rows of
three buttons (160 x 96, x 220 to 740, inside a 4:3 screen), each with the level name,
the band tag and age, and its cleared mark. Every level of an open world is open
[decided]. A parent lock comes with the parent area (v0.19). The saved run's Go button
stays.

## 7. Files that change

| File | Change |
|---|---|
| `content/grades.json` | version 2: 30 levels by world, Lava 1 as id 11, graybox 2 to 4 kept |
| `logic/core/grades.gd`, `logic/core/content.gd` | level ids, names, world and band of a level; `Grade` enum kept for the graybox |
| `logic/core/move_gen.gd` | v1.2: patterns, hidden, equal, equal plus one, mix, `can_make`, constraints, fallback |
| `tools/ref/move_gen.py`, `common.py`, `generator.py`, `make_vectors.py`, `scroll_run.py` | Python reference and new vectors |
| `spec/logic-spec.md` sections 2, 5 and 6 | grades v2, save v2, spec v1.2, layout by thousandths, the v1.1 evenness correction |
| `logic/path/scroll_run.gd` | length and chest amounts from the level, spaces from the layout, `max_length`, `length` in the save |
| `logic/core/save_data.gd` | VERSION 2, migration before defaults, `paint` |
| `logic/core/store.gd`, `game/store_screen.gd`, `game/ui/look.gd` | `paint` items, Bolt's colors row, recolor in `hero_texture()` |
| `logic/fight/attack_gen.gd`, `attack.gd`, `fight.gd`, `duel.gd`, `chest.gd` | fights by level |
| `game/fight/fight_screen.gd` | level id; two to four dice, red and hidden dice, shields to 12 |
| `content/bounce/tuning.json`, `logic/bounce/bounce_rules.gd`, `logic/bounce/bounce_fight.gd`, `game/bounce/bounce_screen.gd` | rules keyed by boss rule name; `match_6` board file |
| `content/areas/lava_scroll.json`, `lava_1.json`, `lava_1_fights.json` | version 2 layout and levels; graybox `grades` lists |
| `content/store.json` | currency sources renamed, `brooches`, Shelly to brooches, five paints, stars opened per milestone |
| `game/scroll_screen.gd` | everything in section 5 |
| `game/ui/choice_widget.gd` | screen layer, act on release on drag levels, drag never picks |
| `game/ui/die_view.gd`, `dice_draw.gd`, `dice_skins.gd` | faces at 80, 72, 60 and 52; `HALF` variable; pip radius; face-down "?" die |
| `game/map_screen.gd`, `game/main.gd` | world map, six level buttons per area, marks per level, level ids |
| `tests/`, `tests/fight/ref/fight_ref.py`, `tests/fight/vectors/fights.json` | vectors, fuzz, evenness, exact length check, save migration, fight fuzz, store paints, bots |
| `tools/demo/`, `tools/demo/find_seed.gd`, `tools/touch_check`, `tools/stills` | level ids, drag then tap, half-size checks |
| crossing art `.import` files | mipmaps on, for the smoothed half size |

## 8. Milestones

Each milestone ends with the tests green, an APK in the project folder and a short video,
as before. Nothing goes on the tablet without Terrence. A level's `available` is switched
on only in the milestone that builds its screen.

1. **Levels, generator v1.2 and plumbing** (nothing changes on screen): grades.json v2
   with all 30 levels as data and only Lava 1 available; move_gen v1.2; Python
   reference; spec sections 2, 5 and 6; vectors; exact length test; area layout; save
   v2; fights by level and the level id passed through fight, duel, bounce and the demo
   tools. Store currency renames and `brooches` (closed), data only. Lava 1 plays
   exactly as today.
2. **Lava 2 on the tablet, the build for Terrence's son**: smoothed half size, screen
   layer for text and the stone widget, hero at 150, step 82, 46 space crossing,
   landmark 5, hop speed, fight screen with two dice, the red die and shields to 8. The
   map shows Lava 1 and Lava 2.
3. **Lava 3 and 4, and the level picker**: landmarks 5 and 10, chest amounts by level,
   drag to scroll with the edge arrow and back chevron (Lava 4 on 4:3), the `match_6`
   board and the bounce tuning keyed by rule name, two rows of level buttons.
4. **Lava 5 and 6, and Bolt's colors**: three dice in the tray at 72, the fallback red
   die; the paint items, recolor and store row. Lava is complete with six levels: the
   Lava Caves fun gate.
5. **Crystal Mines** (logic and screen on Lava art first; its own art after Terrence's
   yes to that job): rail markers, ten pairs, three dice to 18, crystals and Sprout stars
   open.
6. **The Bog**: red preferred, two red dice, the hidden die (sinking) at three sizes;
   brooches open, Shelly; Sapling stars open.
7. **Mushroom Forest**: four dice at 60, pairs and the spore puff, missing among four
   (52 px), across ten; leaves open.
8. **Space**: track places with the hero's own number, the 99 cap, equal dice, groups
   and one more, the mixed level; feathers open.

## 9. Decisions (2026-11-06)

Terrence's answers to v3's questions:

1. **Levels get harder from world to world.** Each world has its own six levels and picks
   up where the one before left off; Lava is easiest, Space hardest (section 1).
2. **Half size is smoothed** (filtered world). The one pixel grid rule is relaxed on the
   zoomed crossing (section 3.2).
3. **Lava 2** (v3's Acorn 2): answers to 8, 46 spaces, about 11 moves. Lava 1 unchanged.
4. **Fights from Lava 2 up use the level's own question.**
5. **The old approved Sprout, Sapling and Oak fight rules are kept** (graybox grades).
6. **The Sprout boss rule is "sum".**
7. **The missing die comes before four dice** (the Bog before the Mushroom Forest).
8. **Every level of an open world is open, with marks.**
9. **Space numbers its stones by place on the track**: "on stone 23, the dice make 7,
   find stone 30" (crossings there stop at 99).
10. **Names and store**: the Bog's currency is **brooches** (bog finds); the minibosses
    are the Svartalf Lantern Lord (Crystal Mines), the Hedley Kow (Mushroom Forest) and
    Ratatoskr (Space); instead of gem-priced dice skins, the store sells **Bolt's
    colors** (red, black, green, purple, pink); **treasure grows with the level**.

### Still open

1. **Shortcut for an older child**: to reach Space math a child must beat four bosses.
   Should the parent area be able to open a later world directly? (Plan: no for now;
   the parent area is not built yet.)
2. **Space 3 to 6 start times with equal dice** ("three 4s make 12"), past v0.19's
   "within 20". Keep them, or keep Space within 20 (more mixed and hidden rolls)?
3. **Prices**: Bolt's colors at 25 to 45 gems, and the treasure table (2 to 4, 3 to 5,
   4 to 6 by level in each world). Do they feel right?
4. **The Bog has four missing-die levels in a row** (Bog 3 to 6). Fine as the Bog's
   theme, or move one (for example Bog 6) into the Mushroom Forest?

## 10. Where this differs from the Fable review

The Fable review's fixes are adopted where they still apply: a gentle Lava 2 (to 8, 8
stones); honest take away; make ten inside the Sprout band; half size with the hero at
150; the zoom fixes (start offset, camera clamp, Go button, drag slop, tray width);
answer first then a reachable pattern; red dice last; Lava 1's draw order kept; uneven
faces stated; lengths computed; 3 or 4 monsters; fights by level; save version bump.
Differences:

- **Thirty levels in five worlds of six**, not six plus a bonus, by Terrence's
  2026-11-06 answer.
- **Stones never right mid-crossing stay** where the math makes them so (three dice
  cannot make 1 or 2); the fallback is used only when the room left is too small.
- **No ten-frame under the dice** in the Mushroom Forest: it comes close to showing the
  total, which the no-hints rule avoids. Doubles live there as pairs instead.
- **Half size is not called pixel-exact**: on the 1340 x 800 tablet it cannot be, and
  Terrence chose smoothing.
- **Lengths** are worked out exactly (expected moves), not "13 x mean".
- **New finding**: v1.1's "answer drawn first" claim is wrong for Lava 1 (op first;
  stone 1 is right 10 percent of the time). Kept for the vectors, spec text fixed.

## 11. Review responses (items not taken, or taken differently)

From the Opus reviews of v2 (`docs/plan-reviews/`):

- Levels 7 (Acorn 4 boss "match 1 to 6" is an anticlimax): kept; "sum" is a missing
  addend and starts with the Crystal Mines (Sprout), as v0.19 says.
- Worlds 2 (track places on every tenth stone at the young levels): moot; Space is now
  the hardest world and uses track places at every level (decided).
- Worlds 3 (Leo unbuyable): with v4's stars, Crystal 1 to 3 give the 3 Sprout stars for
  Leo, so the currency can open with Crystal 1.
- Worlds 12 (rename the band stars): "Sprout stars" stays; Space's platforms are called
  star stones.
- Layout 11 (`ui_scale` in the choice widget): replaced by moving the widget and all text
  to an unscaled screen layer.
- Generator 3 (keep ids 2 to 4 as graybox grades): taken as written.

## Store check (2026-11-05)

On branch `claude/project-thread-ielg89` (PR #12, which holds the shop from PR #11):
the headless suite runs 70 tests and all pass, including the 10 store tests (catalog,
only the slime buyable at 40 gems, about three crossings to afford it, buy and equip,
locked currencies, old saves, red take-away die in every skin).

One bug found in the game layer and fixed here: chest gems went into the save when the
chest opened on screen, but the run (with that chest marked opened) was only written at
the end of the turn. Leaving through the menu during the walk and pressing Go on the map
replayed the same move and opened the same chest again, so gems could be doubled. The
walk's gems and the run are now written together before the walk plays, and the counter
still climbs as each chest opens (`game/scroll_screen.gd`, `gems_unshown`).
