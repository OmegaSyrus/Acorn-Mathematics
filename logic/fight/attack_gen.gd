extends RefCounted
## Builds monster attacks: the dice the monster swings with, the right answer,
## and four choices (one right, three near misses). Pure logic, no nodes.
##
## Near-miss rules (plan section 05):
## - Wrong choices are numbers a child really mixes up. First pick: one of the
##   attack dice on its own, the answer plus one, the answer minus one, and
##   at Sapling the target itself. Next: the answer plus or minus two, and at
##   Oak the dice added instead of subtracted. Plus or minus three is only a
##   filler, used when nothing nearer fits on that side.
## - Every choice is a whole number from 1 up to the grade's top value, all
##   four are different, and exactly one is right.
## - Where the right answer sits among the four (smallest, second, third,
##   largest) is drawn first, evenly, and the dice are rolled again until
##   the near misses can fill that spot. So "always tap the biggest" or
##   "always tap the smallest" wins exactly as often as guessing.

const Attack = preload("res://logic/fight/attack.gd")
const GradesLib = preload("res://logic/core/grades.gd")

const CHOICE_COUNT := 4
const MIN_VALUE := 1
## Rolls tried for one attack before giving up. The rarest case (Oak with the
## answer as the largest choice) fits about one roll in eight.
const MAX_ROLLS := 1000


## Largest value a choice can show. Acorn stays on one die.
static func max_value(grade: int) -> int:
	return 6 if grade == GradesLib.Grade.ACORN else 12


## Every value the rules allow as a wrong choice for this attack, in tiers.
## Tiers 0 and 1 are near misses; tier 2 is filler. Used by the generator
## and by the fuzz tests.
static func near_miss_tiers(attack) -> Array:
	var a: int = attack.answer
	var primary: Array[int] = [a - 1, a + 1]
	var secondary: Array[int] = [a - 2, a + 2]
	match attack.kind:
		Attack.Kind.TWO_DICE:
			primary.append_array(attack.dice)
		Attack.Kind.DIE_AND_TARGET:
			primary.append(attack.dice[0])
			primary.append(attack.target)
		Attack.Kind.MOVE_AND_SLIP:
			primary.append_array(attack.dice)
			secondary.append(attack.dice[0] + attack.dice[1])
	return [primary, secondary, [a - 3, a + 3]]


static func generate(rng, grade: int):
	# How many of the three wrong choices sit below the answer.
	var below_count: int = rng.randi_range(0, CHOICE_COUNT - 1)
	var above_count: int = CHOICE_COUNT - 1 - below_count
	for roll in MAX_ROLLS:
		var attack = _roll(rng, grade)
		if attack == null:
			return null
		var below := _side(attack, true)
		var above := _side(attack, false)
		if _count(below) >= below_count and _count(above) >= above_count:
			var choices: Array[int] = [attack.answer]
			choices.append_array(_take(rng, below, below_count))
			choices.append_array(_take(rng, above, above_count))
			rng.shuffle(choices)
			attack.choices.assign(choices)
			attack.answer_index = choices.find(attack.answer)
			return attack
	assert(false, "AttackGen: no roll fits the near-miss rules")
	return null


## Rolls the monster's dice for the grade and works out the answer.
static func _roll(rng, grade: int):
	var attack = Attack.new()
	attack.grade = grade
	match grade:
		GradesLib.Grade.ACORN:
			attack.kind = Attack.Kind.ONE_DIE
			attack.dice.assign([rng.randi_range(1, 6)])
			attack.answer = attack.dice[0]
		GradesLib.Grade.SPROUT:
			attack.kind = Attack.Kind.TWO_DICE
			attack.dice.assign([rng.randi_range(1, 6), rng.randi_range(1, 6)])
			attack.answer = attack.dice[0] + attack.dice[1]
		GradesLib.Grade.SAPLING:
			# Die + ? = target. The missing number is a die face too.
			attack.kind = Attack.Kind.DIE_AND_TARGET
			var missing: int = rng.randi_range(1, 6)
			attack.dice.assign([rng.randi_range(1, 6)])
			attack.target = attack.dice[0] + missing
			attack.answer = missing
		GradesLib.Grade.OAK:
			# Move die minus slip die. The move die is always the bigger one,
			# so the difference is 1 to 5 and never zero.
			attack.kind = Attack.Kind.MOVE_AND_SLIP
			var move: int = rng.randi_range(2, 6)
			var slip: int = rng.randi_range(1, move - 1)
			attack.dice.assign([move, slip])
			attack.answer = move - slip
		_:
			push_error("AttackGen: unknown grade %d" % grade)
			return null
	return attack


## The allowed wrong values on one side of the answer, grouped by tier.
## A value that appears in two tiers counts only in the nearer one.
static func _side(attack, below: bool) -> Array:
	var a: int = attack.answer
	var top := max_value(attack.grade)
	var seen: Array[int] = []
	var tiers: Array = []
	for tier in near_miss_tiers(attack):
		var kept: Array[int] = []
		for v in tier:
			if v < MIN_VALUE or v > top or v == a or (v < a) != below or seen.has(v):
				continue
			seen.append(v)
			kept.append(v)
		tiers.append(kept)
	return tiers


static func _count(tiers: Array) -> int:
	var n := 0
	for t in tiers:
		n += t.size()
	return n


## Takes `n` values, nearest tier first, shuffling within each tier.
static func _take(rng, tiers: Array, n: int) -> Array[int]:
	var out: Array[int] = []
	for t in tiers:
		if out.size() >= n:
			break
		var pool: Array[int] = t.duplicate()
		rng.shuffle(pool)
		out.append_array(pool.slice(0, n - out.size()))
	return out
