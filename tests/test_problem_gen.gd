extends "res://tests/support/test_case.gd"

const Rng := preload("res://logic/core/rng.gd")
const ProblemGen := preload("res://logic/core/problem_gen.gd")
const Content := preload("res://logic/core/content.gd")


func test_problem_vectors() -> bool:
	var grades := Content.grades()
	for c in vectors("problems.json"):
		var r := Rng.new(c["seed"])
		var p := ProblemGen.generate(c["kind"], grades[c["grade"]], r)
		eq(p, c["problem"], "grade %d %s seed %d" % [c["grade"], c["kind"], c["seed"]])
		eq(r.get_state(), c["state_after"], "rng draws, grade %d %s seed %d" % [c["grade"], c["kind"], c["seed"]])
	return true


## Plan section 16: solvable, in range, exactly one right choice, near misses.
func test_fuzz_every_implemented_grade() -> bool:
	var n := fuzz_count(100000)
	var kinds := ["path", "door", "chest"]
	for gid in Content.grades():
		var grade: Dictionary = Content.grades()[gid]
		if not Content.IMPLEMENTED_RULES.has(grade["rule"]):
			continue
		var r := Rng.new(gid * 7919)
		var slots := [0, 0, 0, 0]
		for i in n:
			var kind: String = kinds[i % 3]
			var p := ProblemGen.generate(kind, grade, r)
			_check_problem(p, grade, kind)
			if kind != "path":
				slots[p["answer_index"]] += 1
			if failures.size() > 20:
				return true
		var total := 0
		for s in slots:
			total += s
		for s in slots:
			check(absf(float(s) / total - 0.25) < 0.02, "key slot bias grade %d %s" % [gid, str(slots)])
	return true


## Collects what is wrong with one problem; the message (with the problem as
## JSON) is only built when something failed, which keeps 100k runs fast.
func _check_problem(p: Dictionary, grade: Dictionary, kind: String) -> void:
	var bad := []
	var dice: Array = p["dice"]
	for i in dice.size():
		var spec: Dictionary = grade["dice"][i]
		if dice[i] < spec["min"] or dice[i] > spec["max"]:
			bad.append("die out of range")
	var answer: int = dice[0] if grade["rule"] == "single" else dice[0] + dice[1]
	if p["answer"] != answer:
		bad.append("wrong answer")
	var c: Array = p["choices"]
	if c.size() != grade["choices"]:
		bad.append("choice count")
	var right := 0
	for v in c:
		if c.count(v) != 1:
			bad.append("duplicate choice")
		if v < grade["min_choice"] or v > grade["max_choice"]:
			bad.append("choice out of range")
		if v == answer:
			right += 1
	if right != 1:
		bad.append("not exactly one right")
	if c[p["answer_index"]] != answer:
		bad.append("answer_index")
	var singles: Array = dice if grade["rule"] == "sum" else []
	var has_near := false
	for v in c:
		if v == answer:
			continue
		if not (singles.has(v) or absi(v - answer) <= 3):
			bad.append("far miss")
		if singles.has(v) or absi(v - answer) == 1:
			has_near = true
	if not has_near:
		bad.append("no near miss")
	if kind == "path":
		var sorted_c := c.duplicate()
		sorted_c.sort()
		if sorted_c != c:
			bad.append("path choices not in distance order")
	if not bad.is_empty():
		failures.append("grade %d %s %s: %s" % [grade["id"], kind, JsonUtil.canonical(p), ", ".join(bad)])
