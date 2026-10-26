"""Reference move generator for scroll areas, mirrors logic/core/move_gen.gd.
Spec: spec/logic-spec.md section 6. Draw order matters."""


def generate_move(grade, rng, room):
    cfg = grade["move"]
    m = min(cfg["max_answer"], room)
    ops = [op for op in cfg["ops"] if not (op == "add" and m < 2)]
    op = ops[0] if len(ops) == 1 else ops[rng.randi_range(0, len(ops) - 1)]
    if op == "add":
        answer = rng.randi_range(2, m)
        a = rng.randi_range(1, answer - 1)
        b = answer - a
    else:
        answer = rng.randi_range(1, m)
        a = rng.randi_range(answer + 1, cfg["die_max"])
        b = a - answer
    choices = list(range(1, m + 1))
    return {"kind": "move", "grade": grade["id"], "op": op, "dice": [a, b],
            "answer": answer, "choices": choices, "answer_index": answer - 1}
