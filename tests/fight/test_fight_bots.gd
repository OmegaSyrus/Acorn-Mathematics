extends "res://tests/fight/fight_test_base.gd"
## Gate 2 (plan, Phase 2): the random bot beats a 3-heart monster in no more
## than 15% of fights and the perfect bot never loses. Same check for the
## duel. The pattern bots are reported so we can see the answer's position
## gives nothing away; they are held to the same 15% bar as random.

const Fight = preload("res://logic/fight/fight.gd")
const Duel = preload("res://logic/fight/duel.gd")
const Bots = preload("res://tests/fight/bots.gd")
const GradesLib = preload("res://logic/core/grades.gd")
const SeededRng = preload("res://logic/core/rng.gd")

const FIGHTS := 5000
const GATE_RANDOM_3_HEARTS := 0.15
const GRADES := [1, 2, 3, 4]


func test_gate_random_and_perfect_vs_3_heart_monster() -> bool:
	_run_bots("3-heart monster", func(rng, g): return Fight.new(rng, g, "blorp", 3), GATE_RANDOM_3_HEARTS)
	return true


func test_bots_vs_4_heart_monster() -> bool:
	_run_bots("4-heart monster", func(rng, g): return Fight.new(rng, g, "craggy", 4), 0.06)
	return true


func test_bots_vs_miniboss_duel() -> bool:
	_run_bots("miniboss duel", func(rng, g): return Duel.new(rng, g, "lava_miniboss"), GATE_RANDOM_3_HEARTS)
	return true


func _run_bots(label: String, make: Callable, max_guess_rate: float) -> void:
	for g in GRADES:
		var line := "%s, %s:" % [label, GradesLib.name_of(g)]
		for bot in Bots.NAMES:
			var game_rng = SeededRng.new(7000 + g)
			var bot_rng = SeededRng.new(9000 + g)
			var wins := 0
			for i in FIGHTS:
				if Bots.play(make.call(game_rng, g), bot, bot_rng):
					wins += 1
			var rate := float(wins) / FIGHTS
			line += " %s %.1f%%" % [bot, rate * 100.0]
			if bot == "perfect":
				check(wins == FIGHTS, "%s: perfect bot lost %d fights" % [line, FIGHTS - wins])
			else:
				check(rate <= max_guess_rate, "%s %s bot won %.1f%%, over %.0f%%" % [label, bot, rate * 100.0, max_guess_rate * 100.0])
		notes.append(line)
