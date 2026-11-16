# Opus high review: Summary + section 1 (levels)
Verified: all 12 lengths give 12.92-13.14 moves; means right; every range reachable; tells in 1.2 hold. 
MUST FIX
1. Sprout 3 uses +-- (two red) but 1.1 says two red is new at Sapling 3; Sprout 3 already biggest step. Fix: Sprout 3 patterns +++, ++- (1-18 still reachable, length 107, mean 9.5). Remove Sprout 3 from +-- "Used at" (line 99); +-- unused or move to Sapling 3.
2. "sum" boss (bounce_rules.gd peg = target - ball) is a missing addend, which 1.1 holds back until Sapling 1, but Sprout 1-3 face it. Fix (a) boss "match 1 to 6" for Sprout 1-3 and sum from Sapling 1; or (b) keep v0.19 mapping and say the Sprout boss previews the missing die.
3. Tries to clear never stated (1.3 lines 131-133). Clear prob ~0.967 x p^13 (3 monsters): p=.90 ~4.1 tries, .85 ~9.2, .95 ~2.0; 4th monster <1%. Add table to 1.3; set Acorn 2 to ~11 moves (length 46 -> 11.29 moves, ~3.3 tries at 90%) or make it open question.
4. Fight shields at Acorn 2/3 show 9-12 which the level never uses (6.1 fight max 12). Fix fight.max = min(max_answer, 12) -> 8,10,12,11,11,12; keep 12 for Sapling 1 and Oak 1. Summary "answer capped at 12" -> "choices capped at the level's top answer (at most 12)".
5. Sprout 1 fight "three dice, to 12" (line 122) -> "three dice, 3 to 11".
6. Lines 66-67 "a lost fight does the same" vs duel.gd restarting only the duel: "a lost monster fight does the same; a lost miniboss duel restarts only the duel [decided]".
OPTIONAL
7. Acorn 4 boss match 1-6 is an anticlimax (old grade 2 = Sprout had the sum boss, migrates to Acorn 4): use match_6 only at Acorn 3, or say so.
8. Red-die share falls 50% (A1), 37.5% (A2), 30% (A3), 25% (A4). State it or pick +- first when it fits (~50%).
9. Missing tells: Oak 2 across_ten answers 1-4 only via ++-- (always four dice two red); ++- and +++- only make 5-9; Sprout 3 answers 12-18 always +++.
10. Ten pair at Sprout 3 fires every time for +++ 11-16, never 17-18: use a coin flip like doubles.
11. Summary line 34 "under 70 / longer": "3 monsters under 70 spaces, 4 from 70 up".
12. Pattern table line 95: ++ "2 to 12 at Sapling 1" is the shown total; add "(total; the answer is the hidden die, 1 to 6)"; same for +++ at Oak 1.
13. If "six per region" meant per age band, Acorn has 4: add to open question 2 "Sprout 1 and 2 could be renamed Acorn 5 and 6".
14. Near-goal rule "at most at the last move" wrong: room 2 fallback can draw 1 -> "only in the last one or two moves".
