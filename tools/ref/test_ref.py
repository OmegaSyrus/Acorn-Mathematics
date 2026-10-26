"""Reference tests: math fuzz, bots, seeded replay, save/resume.
Run: python3 -I tools/ref/test_ref.py [fuzz_count]"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rng import SeededRng  # noqa: E402
from generator import generate  # noqa: E402
from area_run import AreaRun  # noqa: E402
from bots import play, apply_input  # noqa: E402
import common  # noqa: E402
from move_gen import generate_move  # noqa: E402
from scroll_run import ScrollRun, play_scroll  # noqa: E402

FAILS = []


def check(cond, msg):
    if not cond:
        FAILS.append(msg)


def answer_of(grade, dice):
    return dice[0] if grade["rule"] == "single" else dice[0] + dice[1]


def check_problem(p, grade, kind):
    tag = "grade %d %s %r" % (grade["id"], kind, p)
    lo, hi = grade["min_choice"], grade["max_choice"]
    for die, spec in zip(p["dice"], grade["dice"]):
        check(spec["min"] <= die <= spec["max"], "die out of range " + tag)
    check(p["answer"] == answer_of(grade, p["dice"]), "wrong answer " + tag)
    c = p["choices"]
    check(len(c) == grade["choices"], "choice count " + tag)
    check(len(set(c)) == len(c), "duplicate choices " + tag)
    check(sum(1 for v in c if v == p["answer"]) == 1, "not exactly one right " + tag)
    check(c[p["answer_index"]] == p["answer"], "answer_index " + tag)
    check(all(lo <= v <= hi for v in c), "choice out of range " + tag)
    singles = p["dice"] if grade["rule"] == "sum" else []
    wrong = [v for v in c if v != p["answer"]]
    check(all(v in singles or abs(v - p["answer"]) <= 3 for v in wrong), "far miss " + tag)
    check(any(v in singles or abs(v - p["answer"]) == 1 for v in wrong), "no near miss " + tag)
    if kind == "path":
        check(c == sorted(c), "path choices not sorted " + tag)


def test_moves(n):
    grade = common.grades()[1]
    cfg = grade["move"]
    rng = SeededRng(4242)
    counts = {}
    for i in range(n):
        room = 1 + i % 8
        p = generate_move(grade, rng, room)
        a, b = p["dice"]
        tag = "move %r room %d" % (p, room)
        m = min(cfg["max_answer"], room)
        check(1 <= p["answer"] <= m, "answer out of range " + tag)
        check(p["answer"] == (a + b if p["op"] == "add" else a - b), "wrong answer " + tag)
        check(1 <= a <= cfg["die_max"] and 1 <= b <= cfg["die_max"], "die out of range " + tag)
        check(p["choices"] == list(range(1, m + 1)), "choices " + tag)
        if room >= 5:
            counts[(p["op"], p["answer"])] = counts.get((p["op"], p["answer"]), 0) + 1
    check(all(k in counts for k in [("add", 2), ("add", 5), ("sub", 1), ("sub", 5)]), "ops/answers missing %r" % counts)


def test_scroll_bots(runs):
    area, grade = common.area("lava_scroll"), common.grades()[1]
    for i in range(runs):
        run = ScrollRun(area, grade, 100 + i)
        cleared, _ = play_scroll(run, "perfect", None)
        check(cleared and run.pos == area["length"], "perfect scroll bot failed seed %d" % (100 + i))
        lo, hi = area["chest_gems"]
        check(lo * len(run.looted) <= run.gems <= hi * len(run.looted), "gems vs looted chests seed %d" % (100 + i))
    rnd = sum(play_scroll(ScrollRun(area, grade, 900 + i), "random", SeededRng(i + 1))[0] for i in range(runs))
    check(rnd == 0, "random scroll bot cleared %d" % rnd)


def test_fuzz(n):
    for gid, grade in common.grades().items():
        if grade["rule"] not in common.IMPLEMENTED_RULES:
            continue
        rng = SeededRng(gid * 7919)
        slots = [0] * grade["choices"]
        for i in range(n):
            kind = ("path", "door", "chest")[i % 3]
            p = generate(kind, grade, rng)
            check_problem(p, grade, kind)
            if kind != "path":
                slots[p["answer_index"]] += 1
        # Shuffled keys: the right key lands in every slot about equally often.
        total = sum(slots)
        check(all(abs(s / total - 1 / len(slots)) < 0.02 for s in slots),
              "key slot bias grade %d %r" % (gid, slots))
        if len(FAILS) > 20:
            return


def test_bots(runs=1000):
    area, sticks = common.area("lava_1"), common.stickers()
    results = {}
    for gid, grade in common.grades().items():
        if not grade["available"]:
            continue
        perfect = random = 0
        for i in range(runs):
            run = AreaRun(area, grade, sticks, 1000 + i)
            ok, _ = play(run, "perfect", None)
            perfect += ok
            run = AreaRun(area, grade, sticks, 5000 + i)
            ok, _ = play(run, "random", SeededRng(9000 + i))
            random += ok
        check(perfect == runs, "perfect bot failed grade %d: %d/%d" % (gid, perfect, runs))
        check(random < runs / 100, "random bot cleared too often grade %d: %d/%d" % (gid, random, runs))
        results[gid] = (perfect, random)
    return results


def test_replay_and_resume():
    area, sticks = common.area("lava_1"), common.stickers()
    grade = common.grades()[2]
    for s in range(50):
        a = AreaRun(area, grade, sticks, s)
        _, inputs = play(a, "random", SeededRng(s + 1))
        b = AreaRun(area, grade, sticks, s)
        for inp in inputs:
            apply_input(b, inp)
        check(a.events == b.events and a.to_save() == b.to_save(), "replay mismatch seed %d" % s)
    # Close the game at every task boundary: a resumed run matches an unbroken one.
    whole = AreaRun(area, grade, sticks, 77)
    play(whole, "perfect", None)
    for stop in range(len(area["tasks"])):
        r = AreaRun(area, grade, sticks, 77)
        while r.task_index < stop:
            apply_input(r, next_perfect(r))
        r2 = AreaRun.from_save(area, grade, sticks, r.to_save())
        r2.events = list(r.events)
        play(r2, "perfect", None)
        check(r2.events == whole.events, "resume mismatch at task %d" % stop)
    # A fall restarts at task 0 with fresh problems and a counted attempt.
    r = AreaRun(area, grade, sticks, 3)
    r.roll()
    wrong = (r.problem["answer_index"] + 1) % 4
    out = r.choose(wrong)
    check(out["result"] == "fall" and out["restarted"], "fall should restart")
    check(r.task_index == 0 and r.attempt == 2 and r.phase == "await_roll", "restart state")


def next_perfect(run):
    if run.phase == "await_chest":
        return "open"
    if run.phase == "await_roll":
        return "roll"
    return "pick:%d" % run.problem["answer_index"]


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
    test_fuzz(n)
    bots = test_bots()
    test_replay_and_resume()
    test_moves(n)
    test_scroll_bots(300)
    print("fuzz: %d problems per implemented grade" % n)
    for gid, (p, r) in bots.items():
        print("bots grade %d: perfect cleared %d/1000, random cleared %d/1000" % (gid, p, r))
    if FAILS:
        print("FAILED (%d)" % len(FAILS))
        for f in FAILS[:20]:
            print("  " + f)
        sys.exit(1)
    print("all reference tests passed")
