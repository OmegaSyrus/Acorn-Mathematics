# Difficulty plan v3: levels by age, more dice, more stones, five worlds

Status: plan for review (2026-11-05, v3). Nothing below is built yet except the store fix
noted at the end. v1 of this plan was checked by a Fable review and against the existing
plans (design doc v0.19, the 2026-10-29 review, the repo content), which gave v2. v2 was
then checked by four Opus reviews (levels, worlds, generator and content, layout); this
version fixes every must-fix item and takes most optional ones. Section 10 lists where
this plan differs from the Fable review, section 11 the review items not taken.

Asked for by Terrence after the 0.11.0 tablet test: his 4.5 year old had no trouble with
today's Acorn crossing (two dice, add or take away, answers 1 to 5, five stones), so the
game needs harder levels, more dice, more stones (zoom out or scroll sideways), named by
age (Acorn 1, Acorn 2...), and six or more levels for each world.

Labels used below: **[built]** is in the repo today, **[decided]** is settled in the
design doc v0.19 or by Terrence, **[proposal]** is new in this plan and needs a yes.
Defaults chosen for Terrence's calls are marked **(default)** and listed in section 9.

## Summary

- **One ladder of 12 levels**, played in every world: Acorn 1 to 4 (age 4 to 5, two
  dice), Sprout 1 to 3 (5 to 6, three dice), Sapling 1 to 3 (6 to 7, missing die and four
  dice), Oak 1 and 2 (7 to 8). Oak 3 (times) is a placeholder. The age is a hint for the
  parent; the parent picks the level and the game never changes it by itself.
- **Every world has all 12 levels** plus a small **world twist** on the path that changes
  how the same level feels, not what it asks: Lava plain, Crystal Mines count from rail
  markers, the Bog prefers red dice, Mushroom Forest prefers doubles, Space numbers the
  track (from Sapling 2 up). Fights, duels and bosses are the same in every world.
- **The very next step for Terrence's son is Acorn 2**: still two dice, answers up to 8
  (take away still up to 5), 8 stones on screen, a slightly shorter crossing (46 spaces,
  about 11 moves) (default). It ships first.
- **Stones**: Acorn 1 stays at today's 1x view. Every other level shows the crossing at
  half size, with the stones spread to fill the screen (about 11 stones at most on a 4:3
  tablet). How the half size is drawn (filtered world or half-size art) is Terrence's
  call. Levels whose stones run past the screen edge add **drag to scroll**, with
  landmark stones at 5, 10, 15 and 20.
- **Generator v1.2**: answer first, then a sign pattern that can make it, then the dice.
  Acorn 1 keeps today's draw exactly, so its vectors keep the same dice.
- **Crossing length is computed** so a clean run is about 13 moves (Acorn 2 about 11).
  Always 5 chests; 3 monsters on crossings under 70 spaces, 4 from 70 up.
- **Fights use the level's own question** from Acorn 2 up (choices up to the level's
  top answer, at most 12); Acorn 1 keeps today's one die fight. The miniboss duel asks
  the same with numerals. The boss rule is mapped per level.
- **Save v2**: new level ids are band x 10 + level (Acorn 1 = 11); only id 1 migrates.
  The old graybox grades 2 to 4 stay as they are.

## 1. The ladder

### 1.1 Why this order

- **Acorn 1 to Acorn 2 is a small step on purpose.** Today every answer is 5 or less, so
  the dice are small and most sums can be seen at a glance. Acorn 2 keeps two dice and
  the same signs but lets sums reach 8 and shows 8 stones: counting on starts, guessing
  drops from 1 in 5 to 1 in 8. Acorn 3 goes to 10 (the "within ten" milestone), Acorn 4
  to every two dice total (12).
- **Take away stays honest.** One red die can only make answers 1 to 5 (6 - 1 at most),
  so at Acorn 2 to 4 a red die always means a stone from 1 to 5. As the plain answers
  grow, the share of rolls with a red die falls: 50 percent at Acorn 1, 37.5 at Acorn 2,
  30 at Acorn 3, 25 at Acorn 4. That is stated, not fixed; the Bog raises it.
- **A third die before bigger numbers.** Sprout 1 adds a third die with answers up to 11,
  so the only new thing is adding in two steps. Sprout 2 makes the third die red.
  Sprout 3 opens answers to 18 and makes ten: when a ten pair fits, half the time two of
  the dice show it (6 + 4 + 3). Sprout 3 has one red die at most; two red dice are new
  at Sapling 3.
- **The missing die comes as Sapling 1, with small numbers.** v0.19 puts "the missing
  number" at Sapling. The 10-29 review found a missing addend harder than take away,
  which this order keeps (take away is learned from Acorn 1). Keeping its answers to 1 to
  6 makes the missing die the only new thing at that level.
- **Four dice and two red dice** are Sapling 2 and 3: answers to 20, the full number
  line with landmarks.
- **Oak** is the within 20 band: the missing die among three dice and take aways that
  cross ten. Times and share (v0.19 "later") are Oak 3 and beyond, not planned here.
- **Doubles** are not a Lava level: they are the Mushroom Forest twist, so every level
  can be played with doubles there. The v1 "doubles cheer" moves there.
- **No gentle failing** at any level: one wrong stone sinks the hero and the crossing
  starts again; a lost monster fight does the same; a lost miniboss duel restarts only
  the duel. [decided]

### 1.2 The levels: math and view

Signs: `+` is a plain die added, `-` is a red die taken away. Red dice always sit at the
right end, so reading left to right never goes below 1. "Stones" is how many numbered
stones are offered (fewer near the far shore). "Step" is the screen distance between
stones (section 3.2).

| Level | Age hint | Dice | Sign patterns | Answers | Stones | View, step | Constraint |
|---|---|---|---|---|---|---|---|
| **Acorn 1** [built] | 4 | 2 | `++` or `+-` | 1 to 5 | 5 | 1x, 120 | none (today's draw) |
| **Acorn 2** | 4 to 5 | 2 | `++`, `+-` | 1 to 8 (red: 1 to 5) | 8 | half, 82 | none |
| **Acorn 3** | 4 to 5 | 2 | `++`, `+-` | 1 to 10 (red: 1 to 5) | 10 | half, 66 | none |
| **Acorn 4** | 5 | 2 | `++`, `+-` | 1 to 12 (red: 1 to 5) | 12 | half, 60, drag on 4:3 | none |
| **Sprout 1** | 5 | 3 | `+++` | 3 to 11 | 11 | half, 60 | near the shore the last die turns red |
| **Sprout 2** | 5 to 6 | 3 | `++-` | 1 to 11 | 11 | half, 60 | none |
| **Sprout 3** | 6 | 3 | `+++`, `++-` | 1 to 18 | 18 | half, 60, drag | ten pair half the time it fits |
| **Sapling 1** | 6 | 2 | `++`, one die hidden | 1 to 6 | 6 | half, 110 | missing die: `[4] + [?] = 9` |
| **Sapling 2** | 6 to 7 | 4 | `++++`, `+++-` | 1 to 20 | 20 | half, 60, drag | none |
| **Sapling 3** | 7 | 4 | `++++`, `+++-`, `++--` | 1 to 20 | 20 | half, 60, drag | none |
| **Oak 1** | 7 | 3 | `+++`, any one hidden | 1 to 6 | 6 | half, 110 | missing die among three, total to 18 |
| **Oak 2** | 7 to 8 | 3 or 4 | `++-`, `+++-`, `++--` | 1 to 9 | 9 | half, 73 | across ten: the plain dice make 11 or more |
| Oak 3 | 8 | | | | | | times and share, later (placeholder) |

What each pattern can make (the generator checks this exactly, section 4.2):

| Pattern | Smallest | Largest | Used at |
|---|---|---|---|
| `++` | 2 | 12 | Acorn 1 to 4; Sapling 1 (there 2 to 12 is the shown total; the answer is the hidden die, 1 to 6) |
| `+-` | 1 | 5 | Acorn 1 to 4 |
| `+++` | 3 | 18 | Sprout 1, Sprout 3; Oak 1 (shown total; the answer is the hidden die, 1 to 6) |
| `++-` | 1 | 11 | Sprout 2, Sprout 3; Oak 2 (only 5 to 9 when crossing ten) |
| `++++` | 4 | 24 | Sapling 2, Sapling 3 |
| `+++-` | 1 | 17 | Sapling 2, Sapling 3; Oak 2 (only 5 to 9 when crossing ten) |
| `++--` | 1 | 10 | Sapling 3; Oak 2 (1 to 9) |

Tells that come from real math and are kept (the spec states them):

- Acorn: answer 1 always has a red die; answers above 5 never do.
- Sprout 1: stones 1 and 2 are never right mid-crossing (three dice make at least 3).
- Sprout 3: answers 12 to 18 are always all plain.
- Sapling 2 and 3: answers 18 to 20 are always all plain.
- Oak 2: answers 1 to 4 always come as four dice with two red (`++--`), since one red
  die can take at most 6 from a plain total of 11 or more.

### 1.3 The levels: one crossing

Mean answer is the answer's average with room to spare. Length is chosen so the
expected number of moves of a perfect player is about 13 (worked out exactly from the
answer draw, including the shorter answers near the shore; the plain "13 x mean" rule
over-counts because the last moves are short, so the real ratio is 10 to 12.3).
"Fight top" is the largest choice a fight shows.

| Level | Mean answer | Length | Moves | Monsters | Chests | Fight swing | Fight top | Boss rule |
|---|---|---|---|---|---|---|---|---|
| Acorn 1 | 3.25 | 40 [built] | 12.9 | 3 | 5 | one die, pick its numeral [built] | 6 | match 1 to 3 [built] |
| Acorn 2 | 4.50 | 46 (default) | 11.3 | 3 | 5 | Acorn 2 question | 8 | match 1 to 3 |
| Acorn 3 | 5.50 | 65 | 13.1 | 3 | 5 | Acorn 3 question | 10 | match 1 to 6 |
| Acorn 4 | 6.50 | 75 | 12.9 | 4 | 5 | Acorn 4 question | 12 | match 1 to 6 |
| Sprout 1 | 7.00 | 84 | 13.0 | 4 | 5 | three dice, 3 to 11 | 11 | sum (default) |
| Sprout 2 | 6.00 | 70 | 13.0 | 4 | 5 | `++-`, 1 to 11 | 11 | sum (default) |
| Sprout 3 | 9.50 | 107 | 13.0 | 4 | 5 | Sprout 3 question | 12 | sum (default) |
| Sapling 1 | 3.50 | 43 | 13.1 | 3 | 5 | missing die (die and target) | 12 | sum |
| Sapling 2 | 10.50 | 117 | 13.0 | 4 | 5 | four dice | 12 | sum |
| Sapling 3 | 10.50 | 117 | 13.0 | 4 | 5 | two red dice | 12 | sum |
| Oak 1 | 3.50 | 43 | 13.1 | 3 | 5 | missing die among three | 12 | difference |
| Oak 2 | 5.00 | 59 | 13.0 | 3 | 5 | across ten | 9 | difference |

- **Acorn 2 at 46 spaces** (default) is about 11 moves, a gentler first run of the new
  numbers; 54 spaces would make it 13 like the rest (section 9).
- **Monsters**: 3 when the crossing is under 70 spaces, 4 from 70 up. Chests stay 5 at 2
  to 4 gems, so a clear banks about 15 gems at every level and the 40 gem slime price
  holds.
- **Fight swing** (section 6.4): from Acorn 2 up a monster swings with a problem from the
  level's own generator, answer at most the fight top, and the child taps one of four
  shields (dots up to 6, two dice side by side for 7 to 12, as v0.19 says). Acorn 1 keeps
  today's one die fight (dots, then pick the numeral) and its vectors. Hearts and near
  misses as today [built]. This makes Acorn 2 fights harder than today's (section 9).
- **Duel** [decided: every miniboss uses the duel]: the same swing, answered with big
  numerals; miniboss 3 hearts, hero 3 fresh hearts; a lost duel restarts the duel only.
- **Boss** (Match Bounce) [proposal for the mapping]: "match 1 to 3" is today's Acorn
  board; "match 1 to 6" is a new board file with six peg faces (data only); "sum" is
  ball + peg = target, which is a missing addend (v0.19 puts it at Sprout and Sapling;
  at Sprout it previews Sapling 1's missing die) (default); "difference" is
  ball - peg = target (v0.19 Oak). Balls and boss hearts as `content/bounce/tuning.json`
  has them now: match levels 8 balls and 10 hearts, the rest 6 balls and 12 hearts.
- **Walk time**: every walk, including the wrong-stone hop-along and the door hop, takes
  `hop_s = clamp(3.4 / d, 0.17, 0.34)` seconds per hop for d hops: up to 10 hops keep
  today's pace and a 20 hop walk takes 3.4 s, not 6.8 s. `Beeper.count` has 14 rising
  tones; hops 15 to 20 repeat the top tone (or it gets 6 more, cheap). The camera follow
  rate goes from 6 to 12 while hops are under 0.3 s so it does not trail the hero.

### 1.4 How many tries a clear takes

A clear needs every move right and every monster beaten. With p the chance a child gets
one question right (the same p in fights), about 13 moves and 3 monsters:

| p | Clear chance (13 moves) | Tries (13 moves) | Tries (Acorn 2, 11 moves) |
|---|---|---|---|
| 0.95 | 0.51 | about 2 | about 1.8 |
| 0.90 | 0.25 | about 4 | about 3.4 |
| 0.85 | 0.11 | about 9 | about 7 |
| 0.80 | 0.04 | about 23 | about 16 |

A fourth monster changes this by under 1 percent. v0.19's target is 1 to 3 tries at
about 90 percent per task; at 13 moves that is about 4 tries, which is what today's
Acorn 1 already asks (and was fine on the tablet). A level a child gets right 80 percent
of the time is too hard for them; the parent picks a lower one (no adaptive math).

## 2. Worlds: one ladder, five twists

### 2.1 The structure

v0.19 settles that math is separate from content: "the same areas, monsters and bosses
can be replayed at a harder grade", a world opens when the previous boss is beaten at
any grade, and the map shows each area's marks per grade. [decided]

This plan keeps that and answers "six or more levels for each world" like this
(default; Terrence may have meant a ladder that climbs world by world, section 9):

- **Every world offers the whole ladder** (12 levels, Acorn 1 to Oak 2). A child at
  Acorn 1 can reach Space at Acorn 1; an older child can play the Lava Caves at Sapling 3.
  A ladder that climbs world by world (Lava = Acorn, Crystal Mines = Sprout...) was not
  chosen: a 4 year old could never open world 2, and v0.19 wants the same worlds
  replayed harder.
- **Each world has one twist on the path** [proposal]: a change in how the stones are
  labelled or how the dice are drawn that keeps the level's answers, length and
  difficulty close to the Lava version. Twists apply to crossings only; fights, the duel
  and the boss are the same in every world. Twists never change the fail rule or add
  hints.
- **A world ships when at least six levels are playable in it** (Acorn 1 to 4 and
  Sprout 1 and 2 at the least) and gets the rest as they are built. The 10-29 review's
  rule holds: no world 2 until the Lava Caves fun gate passes.
- **Areas**: v0.19 has three areas per world, then the boss run. Each area is a crossing
  file; all three use the world's twist and every level. Today the Lava Caves has one
  crossing (`lava_scroll`). [decided structure, built in part]
- **Art is separate, costed work.** Each new world needs art (four monsters, path
  pieces, background, miniboss, boss kit) from paid services (PixelLab and the like).
  Each world's art is its own job that needs Terrence's yes. This plan needs no new art:
  every twist can be built and tested on the Lava art first (a blank rail stop is a rock
  without a number plus a small code-drawn crystal).

### 2.2 The twists at each level

| Level | Lava Caves | Crystal Mines | The Bog | Mushroom Forest | Space |
|---|---|---|---|---|---|
| Acorn 1 | every stone numbered | numbers on 1 and 5 only | red die 2 in 3 rolls | doubles when they fit (1+1, 2+2) | plain |
| Acorn 2 | plain | 1 and 5 | red 2 in 3 when either fits (about 46 percent of rolls) | doubles to 4+4 | plain |
| Acorn 3 | plain | 1, 5, 10 | red 2 in 3 when either fits | doubles to 5+5 | plain |
| Acorn 4 | plain | 1, 5, 10 | red 2 in 3 when either fits | doubles to 6+6 | plain |
| Sprout 1 | plain | 1, 5, 10 | off (no red die) | first two dice a double | plain |
| Sprout 2 | plain | 1, 5, 10 | no effect (every roll has a red die) | first two dice a double | plain |
| Sprout 3 | plain | 1, 5, 10, 15 | red 2 in 3 when either fits | doubles when no ten pair | plain |
| Sapling 1 | plain | 1, 5 | off (hidden die) | off (hidden die) | plain |
| Sapling 2 | plain | 1, 5, 10, 15, 20 | red 2 in 3 when either fits | first two dice a double | star track, capped at 99 |
| Sapling 3 | plain | 1, 5, 10, 15, 20 | red 2 in 3 when either fits | first two dice a double | star track, capped at 99 |
| Oak 1 | plain | 1, 5 | off (hidden die) | off (hidden die) | star track |
| Oak 2 | plain | 1, 5 | no effect (every roll has a red die) | first two dice a double | star track |

How each twist works:

- **Lava Caves, plain.** Every offered stone shows how far away it is. The home world and
  the reference for every number in this plan.
- **Crystal Mines, rail markers.** Only stone 1, the landmark stones (5, 10, 15, 20) and
  the far shore carry a number; the stones between are blank rail stops with a small
  code-drawn crystal. Blank stops look and tap exactly like numbered ones. The child
  counts on from the nearest marker (number line landmarks). Screen only.
- **The Bog, the bog takes away.** When an answer can be made both with and without a
  red die, patterns with a red die count twice in the pattern draw, so the red one is
  picked 2 times in 3. Answers stay evenly spread, so crossing lengths do not change.
  At Acorn 1 (old draw order) the op list becomes add, sub, sub: about 13.3 moves for
  the 40 spaces, still in range.
- **Mushroom Forest, mushroom pairs.** When the first two plain dice can be a double,
  a coin flip makes them one, and a puff of spores cheers it (code drawn). A ten pair
  (Sprout 3) is tried first. Only the dice change; answers and lengths stay.
- **Space, star track** (from Sapling 2 up, default). The stones are called **star
  stones** here (so "stars" stays the band reward). From Sapling 2 up they carry their
  place on the track (1 to the length) instead of how far away they are, and the hero's
  own star stone shows its number, so the question becomes "I'm on 23, the dice make 7:
  which star stone is 30?" Landmarks are then track places 10, 20, 30... Space crossings
  at those levels are capped at 99 spaces so every number has at most two digits; that
  makes Sapling 2 and 3 about 11.3 moves. Below Sapling 2, Space is plain: adding to a
  two-digit place is a different, harder question, which a world twist should not give
  a 4 year old.

### 2.3 World by world

**1. Lava Caves** (world 1)

| | |
|---|---|
| Path | stepping rocks over lava [decided, built] |
| Fall | the rock tips into the lava and the hero sinks [built] |
| Monsters | Blorp the Ember Troll, Craggy the Stone Troll, Surtlings [decided, built] |
| Order on a crossing | blorp, surtling, craggy, and a second surtling as the fourth [proposal] |
| Miniboss | the Surtling Chief [built, placeholder in `logic/fight/monsters.gd`] |
| Boss | Fafnir's Bones, the Skeleton Dragon [decided, built] |
| Chests | gems [built]; v0.19 chests also give a sticker (the area run does; the crossing does not yet) |
| Stars | Sprout and Sapling stars from first clears (section 6.5) |
| Twist | plain |
| Levels | all 12; Acorn 1 to 4 and Sprout 1 and 2 first (milestones 1 to 4) |

**2. Crystal Mines** (world 2)

| | |
|---|---|
| Path | minecart rails [decided]; the stones are rail stops [proposal] |
| Fall | the hero slips off the rail into the dark [decided: "off the rail"] |
| Monsters | knockers, Gem Dwarves, Svartalf lantern-bearers [decided] |
| Miniboss | not chosen in v0.19. Proposal: the Svartalf Lantern Lord, a tall dark elf whose lantern shows the dice |
| Boss | the Knocker King [decided] |
| Chests | crystals [already in store.json] |
| Twist | rail markers [proposal] |
| Levels | all 12; ships with at least Acorn 1 to 4 and Sprout 1 and 2 |

**3. The Bog** (world 3)

| | |
|---|---|
| Path | grassy tussocks, sunken logs, peat stepping stones [decided] |
| Fall | the hero sinks into the black water [decided: "into the bog"] |
| Monsters | wisplings, nixies, bog-draugr, Tiddy Mun [decided] |
| Miniboss | the King and Queen of the Will-o'-the-wisps [decided] |
| Boss | Jenny Greenteeth [decided] |
| Chests | **pearls** (freshwater pearls from the pools) [proposal: new currency, code drawn icon; Shelly the turtle moves to pearls, section 6.5] |
| Twist | the bog takes away [proposal] |
| Levels | all 12; ships with at least six |

**4. Mushroom Forest** (world 4)

| | |
|---|---|
| Path | mushroom caps [decided] |
| Fall | the cap bends and the hero tumbles into the leaf litter [proposal] |
| Monsters | hobgoblins with acorn shields, pixies, boggarts [decided]; the Hedley Kow [decided as a monster] |
| Miniboss | not chosen in v0.19. Proposal: the Hedley Kow moves up from monster to miniboss and leaves the monster list (a shape changer suits a duel) |
| Boss | the Green Man [decided] |
| Chests | leaves [store.json has them as "from Mossy Woods": rename the source to Mushroom Forest] |
| Twist | mushroom pairs [proposal] |
| Levels | all 12; ships with at least six |

**5. Space** (world 5, Yggdrasil)

| | |
|---|---|
| Path | star platforms along the branches [decided], called star stones in play |
| Fall | the hero drifts off the star stone into the dark and floats back to the start [proposal] |
| Monsters | Fenrir's pups, Ratatoskr squirrels, moon hobgoblins [decided] |
| Miniboss | not chosen in v0.19. Proposal: Ratatoskr himself, the great messenger squirrel; the small Ratatoskr squirrels stay as monsters |
| Boss | Fenrir [decided] |
| Chests | feathers [store.json has them as "from Cloud Tops": rename the source to Space; the eagle at the top of Yggdrasil fits] |
| Twist | star track from Sapling 2 up, crossings there capped at 99 [proposal] |
| Levels | all 12; ships with at least six |

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

### 3.2 Half size for every level after Acorn 1

The crossing is shown at half size so more stones fit; Acorn 1 stays at 1x. On the
tablet one design unit is 1.48 device pixels, so half size is not pixel-exact on the
device whichever way it is drawn. Two ways, Terrence's call (section 9):

- **Filtered world** (default, no art work): the world node is drawn at scale 0.5 with
  `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` (the art imports get mipmaps). Pixel art goes a
  little soft but does not drop rows or shimmer on the hop. Quickest to try for the son.
- **Half-size art**: a tool script makes 2:1 copies of the crossing art (rocks, every
  store hero, monsters, chest, markers, gem) once, offline and free; the world is drawn
  at 1x with the half-size art. Exactly on the one pixel grid that `look.gd` asks for
  ("a character that has to be bigger or smaller gets art made at that size"), but
  thin lines can vanish in the copy, and every new hero needs its copy.

Either way, all **text and touch live in an unscaled screen layer**: stone numbers,
monster names, the Go button, the choice widget, arrows. One function
`world_to_screen(w) = (w - cam_x) x zoom + (0, 244)` places them, so fonts stay sharp
and the Go button keeps today's size without any scale juggling.

**Stones are spread to fill the screen.** The step between stones (on screen) is
`clamp(floor(660 / min(max_answer, 11)), 60, 110)`, fixed for the whole crossing, so the
offered stones run from the hero at x 150 to about x 810:

| Levels | Most stones offered | Screen step | World step at half size | Tap width on the 1340 x 800 tablet |
|---|---|---|---|---|
| Sapling 1, Oak 1 | 6 | 110 | 220 | about 23 mm |
| Acorn 2 | 8 | 82 | 164 | about 17 mm |
| Oak 2 | 9 | 73 | 146 | about 15 mm |
| Acorn 3 | 10 | 66 | 132 | about 14 mm |
| Acorn 4, Sprout 1 to 3, Sapling 2 and 3 | 11 or more | 60 | 120 | about 12.6 mm |

v0.19 asks for targets "about 15 mm across (guess)". At the 60 step the stones are a
little under that; the tap areas are 86 tall (about 18 mm) and the select-then-Go pick
protects against a slipped finger. If the 60 step proves too small on the tablet, the
fix is drag earlier (cap the step at 66), not smaller stones.

| Item | On screen at half size | Note |
|---|---|---|
| Hero | x 150; sprite 93 x 115 becomes 46 x 57, x 127 to 173 | new `HERO_SCREEN_X_ZOOM` |
| Stone d | x 150 + step x d | at step 60 stone 11 is at 810, stone 12 at 870 |
| Rock art | 68 x 38 | gaps between rocks at steps above 68 |
| Tap rect | step wide, 86 tall (y 395 to 481) | covers number and rock |
| Waterline | y 470 | screen y = 244 + 0.5 x world y |
| Stone numbers | font 40 at y 455, box 140 wide | "20" is about 44 wide; landmarks 20 percent bigger |
| Markers | `MARKER_Y` 320 world at half size, so y 389 to 419 | clear of the numbers (today's 348 would touch them) |
| Monsters | 192 art becomes 96 | beside the hero at +42 |
| Monster names | font 22 in the screen layer | not 11 as a scaled world would make them |
| Go button | 150 x 84, centre 175 above the tap rect middle (438), so y 221 to 305 | clear of the tray (bottom 168) |
| `go_area` | the visible screen width less 12 each side | recomputed every frame |

Things that change with the half size:

- **Camera**: `cam_x` is the world x at the screen's left edge. Following the hero:
  `cam_x = hero_x - 150 / zoom` (300 world units). At space 0 the hero is at world 190,
  so `cam_x` is -110: the lower clamp allows it. `world.position = (-round(cam_x x
  zoom), 244)`; rounding keeps the strip from shimmering. The upper clamp becomes
  `_world_w() - visible width / zoom`.
- **World width and edges**: the strip and the start ledge are drawn tiled from world
  x -960 (so a 16:9 screen has no empty strip on the left) to `_goal_x() + 1920`. If the
  strip's seam shows, every other copy is drawn mirrored. No new art.
- **Above and below the strip**: at half size the 540 tall strip covers screen y 244 to
  514. Above it, `tile-wall-basalt` is tiled as a cave roof with a dark fade; below 514
  the lava fill continues to 540 (the progress bar at y 516 sits on it). No new art.
- **Exit door**: `exit_rect` maps the door with `world_to_screen`, then grows it by
  `INCH` in screen units (today it only subtracts the camera).

### 3.3 Drag to scroll

Used only while the stones are offered, and only when the offered stones run past the
visible right edge (worked out from the viewport): at the 60 step that is from stone 12
on a 4:3 tablet and from stone 13 on the 1340 x 800 tablet, so Acorn 4 needs a drag only
on 4:3. Sprout 3 and Sapling 2 and 3 need it everywhere.

- **Drag lives in the choice widget.** On drag levels the stones and the Go button act
  on release, not on press: a touch selects a stone (or presses Go) only if it started
  while the widget was active, the press was accepted by its input gate, it is the same
  touch index, and it moved less than 24 screen units (measured in viewport units, not
  world units). A touch that moves 24 or more is a drag: it moves the camera and never
  selects or presses Go, even if it started on Go. A touch that began before the widget
  was active (for example the tray flick that rolled the dice) is ignored, so lifting a
  finger over a stone after rolling never selects it.
- **Camera with a drag**: the drag offset is part of `_cam_target()`, so the follow lerp
  does not pull it back. The camera can move right until the last offered stone is at
  screen x 780 (up to (m - 11) x 60 + 30 units) and left until the hero is back at x 150.
- **The hero can scroll off to the left** on long drags (at 20 stones the drag goes up to
  570 units, past the hero). A small "back" chevron at the visible left edge, y 498,
  appears while the hero is off screen; tapping it glides back. After Go, the camera
  glides back to the hero (0.3 s) and follows the walk.
- **Selection survives a drag**: the Go button stays over its stone, clamped into the
  visible area.
- **Edge arrow**: a soft code drawn chevron at the visible right edge minus 18, y 498
  (between the rock bottoms at 481 and the progress bar at 516), while offered stones
  are off to the right; it fades after the first drag in a crossing. It points at
  stones, never at an answer.
- **Landmark stones** (all half-size levels): stones 5, 10, 15 and 20 (track places 10,
  20, 30... on the Space star track) have their number in gold, 20 percent bigger, with
  a gold ring drawn under the rock.
- **Controller**: left and right move the highlight; the camera scrolls to keep the
  highlighted stone in view.

### 3.4 The dice tray with more dice

The tray stays `Rect2(300, 8, 390, 160)`, and its contents stay at x 670 or less so the
gem count (its icon starts near x 675 at 100 gems or more on 4:3) stays clear. Signs are
drawn at a size that fits their slot; "=" drops from font 72 to 56 when there are more
than two dice or a total.

| Dice | Die size | Centres | Sign slots (size) | "=" at | Total numeral |
|---|---|---|---|---|---|
| 2 [built] | 96 | 370, 530 | 450 (44) | 630 (font 72) | |
| 3 | 72 | 356, 460, 564 | 408, 512 (26) | 628 | |
| 4 | 60 | 343, 429, 515, 601 | 386, 472, 558 (22) | 652 | |
| 2 + hidden (Sapling 1) | 80 | 356, 476 | 416 | 548 | 610 |
| 3 + hidden (Oak 1) | 60 | 340, 426, 512 | 383, 469 | 572 | 628 |

- **Dice faces at the new sizes.** Skins are built in code in 2 px chunks at 96 px
  (`dice_skins.gd`) and the classic skin is 96 px art; drawn at 72, 64 or 60 they would
  alias. Fix: build every skin's faces at the size in use (80, 72 and 60 are all even, so
  the 2 px chunks fit), draw the classic face the same way as the plain skin at those
  sizes, and make `HALF` in `die_view.gd` a variable.
- **Counting pips**: the pip tap radius (20 today) becomes about 0.21 x the die size and
  a tap goes to the nearest pip, since at 60 px the pips are 13 units apart.
- `scroll_screen.gd` makes as many `DieView`s as the level has dice (it hard-codes 2).
- The numeral under each die still appears after the dice land. A red die is drawn with
  the take-away look in every skin [built]. The hidden die is a face-down die with a
  "?"; it turns over to show its pips after the right stone is picked.

## 4. Generator spec v1.2 (`logic/core/move_gen.gd`, `spec/logic-spec.md` section 6)

### 4.1 Level config

```json
"move": {
  "draw": "answer_first",
  "patterns": ["+++", "++-"],
  "min_answer": 1,
  "max_answer": 18,
  "constraint": "ten_pair",
  "length": 107
}
```

- `draw`: `"op_first"` (Acorn 1 only, today's v1.1 draw; its config keeps `ops`,
  `max_answer` 5 and `die_max` 6 unchanged) or `"answer_first"`.
- The number of dice comes from the pattern (Oak 2 mixes three and four dice).
- `constraint`: `"none"`, `"ten_pair"`, `"hidden"` (with `"hidden_at": "last"` or
  `"any"`), `"across_ten"`.
- `generate_move(level, rng, room, twist := "")`; `twist` is `""`, `"red_heavy"` (Bog)
  or `"pairs"` (Mushroom Forest). Rail markers and star track are screen only. Fights
  call it with no twist.

### 4.2 The draw (answer first)

`randi(lo, hi)` is today's inclusive range (`lo + next_u32() % (hi - lo + 1)`); it uses
one rng call even when `lo == hi`. The rules for when a call happens are part of the
spec, so the Python reference and the C++ port stay in step:

- every `randi` written below is called, even over a range of one value;
- **the last die of a group takes what is left, with no call**;
- **picking from a list with one entry takes it, with no call**.

`can_make(p, a)`: with `k` plain and `j` red dice in pattern `p`, if `j == 0` then
`k <= a <= 6k` (and never under `across_ten`). If `j > 0`, let
`lo = max(j, k - a)` (and also `11 - a` under `across_ten`) and `hi = min(6j, 6k - a)`:
`p` can make `a` exactly when `lo <= hi`. This is the red total's range used in step 7,
so a pattern is never picked that cannot be drawn.

1. `m = min(max_answer, room)`.
2. `pats` = the level's patterns. With `twist == "red_heavy"`, each pattern that has a
   red die is listed twice (the copy right after the original).
3. `A` = every answer `a` from `min_answer` to `m` with some `p` in `pats` where
   `can_make(p, a)`.
4. **Near-goal rule**: if `A` is empty (only on pure plain levels, when the room left is
   less than the number of dice), add the fallback pattern (the level's dice with the
   last one red, for example `++-`) and rebuild `A` from 1. This happens only in the last
   one or two moves of a Sprout 1 crossing. Every other level can always make 1.
5. `answer` = the one entry of `A`, else `A[randi(0, len(A) - 1)]` (every reachable
   distance equally likely).
6. `P` = the entries of `pats` with `can_make(p, answer)`. `p = P[0]` if `len(P) == 1`,
   else `P[randi(0, len(P) - 1)]`.
7. If `j > 0`, the red total `M = randi(lo, hi)` from `can_make` (called even when the
   range is one value, as v1.1 does), else `M = 0`. The plain total is `S = answer + M`.
8. Plain dice, left to right:
   - `ten_pair` (Sprout 3): if `k >= 2` and `S - 10` can be made by the other `k - 2`
     plain dice (for `k = 2`, `S == 10`; for `k = 3`, `S` from 11 to 16), a coin
     `randi(0, 1)`; on 1 the first die is `randi(4, 6)` and the second is 10 minus it.
   - else the `pairs` twist: `X` = the faces x with `S - 2x` makeable by the other
     `k - 2` dice. If `X` is not empty, a coin `randi(0, 1)`; on 1 both first dice are
     x, taken from `X` by the list rule.
   - The remaining plain dice split what is left of `S`: each but the last is
     `randi(max(1, rest - 6 x left), min(6, rest - left))`, where `left` is the number of
     dice still to draw after this one; the last takes the rest.
9. Red dice split `M` the same way.
10. Return `{kind: "move", grade: level id, op: "sub" if j > 0 else "add", signs: p,
    dice: plain then red, answer, choices: [1..m], answer_index: answer - 1}`. `op`
    stays so the screen code that colours the red die keeps working.

**Hidden die levels** (Sapling 1, Oak 1) skip steps 2 to 9: `answer = randi(1, min(6,
m))`; the hidden place is the last die (`hidden_at: last`) or `randi(0, n - 1)` (`any`);
each other die is `randi(1, 6)` left to right; the hidden die's face is the answer. The
result adds `hidden: index` and `total` (the sum, shown as a numeral).

**Acorn 1 stays byte for byte.** `op_first` is v1.1 unchanged and returns exactly v1.1's
keys (no `signs`), so `test_scroll_run` keeps matching. For two dice, steps 7 to 9 draw
the same dice with the same rng calls as v1.1 for the same op and answer: take away is
one call over `[1, 6 - answer]` (v1.1's `[answer + 1, 6]` has the same size) and both
dice take what is left; adding is one call over `[1, answer - 1]` for answers up to 7 and
the second die takes the rest. Only the order of op and answer differs, and only for the
new levels. Twists at Acorn 1:

- `red_heavy`: the op list is add, sub, sub (one `randi(0, 2)`); when `m < 2` it is sub
  alone, with no call, as v1.1.
- `pairs`: after `answer = randi(2, m)` for an add, if the answer is even, a coin
  `randi(0, 1)`; on 1 the first die is answer / 2 with no call, else today's
  `randi(1, answer - 1)`.

**A finding about v1.1**: section 6 says the answer is drawn first "so every distance is
equally likely", but the code draws the op first. At Acorn 1 stone 1 is right 10 percent
of the time and stones 2 to 5 22.5 percent each. That is kept for Acorn 1 (vector
stability; moving Acorn 1 to even answers is a question in section 9); the spec text is
corrected and the new levels are even.

### 4.3 Bias that is stated, not fixed

- Uniform answers make faces uneven: at Sprout 1, answer 3 is always 1 + 1 + 1. The fuzz
  tests must not assert even faces.
- The pattern follows the answer (the tells in section 1.2).
- The red total `M` is drawn evenly over its range, then split.
- The ten pair cannot show for 17 or 18 (the third die would be 7 or 8).

### 4.4 Tests (Godot and the Python reference)

- **Vectors**: `tests/vectors/scroll.json` and new `tests/vectors/moves_v12.json` with
  every level, rooms 1 to max + 3, and both twists. Regenerating the Acorn 1 vectors may
  change only the grade id (1 to 11); a one-off diff in the PR shows that.
- **Fuzz** (every level, every room 1 to 25, many seeds): every die is 1 to 6;
  `len(dice) == len(signs)`; the signs are one of the level's patterns, or the fallback
  only when step 4 applied; the dice read left to right with their signs equal the
  answer and never go below 1 on the way; the answer is in 1 to `m` and in `A`;
  `choices` is 1 to `m`; constraints hold (ten pair adds to 10 when used, hidden index in
  range and total = sum, across ten has plain total 11 or more and answer 9 or less).
- **Evenness**: a fixed sample (seeds 1 to 12,000, room 99, one draw each) per
  answer-first level: every reachable answer appears and the counts pass a chi-square
  test at 1 percent. Fixed seeds make the test pass or fail the same way every run.
- **Two dice property**: for every op and answer up to 5, answer-first steps 7 to 9 give
  the same dice as v1.1 from the same rng state, with the same number of calls.
- **Lengths**: an exact expected-moves calculation (no bots: `E[0] = 0`,
  `E[r] = 1 + sum of P(a | r) E[r - a]`) gives 12.5 to 13.5 for every level's length
  (Acorn 2 at 46: 11 to 11.5, or 12.5 to 13.5 if 54 is chosen), and at least 11 under
  the Space cap.
- **Bots**: a perfect bot clears every level in every world; a random bot clears a
  crossing less than 1 time in 10,000.

## 5. Screen code checklist (`game/scroll_screen.gd` unless named)

- Zoom per level (filtered world or half-size art); `world_to_screen`; world position
  rounded; camera clamps, `_world_w` and the drag offset in `_cam_target()`.
- Screen layer for stone numbers (font 40, box 140), landmark numbers, monster names,
  the Go button and the stone choice widget, with rects recomputed every frame.
- Step per level; tap rects; markers at `MARKER_Y` 320 world when zoomed.
- Strip and start ledge tiled from world -960; cave roof above the strip; lava below.
- `exit_rect` through `world_to_screen`, grown by `INCH` in screen units.
- Drag in `game/ui/choice_widget.gd`: act on release on drag levels, gate and touch
  index, 24 viewport units, a drag never selects or presses Go.
- Edge arrow and back chevron at the visible edges, y 498; camera glide back; controller
  scroll.
- Rail markers (number only on 1, landmarks and shore) and star track numbers (place,
  including the hero's own star stone), both from the area's `twist`.
- Tray layouts for 3 and 4 dice and the hidden die; as many `DieView`s as dice; dice
  faces built at size, `HALF` a variable, pip tap radius by size and nearest pip
  (`die_view.gd`, `dice_draw.gd`, `dice_skins.gd`).
- `hop_s` for every walk, hop-along and door hop; camera follow rate 12 on fast hops.
- Fall animation per world (rock tips, slip off rail, sink in water, cap bends, drift
  off a star stone), code driven on existing art until the world's art exists.
- `tools/touch_check` and `tools/stills` run at a half-size level and with a drag;
  the demo bot (`tools/demo/`) can drag before tapping an off-screen stone.

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
      "id": 12, "band": "acorn", "level": 2, "name": "Acorn 2", "age": "4 to 5",
      "available": true,
      "move": {"draw": "answer_first", "patterns": ["++", "+-"],
               "min_answer": 1, "max_answer": 8, "constraint": "none", "length": 46},
      "view": {"zoom": 0.5, "landmarks": [5]},
      "fight": {"kind": "move", "max": 8},
      "boss": "match_3"
    }
  ]
}
```

- **Acorn 1** (id 11) keeps its old fields (`rule`, `dice`, `choices`, `min_choice`,
  `max_choice`, and `move` with `ops`, `max_answer`, `die_max`) so the graybox area run
  and the old vectors still work; it adds `length` 40, `view` 1x,
  `fight: {"kind": "one_die", "max": 6}`, `boss: "match_3"`.
- **The old graybox grades 2, 3 and 4 stay** with their ids and fields (`rule` sum,
  missing, difference), renamed "Sprout (graybox)" and so on. `ProblemGen`, `AreaRun`,
  `tools/ref/make_vectors.py`, `problems.json` and `replays.json` use them. They are not
  listed in any crossing's `grades`, so they never show on a crossing's map.
- `available` false hides a level until it is built; it is switched on one milestone at
  a time (section 8). Oak 3 is not listed.
- `view.drag` is not stored: the screen decides from the viewport (section 3.3).
- `fight.kind`: `one_die` (Acorn 1), `move` (all new levels, including the hidden die
  levels, whose swing is die and target), and the old kinds `two_dice`,
  `die_and_target` and `move_and_slip` for the graybox grades 2 to 4 (default: kept, so
  the approved rules and `fights.json` still pass; retiring them is a question).
  `fight.max`: 6, 8, 10, 12, 11, 11, 12, 12, 12, 12, 12, 9 from Acorn 1 to Oak 2.
- `boss`: `match_3`, `match_6`, `sum`, `difference`; `content/bounce/tuning.json` keys
  its rules by these names instead of grade numbers (`bounce_fight.gd` reads
  `tuning["grades"][str(grade)]` today).

### 6.2 Area files, one per crossing

```json
{
  "version": 2,
  "id": "lava_scroll", "type": "scroll", "world": "lava_caves", "twist": "plain",
  "grades": [11, 12, 13, 14, 21, 22, 23, 31, 32, 33, 41, 42],
  "chest_gems": [2, 4],
  "layout": {
    "chests": [100, 325, 450, 675, 775],
    "monsters_3": [225, 550, 875],
    "monsters_4": [200, 400, 625, 875],
    "monsters": ["blorp", "surtling", "craggy", "surtling"]
  },
  "max_length": null
}
```

- The length comes from the level (`move.length`), capped by the area's `max_length`
  (99 in Space at the star track levels, null elsewhere).
- Event spaces are placed by thousandths of the length: `at = (length x p + 500) div
  1000`, integers only so the C++ port agrees. 3 monsters under 70 spaces, 4 from 70.
  At length 40 this gives exactly today's spaces (chests 4, 13, 18, 27, 31; monsters 9,
  22, 35), so Acorn 1 runs replay unchanged; a content test asserts it.
- Old area files with an explicit `spaces` list still load (that list wins).
- The graybox area files `lava_1.json` and `lava_1_fights.json` get `"grades": [11, 2]`
  so `main.gd` offers only those two there (with no list it would offer every level).
- Content tests: every event space is distinct, between 1 and length - 1, for every
  level of every area.
- One file per crossing: `lava_scroll.json` now, later two more Lava crossings and three
  per world (`crystal_rails_1.json`, `bog_1.json`, `mushroom_1.json`, `space_1.json`...).

### 6.3 Level ids and save migration

- New ids = band x 10 + level: Acorn 11 to 14, Sprout 21 to 23, Sapling 31 to 33, Oak
  41 to 43. The graybox ids 2 to 4 stay.
- `SaveData.VERSION` goes from 1 to 2. `from_text` reads the version first (missing
  means 1) and migrates **before** it fills defaults from `new_profile`: on a version 1
  save it maps grade id 1 to 11 in `marks` (every area) and in `run.grade`, leaves 2 to 4
  alone, and sets version 2. Running it on a version 2 save changes nothing.
- **The run remembers its length.** `ScrollRun.to_save` adds `length` (a save without it
  means 40). If a saved run's length differs from what its level and area give now
  (only if content changes a length later), the saved run is dropped and the map offers
  a fresh start; marks and gems stay. Without this, `looted` and a pending fight could
  point at spaces that moved.
- A kept test save from version 1 (a mark and a mid-run save at Acorn 1) must load as
  version 2 and resume the same roll.
- `spec/logic-spec.md` sections 2 (grades) and 5 (save) are updated with this.

### 6.4 Fights (`logic/fight/attack_gen.gd` and friends)

- `generate(rng, level)` takes the level (looked up by id in Content). It switches on
  `level.fight.kind`, not on the `Grade` enum.
- `one_die` and the three old kinds: today's paths, unchanged (fight vectors unchanged
  apart from the id 1 to 11).
- `move`: `MoveGen.generate_move(level, rng, level.fight.max)` gives dice, signs and
  answer. Near misses: first tier answer plus or minus 1 and each shown die on its own
  (and the total for a hidden die, as today's die and target); second tier plus or minus
  2 and, when there is a red die, the plain total (forgetting the take away); filler
  plus or minus 3. Choices 1 to `fight.max`; near misses above it are dropped (Oak 1
  totals can reach 18). The "where the answer sits is drawn first" rule stays.
- `max_value(level)` = `fight.max`. The choice style (numerals at Acorn 1 today, in
  `fight.gd`) is keyed on `one_die` instead of the Acorn grade.
- `Fight`, `Duel`, `logic/fight/chest.gd`, `game/fight/fight_screen.gd`,
  `game/bounce/bounce_screen.gd`, `logic/bounce/bounce_fight.gd` and
  `tools/demo/find_seed.gd` take the level id instead of the grade enum;
  `game/scroll_screen.gd` passes it to the fight. The fight screen learns to show two
  to four dice, a red take-away die and shields up to 12 (it shows two plain dice now).
- `tests/fight/ref/fight_ref.py` (its own `max_value` keyed on Acorn) and
  `tests/fight/vectors/fights.json` follow.
- Fuzz: for every level, four distinct choices in range, exactly one right; a random
  tapper loses a 3 heart fight about 9 times in 10, as today.

### 6.5 Currencies, stars and the store

- **Chest currency by world** [proposal for the names]: Lava gems [built], Crystal Mines
  crystals, the Bog pearls (new), Mushroom Forest leaves, Space feathers. Same 5 chests of
  2 to 4 at every level. How many clears the first item takes depends on its price:
  about 3 for the 40 gem slime, about 2 for 20 crystal steel dice, about 1 for 15 leaf
  mint dice.
- **Rename in `content/store.json`**: leaves `from` "Mossy Woods" to "Mushroom Forest",
  feathers `from` "Cloud Tops" to "Space"; add `pearls` (closed).
- **Give pearls something to buy** [proposal]: Shelly the turtle moves from 30 crystals
  to 30 pearls (a turtle fits a bog), and a code-drawn "Pearl" dice skin at 20 pearls.
  Crystals keep Pip, steel, blue gem and night.
- **Give gems more to buy** [proposal]: after the slime, gems buy nothing, yet one clear
  of every Lava level banks about 180. Add two or three code-drawn dice skins priced in
  gems (for example "Ember" 60, "Basalt" 80, "Lava glass" 120). Data only.
- **Stars** [proposal]: the first clear of an area at a level gives one star of that
  band: Sprout levels a Sprout star, Sapling levels a Sapling star, Oak levels a Sapling
  star until Oak items exist. Acorn levels give gems and the mark only.
- `sprout_stars` opens (`"open": true`) when **Sprout 3** ships, so Lava's three Sprout
  levels can buy Leo (3) the day the currency opens; Sir Tam (5) and the gold dice (4)
  need Sprout clears in a second area or world. `sapling_stars` opens with Sapling 1.
  Each world's currency opens when that world ships.

### 6.6 Map

From the moment four levels show (milestone 3), the grade buttons become a band row
(Acorn, Sprout, Sapling, Oak) and a row of that band's levels, each with its cleared
mark. (Today's layout puts buttons from x `480 - n x 100`, so four buttons would start
at x 100, outside a 4:3 screen.) Every level is open by default so a parent can start
the child at the right one; a parent lock comes with the parent area (v0.19). The saved
run's Go button stays.

## 7. Files that change

| File | Change |
|---|---|
| `content/grades.json` | version 2: 12 levels, Acorn 1 as id 11, graybox 2 to 4 kept (section 6.1) |
| `logic/core/grades.gd`, `logic/core/content.gd` | level ids, names, band of a level; `Grade` enum kept for the graybox |
| `logic/core/move_gen.gd` | v1.2: answer first, patterns, `can_make`, constraints, twists, hidden die |
| `tools/ref/move_gen.py`, `common.py`, `generator.py`, `make_vectors.py`, `scroll_run.py` | Python reference and new vectors |
| `spec/logic-spec.md` sections 2, 5 and 6 | grades v2, save v2, spec v1.2, layout by thousandths, the v1.1 evenness correction |
| `logic/path/scroll_run.gd` | length from the level, spaces from the layout, `max_length`, twist, `length` in the save |
| `logic/core/save_data.gd` | VERSION 2, migration before defaults |
| `logic/fight/attack_gen.gd`, `attack.gd`, `fight.gd`, `duel.gd`, `chest.gd` | fights by level (section 6.4) |
| `game/fight/fight_screen.gd` | level id; two to four dice, red die, shields to 12 |
| `content/bounce/tuning.json`, `logic/bounce/bounce_rules.gd`, `logic/bounce/bounce_fight.gd`, `game/bounce/bounce_screen.gd` | rules keyed by boss rule name; `match_6` board file |
| `content/areas/lava_scroll.json`, `lava_1.json`, `lava_1_fights.json` | version 2 layout and levels; graybox `grades` lists |
| `content/store.json` | stale currency sources renamed, `pearls` added, Shelly to pearls, new dice skins, stars opened per milestone |
| `game/scroll_screen.gd` | everything in section 5 |
| `game/ui/choice_widget.gd` | screen layer, act on release on drag levels, drag never picks |
| `game/ui/die_view.gd`, `dice_draw.gd`, `dice_skins.gd` | faces built at 80, 72 and 60; `HALF` variable; pip radius; face-down "?" die |
| `game/map_screen.gd`, `game/main.gd` | band and level picker, marks per level, level ids |
| `tests/`, `tests/fight/ref/fight_ref.py`, `tests/fight/vectors/fights.json` | vectors, fuzz, evenness, exact length check, save migration, fight fuzz by level, bots |
| `tools/demo/`, `tools/demo/find_seed.gd`, `tools/touch_check`, `tools/stills` | level ids, drag then tap, half-size checks |
| art `.import` files | mipmaps on for the crossing art, if the filtered world is chosen |

## 8. Milestones

Each milestone ends with the tests green, an APK in the project folder and a short video,
as before. Nothing goes on the tablet without Terrence. A level's `available` is switched
on only in the milestone that builds its screen.

1. **Levels, generator v1.2 and plumbing** (nothing changes on screen): grades.json v2
   with all 12 levels as data and only Acorn 1 available; move_gen v1.2; Python
   reference; spec sections 2, 5 and 6; vectors; exact length test; area layout; save
   v2; fights by level and the level id passed through fight, duel, bounce and the demo
   tools. Store currency renames and `pearls` (closed), data only. Acorn 1 plays exactly
   as today.
2. **Acorn 2 on the tablet, the build for Terrence's son**: half size (filtered world by
   default), screen layer for text and the stone widget, hero at 150, step 82, 46 space
   crossing, landmark 5, hop speed, fight screen with two dice, the red die and shields
   to 8. Acorn 2 available; the map shows Acorn 1 and Acorn 2 (two buttons fit).
3. **Acorn 3 and Acorn 4, and the band and level picker**: landmarks 5 and 10, drag to
   scroll with the edge arrow and back chevron (Acorn 4 on 4:3), the `match_6` board and
   the bounce tuning keyed by rule name.
4. **Sprout 1 and 2**: three dice in the tray, dice faces at 72, the red third die.
   Lava now has its first six levels.
5. **Sprout 3**: answers to 18, ten pairs; Sprout stars open (Leo buyable).
6. **Sapling 1 to 3**: hidden die tray, four dice at 60, two red dice; Sapling stars
   open.
7. **Oak 1 and 2**.
8. **World twists**, each with its world (Crystal Mines first), after the Lava Caves fun
   gate passes and once Terrence approves that world's art job. Twists can be tried on
   the Lava art before then.

## 9. Open questions for Terrence

Each has a default the plan uses until he answers.

1. **Worlds and levels**: one 12-level ladder replayed in every world (default), or a
   ladder that climbs world by world? If "six per region" meant six per age band, Sprout
   1 and 2 could be named Acorn 5 and 6.
2. **Half size look**: filtered world (default, soft pixels, no art work) or half-size
   copies of the crossing art (exact pixels, every hero needs a copy)?
3. **Acorn 2 for your son**: 46 spaces, about 11 moves (default), or 54 like the rest;
   answers to 8 (default) or straight to 10? And should Acorn 1 move to even answers
   (stone 1 is right only 10 percent of the time now; this rewrites Acorn 1's vectors;
   default no)?
4. **Fights from Acorn 2 up** use the level's own question (two dice, red die possible,
   shields to 8), harder than today's one die fight. OK (default yes)?
5. **Old fight rules**: keep the approved Sprout, Sapling and Oak fight kinds for the
   graybox grades (default) or retire them?
6. **Boss at Sprout**: v0.19's "sum" (default; it previews the missing die) or "match 1
   to 6" until Sapling?
7. **Missing die before four dice** (Sapling 1, default), or after?
8. **All levels open** with marks (default), or each opens when the one before is
   cleared?
9. **Space star track** from Sapling 2 up (default), or Space plain at every level?
10. **Names and store**: pearls for the Bog with Shelly moved there; the Svartalf
    Lantern Lord, the Hedley Kow and Ratatoskr as minibosses; gem-priced dice skins; the
    same 5 chests of 2 to 4 at every level (default)?

## 10. Where this differs from the Fable review

The Fable review's fixes are adopted: a gentler Acorn 2 (to 8, 8 stones) and four Acorn
levels; honest take away (red only 1 to 5 with two dice); make ten inside Sprout; half
size with the hero at 150 and up to 11 stones; the zoom fixes (start offset, camera
clamp, Go button, drag slop, tray width); answer first then a reachable pattern; red dice
last; keep the two dice draw order for Acorn 1; uneven faces stated; lengths computed;
3 or 4 monsters; fights by level; save version bump. Differences:

- **Twelve levels, not six plus a bonus.** Six is the first set (Acorn 1 to 4, Sprout 1
  and 2); the ladder continues so older children have somewhere to go in every world.
- **Stones 1 and 2 at Sprout 1 stay never-right mid-crossing.** Three dice cannot make
  them; knowing that is real math. The fallback red die is used only when the room left
  is too small (the Fable review's near-goal case).
- **Doubles are the Mushroom Forest twist**, not a Sprout level, and **the Mushroom
  Forest has no ten-frame under the dice**: a ten-frame that groups the dice comes close
  to showing the total, which the no-hints rule avoids.
- **Space's twist is the star track, not the hidden die**, and only from Sapling 2 up.
  The hidden die is a ladder level (Sapling 1, Oak 1); as a world twist it would make
  Acorn 1 in Space far harder.
- **Acorn 4 keeps answers to 12** and uses drag for stone 12 on a 4:3 screen, instead of
  capping at 11 or moving the hero to the edge.
- **0.5x is not called pixel-exact** (the Fable review did): on the 1340 x 800 tablet it
  cannot be, so the look is a choice (section 3.2).
- **The Go button**: its problem at half size is its size, not that it lands in the
  tray; the screen layer keeps it at today's size.
- **Lengths** are worked out exactly (expected moves) rather than from "13 x mean".
- **New finding**: v1.1's "answer drawn first" claim is wrong for Acorn 1 (op is drawn
  first; stone 1 is right 10 percent of the time). Kept for the vectors, spec text fixed.

## 11. Review responses (items not taken, or taken differently)

- Levels 7 (Acorn 4 boss "match 1 to 6" is an anticlimax): kept; old grade 2 no longer
  migrates to Acorn 4, and "sum" is a missing addend, which waits for Sprout as v0.19 says.
- Worlds 2 (position numbers on every tenth star stone below Sapling 2): not taken; two
  kinds of numbers on screen would confuse a 4 year old, so Space is plain below
  Sapling 2.
- Worlds 3 (Leo unbuyable): fixed by opening Sprout stars at Sprout 3, not by changing
  Leo's price.
- Worlds 12 (rename the band stars): "Sprout stars" stays (already in store.json); the
  Space platforms are called star stones instead.
- Layout 11 (`ui_scale` in the choice widget): replaced by moving the widget and all text
  to an unscaled screen layer (layout 1), which covers padding, highlight and Go sizes.
- Generator 3 (keep ids 2 to 4 as graybox grades): taken as written; the graybox areas
  list `[11, 2]`.

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
