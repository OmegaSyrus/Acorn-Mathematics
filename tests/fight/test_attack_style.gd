extends "res://tests/fight/fight_test_base.gd"
## How the monster's dice are shown (Terrence, 2026-10-28): at Acorn a plain
## match of dots to dots was too simple, so the die shows a numeral and the
## shields show dots. Other grades, and the duel, keep dots on the dice.

const Fight = preload("res://logic/fight/fight.gd")
const Duel = preload("res://logic/fight/duel.gd")
const GradesLib = preload("res://logic/core/grades.gd")
const SeededRng = preload("res://logic/core/rng.gd")


func test_acorn_fight_shows_a_numeral_and_dot_choices() -> bool:
	var f = Fight.new(SeededRng.new(5), GradesLib.Grade.ACORN, "blorp", 3)
	check(f.attack_style() == Fight.AttackStyle.NUMERAL, "Acorn monster dice show a numeral")
	check(f.choice_style == Fight.ChoiceStyle.DICE, "Acorn shields still show dots")
	return true


func test_other_grades_show_dots() -> bool:
	for g in [GradesLib.Grade.SPROUT, GradesLib.Grade.SAPLING, GradesLib.Grade.OAK]:
		var f = Fight.new(SeededRng.new(5), g, "blorp", 3)
		check(f.attack_style() == Fight.AttackStyle.DOTS, "grade %d dice show dots" % g)
	return true


func test_duel_keeps_dots_on_the_dice() -> bool:
	# the duel already crosses over: dots on the dice, numerals on the choices
	for g in [GradesLib.Grade.ACORN, GradesLib.Grade.OAK]:
		var d = Duel.new(SeededRng.new(5), g, "lava_miniboss")
		check(d.attack_style() == Fight.AttackStyle.DOTS, "grade %d duel dice show dots" % g)
	return true
