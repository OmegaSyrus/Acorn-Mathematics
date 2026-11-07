## Move problems for scroll areas: an add or subtract whose answer is how many
## spaces to move. Spec: spec/logic-spec.md section 6. Reference:
## tools/ref/move_gen.py. Every rng draw is part of the spec.
extends RefCounted

const Rng := preload("res://logic/core/rng.gd")


## room is how many spaces are left before the goal. Returns
## {kind, grade, op, dice, answer, choices, answer_index}; choices are the
## distances 1..m in order (the next m spaces), so answer_index = answer - 1.
## The answer is drawn first, then the dice, so every distance is as likely.
## lo and hi (when hi > 0) narrow the answer only, to keep a crossing within
## its roll count (ScrollRun); the choices shown are still 1..m.
static func generate_move(grade: Dictionary, rng: Rng, room: int, lo := 1, hi := 0) -> Dictionary:
	var cfg: Dictionary = grade["move"]
	var m: int = mini(cfg["max_answer"], room)
	var top: int = m if hi <= 0 else clampi(hi, 1, m)
	var bottom: int = clampi(lo, 1, top)
	var ops := []
	for op in cfg["ops"]:
		if not (op == "add" and top < 2):
			ops.append(op)
	var op: String = ops[0] if ops.size() == 1 else ops[rng.randi_range(0, ops.size() - 1)]
	var answer: int
	var a: int
	var b: int
	if op == "add":
		answer = rng.randi_range(maxi(2, bottom), top)
		a = rng.randi_range(1, answer - 1)
		b = answer - a
	else:
		answer = rng.randi_range(bottom, top)
		a = rng.randi_range(answer + 1, cfg["die_max"])
		b = a - answer
	var choices := []
	for d in range(1, m + 1):
		choices.append(d)
	return {
		"kind": "move",
		"grade": grade["id"],
		"op": op,
		"dice": [a, b],
		"answer": answer,
		"choices": choices,
		"answer_index": answer - 1,
	}
