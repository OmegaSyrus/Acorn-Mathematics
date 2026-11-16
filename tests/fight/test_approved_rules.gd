extends "res://tests/fight/fight_test_base.gd"
## The three fight rules Terrence approved on 2026-10-26, checked on their own
## so a change that breaks one fails here by name:
## 1. Sapling: die + ? = target, and the missing number is a die face (1 to 6).
## 2. Oak: the move die is always bigger than the slip die.
## 3. The duel asks each grade's normal question, with numerals to pick from.

const AttackGen = preload("res://logic/fight/attack_gen.gd")
const Attack = preload("res://logic/fight/attack.gd")
const Fight = preload("res://logic/fight/fight.gd")
const Duel = preload("res://logic/fight/duel.gd")
const GradesLib = preload("res://logic/core/grades.gd")
const SeededRng = preload("res://logic/core/rng.gd")

const COUNT := 20000
const GRADES := [GradesLib.Grade.ACORN, GradesLib.Grade.SPROUT, GradesLib.Grade.SAPLING, GradesLib.Grade.OAK]
const KIND_OF := {
	GradesLib.Grade.ACORN: Attack.Kind.ONE_DIE,
	GradesLib.Grade.SPROUT: Attack.Kind.TWO_DICE,
	GradesLib.Grade.SAPLING: Attack.Kind.DIE_AND_TARGET,
	GradesLib.Grade.OAK: Attack.Kind.MOVE_AND_SLIP,
}


func test_sapling_missing_number_is_a_die_face() -> bool:
	var rng = SeededRng.new(301)
	var seen := {}
	for i in COUNT:
		var atk = AttackGen.generate(rng, GradesLib.Grade.SAPLING)
		if not check(atk.kind == Attack.Kind.DIE_AND_TARGET, "Sapling attack is die + ? = target"):
			return true
		if not check(atk.dice.size() == 1 and atk.dice[0] + atk.answer == atk.target,
				"die + answer != target: %s" % str(atk.to_dict())):
			return true
		if not check(atk.answer >= 1 and atk.answer <= 6, "missing number %d is not a die face" % atk.answer):
			return true
		seen[atk.answer] = true
	check(seen.size() == 6, "every face 1 to 6 shows up as the missing number")
	return true


func test_oak_move_die_is_always_bigger() -> bool:
	var rng = SeededRng.new(401)
	for i in COUNT:
		var atk = AttackGen.generate(rng, GradesLib.Grade.OAK)
		if not check(atk.kind == Attack.Kind.MOVE_AND_SLIP and atk.dice.size() == 2, "Oak attack is move and slip"):
			return true
		var move: int = atk.dice[0]
		var slip: int = atk.dice[1]
		if not check(move > slip, "move %d is not bigger than slip %d" % [move, slip]):
			return true
		if not check(atk.answer == move - slip and atk.answer >= 1 and atk.answer <= 5,
				"difference %d out of 1 to 5" % atk.answer):
			return true
	return true


func test_duel_asks_each_grades_question_with_numerals() -> bool:
	for grade in GRADES:
		var d = Duel.new(SeededRng.new(500 + grade), grade, "lava_miniboss")
		check(d.choice_style == Fight.ChoiceStyle.NUMERALS, "%s duel shows numerals" % GradesLib.name_of(grade))
		for i in 50:
			check(d.attack.kind == KIND_OF[grade], "%s duel asks the %s question" % [GradesLib.name_of(grade), GradesLib.name_of(grade)])
			check(d.attack.choices.size() == 4 and d.attack.choices.count(d.attack.answer) == 1,
					"%s duel: one right numeral of four" % GradesLib.name_of(grade))
			d.choose(d.attack.answer_index if i % 2 == 0 else (d.attack.answer_index + 1) % 4)
			if d.is_over():
				d.restart()
			else:
				d.next_exchange()
	return true
