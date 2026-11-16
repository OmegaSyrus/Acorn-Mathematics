# Opus high review: sections 2 and 6.5 (worlds, currencies)
Verdict: structure answers the ask; 12 levels per world, ships with >= 6.
MUST FIX
1. 4.2 step 6 "p = P[0] if there is one" always picks P[0] when P non-empty: at Acorn 2-4 "++" first, so answers 2-5 never get a red die; Bog doubled red never picked. Fix: "p = P[0] if len(P) == 1".
2. Space star track breaks own rule (2.1 twist changes feel not ask; v0.19 same shaped question everywhere). Acorn 3 example "on 23, dice make 7, which star is 30?" is two-digit addition. Fix: default keep distance numbers below Sapling 2, position numbers only on every tenth star; keep Q5 in section 9 as opt-in.
3. Leo unbuyable when sprout_stars open at milestone 5 (only Sprout 1-2 exist, 2 stars, Leo costs 3). Fix: open sprout_stars at milestone 6, or price Leo 2.
4. Pearls has nothing to buy. Fix: move Shelly (turtle) from 30 crystals to 30 pearls, add code-drawn pearl dice skin ~20 pearls; or don't add pearls until Bog items exist.
5. Ask Terrence whether one 12-level ladder replayed in every world is what he meant, or a ladder climbing world by world (add to section 9).
6. New worlds need art (4 monsters each, path pieces, backgrounds, bosses, 3 minibosses), paid PixelLab/RD work, not in milestones. Add: each world's art is a separate costed job needing Terrence's yes; twists can be tested on Lava art; rail-stop crystal drawn in code.
OPTIONAL
7. Gems have nothing after the slime (one clear of each Lava level ~180 gems). Add 2-3 code-drawn dice skins priced in gems.
8. "About 3 clears" holds only for gems; Steel 20 crystals ~2 clears, Mint/Sky 15 ~1. Correct.
9. Bog "red twice as likely" only true for answers 2-5; at Acorn 2 red share 37.5% -> ~46%. Wording: "when either fits, red 2 times in 3". Bog off at Sprout 1, no effect Sprout 2; Space plain at Acorn 1-2. State it.
10. Do twists reach fights/duel/boss? attack_gen calls generate_move without a twist. Say "path only" or pass it.
11. Labels: Surtling Chief is a placeholder (monsters.gd) -> "[built, placeholder]"; "stones are rail stops" not in v0.19 -> [proposal]; if Hedley Kow / Ratatoskr become minibosses say whether they stay in monster lists; v0.19 chests give stickers (area_run.gd still does): say chests give sticker + currency.
12. "Stars" means three things in Space. Call platforms "star stones" or rename band rewards ("Sprout badges", data only). Blank rail stops must look/tap like numbered ones.
13. Landmarks undefined for the star track: distances 5/10/15/20 or positions 10/20/30? Positions match the twist.
14. Oak earns no star: give Sapling stars for Oak until Oak items exist, or say on purpose.
