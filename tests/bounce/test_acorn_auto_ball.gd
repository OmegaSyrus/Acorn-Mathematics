extends "res://tests/fight/fight_test_base.gd"
## Acorn Match Bounce (the children's mother, 2026-10-28): no naming step.
## The ball takes the boss's roll and the pegs show numerals; above Acorn the
## child still names the peg and the pegs show dots.

const BounceFight = preload("res://logic/bounce/bounce_fight.gd")
const SeededRng = preload("res://logic/core/rng.gd")


func test_acorn_ball_takes_the_roll() -> bool:
	var f = BounceFight.new(SeededRng.new(9), 1)
	check(f.auto_name(), "Acorn skips naming")
	check(f.peg_labels() == "numerals", "Acorn pegs show numerals")
	for shot in 6:
		check(f.ball_shows() == f.target, "the ball shows the boss's roll")
		f.name_for_child()
		check(f.named_right, "the ball is always named right")
		f.fire(0)
		f.sim.run()
		var out: Dictionary = f.end_shot()
		if out["state"] != BounceFight.State.NAMING:
			break
	return true


func test_sprout_still_names_the_peg() -> bool:
	var f = BounceFight.new(SeededRng.new(9), 2)
	check(not f.auto_name(), "Sprout names the peg")
	check(f.peg_labels() == "dots", "Sprout pegs show dots")
	check(f.ball_shows() == f.ball_value, "Sprout ball shows its own die")
	return true
