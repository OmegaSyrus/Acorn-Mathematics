extends "res://tests/fight/fight_test_base.gd"
## How the choices are shown (Terrence, 2026-10-28): at Acorn a plain match
## of dots to dots was too simple, so the rolled die keeps its dots and the
## shields show numerals; the child picks the number that matches the dots.
## Other grades keep dice faces on the shields; the duel is numerals everywhere.

const Fight = preload("res://logic/fight/fight.gd")
const Duel = preload("res://logic/fight/duel.gd")
const GradesLib = preload("res://logic/core/grades.gd")
const SeededRng = preload("res://logic/core/rng.gd")


func test_acorn_fight_picks_a_numeral() -> bool:
	var f = Fight.new(SeededRng.new(5), GradesLib.Grade.ACORN, "blorp", 3)
	check(f.choice_style == Fight.ChoiceStyle.NUMERALS, "Acorn shields show numerals")
	check(f.attack.dice.size() == 1 and f.attack.answer == f.attack.dice[0], "the answer is the die's count")
	return true


func test_other_grades_pick_dice_faces() -> bool:
	for g in [GradesLib.Grade.SPROUT, GradesLib.Grade.SAPLING, GradesLib.Grade.OAK]:
		var f = Fight.new(SeededRng.new(5), g, "blorp", 3)
		check(f.choice_style == Fight.ChoiceStyle.DICE, "grade %d shields show dice faces" % g)
	return true


func test_duel_picks_numerals_at_every_grade() -> bool:
	for g in [GradesLib.Grade.ACORN, GradesLib.Grade.OAK]:
		var d = Duel.new(SeededRng.new(5), g, "lava_miniboss")
		check(d.choice_style == Fight.ChoiceStyle.NUMERALS, "grade %d duel shows numerals" % g)
	return true
