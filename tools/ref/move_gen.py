"""Reference move generator for scroll areas, mirrors logic/core/move_gen.gd.
Spec: spec/logic-spec.md section 6. Draw order matters."""


def generate_move(grade, rng, room, lo=1, hi=0):
    cfg = grade["move"]
    m = min(cfg["max_answer"], room)
    top = m if hi <= 0 else max(1, min(hi, m))
    bottom = max(1, min(lo, top))
    ops = [op for op in cfg["ops"] if not (op == "add" and top < 2)]
    op = ops[0] if len(ops) == 1 else ops[rng.randi_range(0, len(ops) - 1)]
    if op == "add":
        answer = rng.randi_range(max(2, bottom), top)
        a = rng.randi_range(1, answer - 1)
        b = answer - a
    else:
        answer = rng.randi_range(bottom, top)
        a = rng.randi_range(answer + 1, cfg["die_max"])
        b = a - answer
    choices = list(range(1, m + 1))
    return {"kind": "move", "grade": grade["id"], "op": op, "dice": [a, b],
            "answer": answer, "choices": choices, "answer_index": answer - 1}
