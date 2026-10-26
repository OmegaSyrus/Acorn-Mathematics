"""Reference for the fight rules. Mirrors logic/fight/attack_gen.gd and
logic/fight/fight.gd call for call, so the Godot code and the C++ port can
both be checked against tests/fight/vectors/fights.json.

Run from the project root:
    python3 -I tests/fight/ref/fight_ref.py          # rewrite the vectors
    python3 -I tests/fight/ref/fight_ref.py --check  # fuzz + bots, no writing
"""
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "ref"))
from rng import SeededRng  # noqa: E402  (the graybox's reference RNG)

ACORN, SPROUT, SAPLING, OAK = 1, 2, 3, 4
ONE_DIE, TWO_DICE, DIE_AND_TARGET, MOVE_AND_SLIP = 0, 1, 2, 3
CHOICE_COUNT = 4
MIN_VALUE = 1
MAX_ROLLS = 1000
HERO_HEARTS = 3
WIND_UP, RESOLVING, WON, LOST = 0, 1, 2, 3


def max_value(grade):
    return 6 if grade == ACORN else 12


def near_miss_tiers(atk):
    a = atk["answer"]
    primary = [a - 1, a + 1]
    secondary = [a - 2, a + 2]
    if atk["kind"] == TWO_DICE:
        primary += atk["dice"]
    elif atk["kind"] == DIE_AND_TARGET:
        primary += [atk["dice"][0], atk["target"]]
    elif atk["kind"] == MOVE_AND_SLIP:
        primary += atk["dice"]
        secondary.append(atk["dice"][0] + atk["dice"][1])
    return [primary, secondary, [a - 3, a + 3]]


def _roll(rng, grade):
    atk = {"grade": grade, "target": 0}
    if grade == ACORN:
        atk["kind"] = ONE_DIE
        atk["dice"] = [rng.randi_range(1, 6)]
        atk["answer"] = atk["dice"][0]
    elif grade == SPROUT:
        atk["kind"] = TWO_DICE
        d0 = rng.randi_range(1, 6)
        d1 = rng.randi_range(1, 6)
        atk["dice"] = [d0, d1]
        atk["answer"] = d0 + d1
    elif grade == SAPLING:
        atk["kind"] = DIE_AND_TARGET
        missing = rng.randi_range(1, 6)
        atk["dice"] = [rng.randi_range(1, 6)]
        atk["target"] = atk["dice"][0] + missing
        atk["answer"] = missing
    elif grade == OAK:
        atk["kind"] = MOVE_AND_SLIP
        move = rng.randi_range(2, 6)
        slip = rng.randi_range(1, move - 1)
        atk["dice"] = [move, slip]
        atk["answer"] = move - slip
    else:
        raise ValueError(grade)
    return atk


def _side(atk, below):
    a = atk["answer"]
    top = max_value(atk["grade"])
    seen = []
    tiers = []
    for tier in near_miss_tiers(atk):
        kept = []
        for v in tier:
            if v < MIN_VALUE or v > top or v == a or (v < a) != below or v in seen:
                continue
            seen.append(v)
            kept.append(v)
        tiers.append(kept)
    return tiers


def _take(rng, tiers, n):
    out = []
    for t in tiers:
        if len(out) >= n:
            break
        pool = list(t)
        rng.shuffle(pool)
        out += pool[: n - len(out)]
    return out


def generate(rng, grade):
    below_count = rng.randi_range(0, CHOICE_COUNT - 1)
    above_count = CHOICE_COUNT - 1 - below_count
    for _ in range(MAX_ROLLS):
        atk = _roll(rng, grade)
        below = _side(atk, True)
        above = _side(atk, False)
        if sum(map(len, below)) >= below_count and sum(map(len, above)) >= above_count:
            choices = [atk["answer"]] + _take(rng, below, below_count) + _take(rng, above, above_count)
            rng.shuffle(choices)
            atk["choices"] = choices
            atk["answer_index"] = choices.index(atk["answer"])
            return atk
    raise AssertionError("no roll fits")


class Fight:
    def __init__(self, rng, grade, monster_hearts, first_strike=False):
        self.rng = rng
        self.grade = grade
        self.max_hearts = monster_hearts
        self.hero = HERO_HEARTS
        self.monster = monster_hearts - (1 if first_strike else 0)
        self.wind_up()

    def wind_up(self):
        self.attack = generate(self.rng, self.grade)
        self.state = WIND_UP

    def choose(self, i):
        assert self.state == WIND_UP
        right = i == self.attack["answer_index"]
        if right:
            self.monster -= 1
        else:
            self.hero -= 1
        if self.monster <= 0:
            self.state = WON
        elif self.hero <= 0:
            self.state = LOST
        else:
            self.state = RESOLVING
        return right

    def restart(self):  # duel only
        self.hero = HERO_HEARTS
        self.monster = self.max_hearts
        self.wind_up()


def attack_vectors():
    cases = []
    for grade in (ACORN, SPROUT, SAPLING, OAK):
        for seed in (0, 1, 2, 77, 4096):
            rng = SeededRng(seed)
            attacks = [generate(rng, grade) for _ in range(25)]
            cases.append({"grade": grade, "seed": seed, "attacks": attacks, "state_after": rng.get_state()})
    return cases


def fight_vectors():
    """Scripted taps through whole fights; a new fight starts when one ends."""
    taps = [0, 1, 2, 3, 3, 2, 1, 0, 2, 2, 0, 1, 3, 1, 0, 2, 3, 3, 1, 0]
    cases = []
    for grade in (ACORN, SPROUT, SAPLING, OAK):
        for hearts, first_strike in ((3, False), (4, False), (3, True)):
            rng = SeededRng(500 + grade)
            f = Fight(rng, grade, hearts, first_strike)
            log = []
            for t in taps:
                right = f.choose(t)
                log.append([t, right, f.hero, f.monster, f.state])
                if f.state in (WON, LOST):
                    f = Fight(rng, grade, hearts, first_strike)
                else:
                    f.wind_up()
            cases.append({"grade": grade, "hearts": hearts, "first_strike": first_strike,
                          "taps": taps, "log": log, "state_after": rng.get_state()})
    return cases


def check():
    for grade in (ACORN, SPROUT, SAPLING, OAK):
        rng = SeededRng(1000 + grade)
        for _ in range(100000):
            atk = generate(rng, grade)
            c = atk["choices"]
            assert len(set(c)) == 4 and c.count(atk["answer"]) == 1
            assert all(MIN_VALUE <= v <= max_value(grade) for v in c)
            allowed = sum(near_miss_tiers(atk), [])
            assert all(v in allowed for v in c if v != atk["answer"])
        game, bot = SeededRng(7000 + grade), SeededRng(9000 + grade)
        wins = 0
        for _ in range(5000):
            f = Fight(game, grade, 3)
            while f.state not in (WON, LOST):
                f.choose(bot.randi_range(0, 3))
                if f.state == RESOLVING:
                    f.wind_up()
            wins += f.state == WON
        print("grade %d: 100k attacks ok, random bot beat a 3-heart monster in %.1f%% of 5000 fights" % (grade, 100.0 * wins / 5000))
        assert wins / 5000 <= 0.15


if __name__ == "__main__":
    if "--check" in sys.argv:
        check()
    else:
        out = os.path.join(ROOT, "tests", "fight", "vectors", "fights.json")
        with open(out, "w") as fh:
            json.dump({"version": 1, "attacks": attack_vectors(), "fights": fight_vectors()}, fh, indent=1)
        print("wrote", out)
