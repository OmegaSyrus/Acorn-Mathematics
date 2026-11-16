# Fable (medium) analysis of docs/difficulty-plan.md v1 (2026-11-05)

## 1. Pedagogy
- Acorn 1 -> Acorn 2 is the biggest jump: doubles stones (5->10), doubles top sum, switches subitizing -> counting on at once. Insert a step: two dice, sums to 7-8, 8 stones. Then to 10, then any two dice to 12 (Acorn gets 4 levels).
- Take-away never grows: one red die => difference <= 5 (move_gen.gd:30-31), so from Acorn 2 a red die means "stone 1-5". Sub answers must honestly be 1..5; bigger take-aways via a + b - c (to 11).
- Make ten and doubles in Oak (age 7-8) is too late. Put doubles (answers 2,4..12) and make-ten (3 dice, one fixed complement: 6+4+3) inside Sprout; cheap constraints on the same generator.
- Sapling 3 missing die drops to 6 stones (reads as demotion). Show tray "[die] + [?] = 9", keep stone semantics, say so.
- Keep age as a parent hint, not in the tier name (a 4.5 yo passed tier 1 in one session).

## 2. 6+ levels per region
Both axes: one global ladder of 6 levels played in every region, plus a region twist (presentation / skill stressed, not the generator contract). Proposed: L1 two dice to 5 (today), L2 to 8, L3 to 10/12, L4 three dice all plus, L5 three dice one red, L6 four dice mixed to 20 (missing die as bonus L7). Twists: Lava plain; Crystal Mines only landmark stones numbered (count on from 5/10/15/20); Bog red dice more frequent, take-away heavy; Mushroom Forest ten-frame under dice, doubles/make-ten draws; Space number line to 20 with jumps, missing/hidden die. Generator gets at most two new knobs (signs, constraint: doubles|make_ten|hidden_die). by_band -> by level + region twist flag.

## 3. Screen/touch
- 0.55 checks out (stone 10 at x 810) but rock gap 2 units, digits 26 units. 0.5x better: integer pixel scale (answers pixel-grid question), step 60, rock 58 (0.58"), 11 stones fit (hero 150 -> 810). Hero at 130: 12 stones reach 850, 10 past 4:3 edge, so "to 12" needs max_answer 11 or hero at the very left; no scrolling needed until 15. Dragging can wait a milestone.
- 0.33x gives 38-unit rocks, under touch minimum: scrolling needed for 20.
- Missed: SPACE0_X 190 scales to 95 (left of 4:3 edge 120) -> offset; _cam_target (scroll_screen.gd:588) clamps at _world_w()-960, must use zoom; Go button go_offset (0,-175) above a stone at y~452*0.5 lands in HUD tray (y 8..168) -> set go_area; drag needs slop threshold before press counts (FLICK_PX 24); tray 390 wide fits three 72 px dice + signs (~336) but four dice need ~410 -> 60 px dice or wider tray.

## 4. Generator traps
- a+b-c maxes 11 (Sprout 2 "1-12" unreachable 12); a+b-c-d max 10; a+b+c-d max 17 (Sapling 2 "to 20" unreachable above 17 with any red). Draw answer first, then the sign pattern from patterns that can reach it; document bias (big stones imply all-plus).
- Pure-add with 3/4 dice: min answer 3/4, stones 1-2 never right (child learns to skip). Near goal m=min(max_answer, room) can be < n_dice -> no add problem (code only drops add when m<2, move_gen.gd:16-19). Rule: fall back to a sub pattern, or any distance >= room lands on the shore.
- Three dice capped at 12 = small faces (6+6+5 never). Let answers run to 15-18 or accept "small numbers, more of them".
- Sequential draw max(1, rest-6k)..min(6, rest-k) correct for adds; red die clamped to 6k - answer. Place red dice last so left-to-right reading never goes negative.
- Vector stability: milestone 1 says Acorn 1 vectors unchanged, but plan draws red die first while move_gen.gd:30 draws big die first. Keep old order for n_dice 2 or accept new vectors.
- Uniform answers => non-uniform faces (answer 3 with 3 dice always 1+1+1); state in spec; fuzz must not assert uniform faces.

## 5. Risks/gaps
- Crossing length: table contradicts "13 x mean answer" (Acorn 3 ~16 moves, Sprout 1 ~11, Sapling 1 ~10, Sapling 3 ~17). Compute length from the generator's mean.
- Fail cost grows with length (restart whole crossing, monsters return). Keep 3-4 monsters per crossing regardless of length; chests 5.
- Fights: attack_gen.gd keys on Grade enum (max_value, _roll match): tier ids 11/12/21 break it unless mapped. Acorn 2-3 fights (one die dots->numeral) far easier than crossing; two-dice fight at Acorn 3 fits.
- Economy: sprout_stars "clearing an area at Sprout" -- define whether each level clear gives a star (Leo 3, Sir Tam 5).
- Walk time: 20 hops at HOP_S 0.34 ~7 s; speed hops for long moves.
- Content: lava_scroll.json "grades": [1] and one length; by_band wrong granularity; use per-tier or computed.
- Save: bump SaveData.VERSION, keep an old-save vector; restored run pos < new length.
- Open: unlock order (all-open with marks fine); cut doubles cheer.
