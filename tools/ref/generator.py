"""Reference problem generator, mirrors logic/core/problem_gen.gd.
The algorithm is specified in spec/logic-spec.md; draw order matters."""


class GenError(Exception):
    pass


def roll_dice(grade, rng):
    return [rng.randi_range(d["min"], d["max"]) for d in grade["dice"]]


def near_misses(answer, singles, lo, hi, count, rng):
    def ok(v, taken):
        return lo <= v <= hi and v != answer and v not in taken

    near = []
    for v in list(singles) + [answer - 1, answer + 1]:
        if ok(v, near):
            near.append(v)
    rng.shuffle(near)
    picked = near[:count]
    k = 2
    while len(picked) < count:
        if k > hi - lo + 1:
            raise GenError("not enough choices")
        pair = [v for v in (answer - k, answer + k) if ok(v, picked)]
        if len(pair) == 2 and len(picked) == count - 1:
            pair = [pair[rng.randi_range(0, 1)]]
        picked += pair
        k += 1
    return picked


def generate(kind, grade, rng):
    rule = grade["rule"]
    dice = roll_dice(grade, rng)
    if rule == "single":
        answer = dice[0]
        singles = []
    elif rule == "sum":
        answer = dice[0] + dice[1]
        singles = dice[:]
    else:
        raise GenError("rule not implemented: " + rule)
    wrong = near_misses(answer, singles, grade["min_choice"], grade["max_choice"],
                        grade["choices"] - 1, rng)
    choices = wrong + [answer]
    if kind == "path":
        choices.sort()
    else:
        rng.shuffle(choices)
    return {
        "kind": kind,
        "grade": grade["id"],
        "dice": dice,
        "answer": answer,
        "choices": choices,
        "answer_index": choices.index(answer),
    }
