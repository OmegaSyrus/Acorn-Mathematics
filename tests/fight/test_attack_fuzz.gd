extends "res://tests/fight/fight_test_base.gd"
## Math fuzzing (plan, "How testing works"): every generated attack is
## solvable, in range for its grade, has exactly one right choice, and its
## wrong choices follow the near-miss rules. 100,000 attacks per grade.

const AttackGen = preload("res://logic/fight/attack_gen.gd")
const Attack = preload("res://logic/fight/attack.gd")
const GradesLib = preload("res://logic/core/grades.gd")
const SeededRng = preload("res://logic/core/rng.gd")

const PER_GRADE := 100000


func test_every_attack_follows_the_rules() -> bool:
	for grade in [GradesLib.Grade.ACORN, GradesLib.Grade.SPROUT, GradesLib.Grade.SAPLING, GradesLib.Grade.OAK]:
		var rng = SeededRng.new(1000 + grade)
		var top := AttackGen.max_value(grade)
		var rank_counts := [0, 0, 0, 0]
		var tier_counts := [0, 0, 0]
		var bad := 0
		for i in PER_GRADE:
			var atk = AttackGen.generate(rng, grade)
			var ok := _check_attack(atk, top)
			if not ok:
				bad += 1
				if bad > 5:
					break
				continue
			var sorted: Array = atk.choices.duplicate()
			sorted.sort()
			rank_counts[sorted.find(atk.answer)] += 1
			var tiers: Array = AttackGen.near_miss_tiers(atk)
			for v in atk.choices:
				if v == atk.answer:
					continue
				for t in tiers.size():
					if tiers[t].has(v):
						tier_counts[t] += 1
						break
		var wrongs: int = PER_GRADE * 3
		notes.append("%s: answer position smallest..largest %s; wrong choices from first picks %d%%, next %d%%, filler %d%%" % [
			GradesLib.name_of(grade),
			str(rank_counts.map(func(n): return "%d%%" % roundi(100.0 * n / PER_GRADE))),
			roundi(100.0 * tier_counts[0] / wrongs),
			roundi(100.0 * tier_counts[1] / wrongs),
			roundi(100.0 * tier_counts[2] / wrongs)])
	return true


func _check_attack(atk, top: int) -> bool:
	var where := "grade %d dice %s target %d choices %s" % [atk.grade, str(atk.dice), atk.target, str(atk.choices)]
	if not check(atk.choices.size() == 4, "not 4 choices: " + where):
		return false
	# Solvable, and the stored answer is the real answer.
	var expected: int
	match atk.kind:
		Attack.Kind.ONE_DIE:
			expected = atk.dice[0]
		Attack.Kind.TWO_DICE:
			expected = atk.dice[0] + atk.dice[1]
		Attack.Kind.DIE_AND_TARGET:
			expected = atk.target - atk.dice[0]
		Attack.Kind.MOVE_AND_SLIP:
			expected = atk.dice[0] - atk.dice[1]
	if not check(atk.answer == expected, "wrong answer %d, expected %d: %s" % [atk.answer, expected, where]):
		return false
	for d in atk.dice:
		if not check(d >= 1 and d <= 6, "die out of range: " + where):
			return false
	# Exactly one right choice, all different, all in range.
	var right := 0
	for v in atk.choices:
		if v == atk.answer:
			right += 1
		if not check(v >= 1 and v <= top, "choice out of range: " + where):
			return false
		if not check(atk.choices.count(v) == 1, "repeated choice: " + where):
			return false
	if not check(right == 1, "%d right choices: %s" % [right, where]):
		return false
	if not check(atk.choices[atk.answer_index] == atk.answer, "answer_index wrong: " + where):
		return false
	# Every wrong choice is an allowed near miss.
	var allowed: Array = []
	for tier in AttackGen.near_miss_tiers(atk):
		allowed.append_array(tier)
	for v in atk.choices:
		if v != atk.answer and not check(allowed.has(v), "%d is not a near miss: %s" % [v, where]):
			return false
	# Filler (plus or minus three) only when nothing nearer was free on that side.
	var tiers: Array = AttackGen.near_miss_tiers(atk)
	for v in atk.choices:
		if v == atk.answer or tiers[0].has(v) or tiers[1].has(v):
			continue
		var side_below: bool = v < atk.answer
		for u in tiers[0] + tiers[1]:
			if u < 1 or u > top or u == atk.answer or (u < atk.answer) != side_below:
				continue
			if not check(atk.choices.has(u), "filler %d used while %d was free: %s" % [v, u, where]):
				return false
	return true
