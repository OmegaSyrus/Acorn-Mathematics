"""Writes tests/vectors/*.json from the reference. The Godot tests and the
C++ port must reproduce every vector exactly.
Run: python3 -I tools/ref/make_vectors.py"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rng import SeededRng  # noqa: E402
from generator import generate  # noqa: E402
from area_run import AreaRun  # noqa: E402
from bots import play  # noqa: E402
from move_gen import generate_move  # noqa: E402
from scroll_run import ScrollRun, play_scroll  # noqa: E402
import common  # noqa: E402

OUT = os.path.join(common.ROOT, "tests", "vectors")


def write(name, data):
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")


def rng_vectors():
    cases = []
    for seed in (0, 1, 2, 42, 123456789, 0xFFFFFFFF, 0x1_0000_0001):
        r = SeededRng(seed)
        u32 = [r.next_u32() for _ in range(8)]
        d6 = [r.randi_range(1, 6) for _ in range(20)]
        arr = list(range(10))
        r.shuffle(arr)
        cases.append({"seed": seed, "u32": u32, "d6": d6, "shuffle10": arr,
                      "state_after": r.get_state()})
    return {"version": 1, "cases": cases}


def problem_vectors():
    cases = []
    for gid, grade in common.grades().items():
        if grade["rule"] not in common.IMPLEMENTED_RULES:
            continue
        for kind in ("path", "door", "chest"):
            for seed in range(1, 41):
                r = SeededRng(seed)
                p = generate(kind, grade, r)
                cases.append({"grade": gid, "kind": kind, "seed": seed,
                              "problem": p, "state_after": r.get_state()})
    return {"version": 1, "cases": cases}


def replay_vectors():
    area, sticks = common.area("lava_1"), common.stickers()
    cases = []
    for gid in (1, 2):
        grade = common.grades()[gid]
        for seed in range(1, 11):
            run = AreaRun(area, grade, sticks, seed)
            # A few attempts: random play until it falls, then perfect play.
            inputs = []
            for _ in range(3):
                _, part = play(run, "random", SeededRng(seed * 31 + len(inputs)))
                inputs += part
                if run.phase == "cleared":
                    break
            if run.phase != "cleared":
                _, part = play(run, "perfect", None)
                inputs += part
            cases.append({"area": area["id"], "grade": gid, "seed": seed,
                          "inputs": inputs, "log": run.events, "final": run.to_save(),
                          "phase": run.phase})
    return {"version": 1, "cases": cases}


def scroll_vectors():
    grade = common.grades()[1]
    moves = []
    for room in (1, 2, 3, 5, 40):
        for seed in range(1, 31):
            r = SeededRng(seed)
            moves.append({"grade": 1, "room": room, "seed": seed,
                          "problem": generate_move(grade, r, room), "state_after": r.get_state()})
    area = common.area("lava_scroll")
    runs = []
    for seed in range(1, 11):
        run = ScrollRun(area, grade, seed)
        inputs = []
        for k in range(3):
            _, part = play_scroll(run, "random", SeededRng(seed * 37 + k))
            inputs += part
            if run.phase == "cleared":
                break
        if run.phase != "cleared":
            _, part = play_scroll(run, "perfect", None)
            inputs += part
        runs.append({"area": area["id"], "grade": 1, "seed": seed, "inputs": inputs,
                     "log": run.events, "final": run.to_save(), "phase": run.phase})
    return {"version": 1, "moves": moves, "cases": runs}


if __name__ == "__main__":
    write("scroll.json", scroll_vectors())
    write("rng.json", rng_vectors())
    write("problems.json", problem_vectors())
    write("replays.json", replay_vectors())
    print("wrote", sorted(os.listdir(OUT)))
