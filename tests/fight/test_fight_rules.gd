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


func test_block_comes_first_and_a_right_block_costs_nothing() -> bool:
	var f = Fight.new(SeededRng.new(1), SPROUT, "blorp", 3)
	check(f.state == Fight.State.WIND_UP, "starts in wind-up")
	check(f.phase == Fight.Phase.BLOCK, "the monster attacks first")
	check(f.hero_hearts == 3 and f.monster_hearts == 3, "3 hearts each")
	var out: Dictionary = f.choose(f.attack.answer_index)
	check(out.right and out.phase == Fight.Phase.BLOCK, "right block reported")
	check(out.monster_hearts == 3 and out.hero_hearts == 3, "a block takes no heart from anyone")
	check(f.state == Fight.State.RESOLVING, "resolving after a block")
	f.next_exchange()
	check(f.state == Fight.State.WIND_UP and f.phase == Fight.Phase.BASH, "then the hero's shield bash")
	return true


func test_wrong_block_costs_a_hero_heart() -> bool:
	var f = Fight.new(SeededRng.new(2), SPROUT, "blorp", 3)
	var out: Dictionary = f.choose(_wrong_index(f))
	check(not out.right, "wrong answer reported wrong")
	check(out.hero_hearts == 2 and out.monster_hearts == 3, "hero lost one heart")
	check(out.answer == f.attack.answer, "outcome names the answer for the numeral fade-in")
	return true


func test_bash_right_costs_a_monster_heart_and_wrong_costs_nothing() -> bool:
	var f = Fight.new(SeededRng.new(3), SPROUT, "blorp", 3)
	f.choose(f.attack.answer_index)
	f.next_exchange()
	var out: Dictionary = f.choose(_wrong_index(f))
	check(out.phase == Fight.Phase.BASH and not out.right, "a missed bash")
	check(out.hero_hearts == 3 and out.monster_hearts == 3, "a missed bash loses no heart")
	f.next_exchange()
	check(f.phase == Fight.Phase.BLOCK, "the monster attacks again")
	f.choose(f.attack.answer_index)
	f.next_exchange()
	out = f.choose(f.attack.answer_index)
	check(out.monster_hearts == 2 and out.hero_hearts == 3, "a right bash costs the monster a heart")
	return true


func test_three_wrong_blocks_lose_the_fight_and_restart_the_area() -> bool:
	var f = Fight.new(SeededRng.new(3), SPROUT, "blorp", 3)
	while not f.is_over():
		f.choose(_wrong_index(f))
		if not f.is_over():
			f.next_exchange()
	check(f.state == Fight.State.LOST and f.hero_hearts == 0, "lost after 3 hits")
	check(f.exchange_count == 5, "3 blocks and 2 missed bashes")
	check(f.monster_hearts == 3, "missed bashes cost the monster nothing")
	check(f.on_loss == Fight.OnLoss.RESTART_AREA, "a lost fight restarts the area")
	return true


func test_beating_the_monster_wins() -> bool:
	var f = Fight.new(SeededRng.new(4), SPROUT, "craggy", 4)
	for i in 8:
		f.choose(f.attack.answer_index)
		if f.is_over():
			break
		f.next_exchange()
	check(f.state == Fight.State.WON and f.monster_hearts == 0, "won after 4 blocks and 4 bashes")
	check(f.exchange_count == 8, "4 blocks + 4 bashes")
	return true


func test_hearts_from_the_crossing_carry_in() -> bool:
	var f = Fight.new(SeededRng.new(4), SPROUT, "blorp", 3)
	f.set_hero_hearts(4)
	check(f.hero_hearts == 4 and f.hero_max_hearts == 4, "a picked-up heart makes 4")
	f.set_hero_hearts(2)
	check(f.hero_hearts == 2 and f.hero_max_hearts == 3, "a hurt hero starts with 2 of 3")
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
	check(d.monster_hearts == 5 and d.hero_hearts == 3, "the miniboss has 5 hearts, the hero 3")
	while not d.is_over():
		d.choose(_wrong_index(d))
		if not d.is_over():
			d.next_exchange()
	check(d.state == Fight.State.LOST, "duel lost")
	d.restart()
	check(d.state == Fight.State.WIND_UP and d.phase == Fight.Phase.BLOCK, "duel winds up again, block first")
	check(d.hero_hearts == 3 and d.monster_hearts == 5, "fresh hearts after restart")
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
