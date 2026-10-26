## Problem generator for path steps, doors and chests.
## Spec: spec/logic-spec.md. Reference: tools/ref/generator.py.
## Every rng draw is part of the spec: change the order and the vectors break.
extends RefCounted

const Rng := preload("res://logic/core/rng.gd")


static func roll_dice(grade: Dictionary, rng: Rng) -> Array:
	var dice := []
	for d in grade["dice"]:
		dice.append(rng.randi_range(d["min"], d["max"]))
	return dice


## Wrong choices: first the near set (each die alone, answer -1, answer +1),
## shuffled; then answer -k / +k for k = 2, 3, ... until there are enough.
static func near_misses(answer: int, singles: Array, lo: int, hi: int, count: int, rng: Rng) -> Array:
	var near := []
	for v in singles + [answer - 1, answer + 1]:
		if _ok(v, answer, lo, hi, near):
			near.append(v)
	rng.shuffle(near)
	var picked := near.slice(0, count)
	var k := 2
	while picked.size() < count:
		if k > hi - lo + 1:
			push_error("near_misses: not enough choices")
			return picked
		var pair := []
		for v in [answer - k, answer + k]:
			if _ok(v, answer, lo, hi, picked):
				pair.append(v)
		if pair.size() == 2 and picked.size() == count - 1:
			pair = [pair[rng.randi_range(0, 1)]]
		picked.append_array(pair)
		k += 1
	return picked


static func _ok(v: int, answer: int, lo: int, hi: int, taken: Array) -> bool:
	return v >= lo and v <= hi and v != answer and not taken.has(v)


## kind is "path", "door" or "chest". Returns
## {kind, grade, dice, answer, choices, answer_index}. Path choices are in
## distance order (they are rocks in a row); key choices are shuffled.
static func generate(kind: String, grade: Dictionary, rng: Rng) -> Dictionary:
	var dice := roll_dice(grade, rng)
	var answer: int
	var singles := []
	match grade["rule"]:
		"single":
			answer = dice[0]
		"sum":
			answer = dice[0] + dice[1]
			singles = dice.duplicate()
		_:
			push_error("rule not implemented: " + str(grade["rule"]))
			return {}
	var choices := near_misses(answer, singles, grade["min_choice"], grade["max_choice"],
			grade["choices"] - 1, rng)
	choices.append(answer)
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
		"answer_index": choices.find(answer),
	}
