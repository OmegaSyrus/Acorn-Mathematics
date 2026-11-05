# Digest of existing plans for future levels (found 2026-11-05)

Sources: docs/difficulty-plan.md (newest, 11-05); Sum-Dungeon-Design-v0.19 (10-26; text in scratchpad/txt/Sum-Dungeon-Design-v0.19.txt); review 10-29 (scratchpad/txt/Acorn-Review-2026-10-29.txt); repo content/, logic/fight/README.md, logic/bounce/README.md, content/bounce/tuning.json, content/store.json.

## Grades
- v0.19 §03: Acorn = one die, "a full roll is shown; pick where you land"; Sprout = add two dice; Sapling = missing number; Oak = take away (move die + red slip die). "Later: Within 20, then times and share as new grades. Same areas, same monsters, same bosses." Grade picked on map, "never changes by itself", parents can lock. Dice: dots first, numeral after; "Above 6: two dice side by side... Above 12: numerals." No hints, no adaptive difficulty.
- Fights (v0.19 §05, attack_gen.gd): Acorn one die -> same count (1-6); Sprout two dice total (1-12); Sapling die+target missing number; Oak move/slip difference. 4 shields, near misses, hero 3 hearts (refill each fight), monsters 3-4. Code only splits ACORN vs rest. Later attack styles: twin strikes, feints (3 dice, 2 real), armor (subtract), combos (3, 4, ?).
- Duel (§06): miniboss shows sum/difference, pick the numeral; every miniboss uses it. Lava miniboss = Surtling Chief.
- Boss Match Bounce (§07, tuning.json): Acorn match 1-3 colors/numerals, 8 balls, 10 hearts; Sprout ball+peg=target; Sapling sum; Oak ball-peg=target; "times later".
- Code now: Acorn rule single but crossing move = two dice add/sub, answers 1-5. Sprout two dice sum 1-14. Sapling/Oak unavailable.
- Review 10-29: Acorn = one die (Rachel's mode), Sprout two dice +- to 6, Sapling slip difference, Oak missing number (swap: missing addend harder than take-away), then within 20. Crossing length per grade (Acorn 24, Sprout 40). Ten-frames for 7-12 when within-20 arrives; show right answer after a fall; numbered track.
- Current difficulty plan: Acorn 1-3, Sprout 1-3, Sapling 1-3, Oak later (see docs/difficulty-plan.md).

## Worlds (v0.19 §10), in order
1. Lava Caves: stepping rocks. Blorp the Ember Troll, Craggy the Stone Troll, Surtlings. Miniboss Surtling Chief. Boss Fafnir's Bones, the Skeleton Dragon.
2. Crystal Mines: minecart rails. Knockers, Gem Dwarves, Svartalf lantern-bearers. Boss the Knocker King.
3. The Bog: tussocks, logs, peat stones. Wisplings, nixies, bog-draugr, Tiddy Mun. Miniboss the King and Queen of the Will-o'-the-wisps. Boss Jenny Greenteeth.
4. Mushroom Forest: mushroom caps. Hobgoblins with acorn shields, pixies, boggarts, the Hedley Kow. Boss the Green Man.
5. Space (Yggdrasil): star platforms. Fenrir's pups, Ratatoskr squirrels, moon hobgoblins. Boss Fenrir.
- Other minibosses not chosen. No per-world math twist in v0.19: math is grade-driven; only path art and the fall change. A world opens when the previous boss is beaten at any grade. Full sticker panel unlocks world dice style (wood, stone, crystal, bone, star). Heroes from bosses.
- Store currencies (store.json 11-05): gems (Lava chests, open), crystals (Crystal Mines), leaves ("Mossy Woods"), feathers ("Cloud Tops"), sprout_stars, sapling_stars. Mossy Woods / Cloud Tops conflict with the design's Bog / Mushroom Forest / Space; no Bog or Space currency.

## Area structure
- v0.19 §02: area = 6-10 tasks, ~10-15 min, restarts on fail. World = three areas, then boss run (duel then boss). "Area length is the difficulty knob"; target 1-3 tries at ~90% per task.
- Built: lava_scroll.json, 40-space crossing, 5 chests (2-4 gems), 3 monsters.
- Review: don't start world 2 until the Lava Caves fun gate passes.
- Replaying areas at a higher grade is how the game gets harder (v0.19 §01, §03). Sapling/Oak played in Lava Caves before new worlds use them.
