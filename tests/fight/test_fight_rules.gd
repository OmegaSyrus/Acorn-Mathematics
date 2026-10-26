extends "res://tests/fight/fight_test_base.gd"
## The exchange state machine, hearts, chests and mimics, and the duel.

const Fight = preload("res://logic/fight/fight.gd")
const Duel = preload("res://logic/fight/duel.gd")
const Chest = preload("res://logic/fight/chest.gd")
const GradesLib = preload("res://logic/core/grades.gd")
const SeededRng = preload("res://logic/core/rng.gd")

const SPROUT := 2


func _wrong_index(f) -> int:
	return (f.attack.answer_index + 1) % 4


func test_right_answer_parries_and_monster_loses_a_heart() -> bool:
	var f = Fight.new(SeededRng.new(1), SPROUT, "blorp", 3)
	check(f.state == Fight.State.WIND_UP, "starts in wind-up")
	check(f.hero_hearts == 3 and f.monster_hearts == 3, "3 hearts each")
	var out: Dictionary = f.choose(f.attack.answer_index)
	check(out.right, "right answer reported right")
	check(out.monster_hearts == 2 and out.hero_hearts == 3, "monster lost one heart")
	check(f.state == Fight.State.RESOLVING, "resolving after a parry")
	f.next_exchange()
	check(f.state == Fight.State.WIND_UP, "next exchange winds up")
	return true


func test_wrong_answer_lands_the_hit() -> bool:
	var f = Fight.new(SeededRng.new(2), SPROUT, "blorp", 3)
	var out: Dictionary = f.choose(_wrong_index(f))
	check(not out.right, "wrong answer reported wrong")
	check(out.hero_hearts == 2 and out.monster_hearts == 3, "hero lost one heart")
	check(out.answer == f.attack.answer, "outcome names the answer for the numeral fade-in")
	return true


func test_three_wrong_answers_lose_the_fight_and_restart_the_area() -> bool:
	var f = Fight.new(SeededRng.new(3), SPROUT, "blorp", 3)
	for i in 3:
		f.choose(_wrong_index(f))
		if i < 2:
			f.next_exchange()
	check(f.state == Fight.State.LOST, "lost after 3 hits")
	check(f.on_loss == Fight.OnLoss.RESTART_AREA, "a lost fight restarts the area")
	return true


func test_beating_the_monster_wins() -> bool:
	var f = Fight.new(SeededRng.new(4), SPROUT, "craggy", 4)
	for i in 4:
		f.choose(f.attack.answer_index)
		if i < 3:
			f.next_exchange()
	check(f.state == Fight.State.WON and f.monster_hearts == 0, "won after 4 parries")
	return true


func test_every_fight_starts_with_fresh_hearts() -> bool:
	var rng = SeededRng.new(5)
	var f = Fight.new(rng, SPROUT, "blorp", 3)
	f.choose(_wrong_index(f))
	var g = Fight.new(rng, SPROUT, "blorp", 3)
	check(g.hero_hearts == 3, "hearts refill for the next fight")
	return true


func test_normal_chest() -> bool:
	check(Chest.resolve(false, true) == Chest.Result.OPENED, "right answer opens")
	check(Chest.resolve(false, false) == Chest.Result.STAYS_SHUT, "wrong answer stays shut")
	return true


func test_mimic_is_a_fight_either_way() -> bool:
	check(Chest.resolve(true, true) == Chest.Result.MIMIC_FIGHT, "mimic fights after a right answer")
	check(Chest.resolve(true, false) == Chest.Result.MIMIC_FIGHT, "mimic fights after a wrong answer")
	var first = Chest.mimic_fight(SeededRng.new(6), SPROUT, true)
	check(first.monster_hearts == first.monster_max_hearts - 1, "right answer gives the first strike")
	var none = Chest.mimic_fight(SeededRng.new(6), SPROUT, false)
	check(none.monster_hearts == none.monster_max_hearts, "wrong answer: mimic at full hearts")
	check(none.hero_hearts == 3, "hero has 3 hearts against a mimic")
	check(none.on_loss == Fight.OnLoss.RESTART_AREA, "losing to a mimic restarts the area")
	return true


func test_duel_uses_numerals_and_restarts_itself() -> bool:
	var d = Duel.new(SeededRng.new(7), SPROUT, "lava_miniboss")
	check(d.choice_style == Fight.ChoiceStyle.NUMERALS, "duel shows numerals")
	check(d.on_loss == Fight.OnLoss.RESTART_DUEL, "losing the duel restarts the duel only")
	check(d.monster_hearts == 3 and d.hero_hearts == 3, "3 hearts each")
	d.choose(d.attack.answer_index)
	d.next_exchange()
	for i in 3:
		d.choose(_wrong_index(d))
		if i < 2:
			d.next_exchange()
	check(d.state == Fight.State.LOST, "duel lost")
	d.restart()
	check(d.state == Fight.State.WIND_UP, "duel winds up again")
	check(d.hero_hearts == 3 and d.monster_hearts == 3, "fresh hearts after restart")
	return true


func test_same_seed_same_taps_same_fight() -> bool:
	var taps := [0, 3, 1, 2, 2, 0, 1, 3, 0, 0, 1, 2]
	var a := _replay(42, taps)
	var b := _replay(42, taps)
	check(a == b, "replay differs")
	check(a != _replay(43, taps), "a different seed gives a different fight")
	return true


func _replay(seed_value: int, taps: Array) -> Array:
	var log := []
	var rng = SeededRng.new(seed_value)
	var f = Fight.new(rng, SPROUT, "craggy", 4)
	for t in taps:
		log.append(f.attack.to_dict())
		log.append(f.choose(t))
		if f.is_over():
			f = Fight.new(rng, SPROUT, "craggy", 4)
		else:
			f.next_exchange()
	return log
