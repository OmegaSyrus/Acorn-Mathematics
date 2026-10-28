extends "res://tests/fight/fight_test_base.gd"
## Match Bounce rules: name the peg, ghosts and pops, ±1 pegs and combo
## damage, refills, balls and boss hearts, and seeded replay.

const BounceFight = preload("res://logic/bounce/bounce_fight.gd")
const BounceSim = preload("res://logic/bounce/bounce_sim.gd")
const BounceRules = preload("res://logic/bounce/bounce_rules.gd")
const SeededRng = preload("res://logic/core/rng.gd")
const JsonUtil = preload("res://logic/core/json_util.gd")

const ACORN := 1
const SPROUT := 2
const OAK := 4


## A column of pegs straight under the launcher, no walls. The ball fired
## straight down (aim 0) touches every one of them.
func _column_board(faces: Array, mods := []) -> Dictionary:
	var pegs := []
	for i in faces.size():
		pegs.append({"x": 480, "y": 160 + 70 * i, "face": faces[i]})
	return {"launcher": [480, 70], "floor_y": 540, "peg_radius": 20,
		"walls": [], "bumpers": [], "pegs": pegs, "mods": mods}


func _phys() -> Dictionary:
	return BounceFight.load_tuning()["physics"]


func _count(events: Array, type: String) -> int:
	return events.filter(func(e): return e["type"] == type).size()


func test_acorn_names_one_of_three_faces_and_target_is_1_to_3() -> bool:
	var rng = SeededRng.new(11)
	var aim_rng = SeededRng.new(12)
	for f in 30:
		var fight = BounceFight.new(rng, ACORN)
		while not fight.is_over():
			check(Array(fight.choices) == [1, 2, 3], "Acorn offers faces 1, 2, 3: %s" % str(fight.choices))
			check(fight.target >= 1 and fight.target <= 3, "Acorn target %d is 1 to 3" % fight.target)
			check(fight.ball_value == 0, "Acorn ball has no die")
			check(fight.answer_face == fight.target, "Acorn: the answer is the target's count")
			fight.name_peg(fight.choices.find(fight.answer_face))
			check(fight.live_count() >= 3, "Acorn: at least 3 live pegs on a shot (%d)" % fight.live_count())
			fight.fire(aim_rng.randi_range(-650, 650)).run()
			fight.end_shot()
	return true


func test_sum_and_difference_shots_are_solvable() -> bool:
	for grade in [SPROUT, OAK]:
		var rng = SeededRng.new(20 + grade)
		var fight = BounceFight.new(rng, grade)
		for i in 300:
			var need := BounceRules.needed_face(fight.rule, fight.ball_value, fight.target)
			check(need == fight.answer_face, "needed face matches the answer")
			check(fight.ball_value >= 1 and fight.ball_value <= 6, "ball is a die face")
			check(fight.choices.size() == 4 and fight.choices.count(fight.answer_face) == 1, "one right face of four")
			for c in fight.choices:
				check(c >= 1 and c <= 6, "choice %d is a die face" % c)
			if fight.rule == "difference":
				check(fight.ball_value > fight.answer_face and fight.target >= 1, "Oak: ball bigger than the peg")
			fight._new_shot()
	return true


func test_wrong_name_ghosts_through_everything() -> bool:
	var board := _column_board([2, 2, 2, 2])
	var sim = BounceSim.new(_phys(), board, [true, true, true, true], "match", 2, 0, false, 0)
	var events: Array = sim.run()
	check(sim.popped.is_empty() and sim.damage == 0, "nothing pops after a wrong name")
	check(_count(events, "whiff") == 4, "the ball whiffs through all four pegs")
	check(sim.ended == BounceSim.End.FLOOR, "the ball falls out the bottom")
	return true


func test_only_matching_pegs_pop() -> bool:
	var board := _column_board([1, 3, 2, 3])
	var sim = BounceSim.new(_phys(), board, [true, true, true, true], "match", 3, 0, true, 0)
	sim.run()
	for i in sim.popped:
		check(int(board["pegs"][i]["face"]) == 3, "only 3-pegs pop")
	check(sim.popped.size() >= 1, "the first 3-peg in the column pops")
	check(sim.damage == sim.popped.size(), "one heart per pop with no ±1 pegs")
	return true


func test_plus_one_peg_changes_the_ball_and_adds_a_combo_heart() -> bool:
	# Ball 3, target 7: the 4-pegs are live. After +1 the ball is 4 and only
	# the 3-pegs are live. Placed by hand so the test checks rules, not aim.
	var board := _column_board([3, 4], [{"x": 300, "y": 300, "add": 1}])
	var sim = BounceSim.new(_phys(), board, [true, true], "sum", 7, 3, true, 0)
	check(sim.is_live(1) and not sim.is_live(0), "ball 3: the 4-peg is live")
	sim.pos = Vector2(300, 300 - 32 + 2)
	sim.vel = Vector2(0, 50)
	var ev: Array = sim.step()
	check(_count(ev, "mod") == 1 and sim.ball_value == 4, "+1 peg makes the ball a 4")
	check(sim.is_live(0) and not sim.is_live(1), "ball 4: the 3-peg is live, the 4-peg ghosts")
	sim.pos = Vector2(480, 160 - 32 + 2)
	sim.vel = Vector2(0, 50)
	ev = sim.step()
	check(_count(ev, "pop") == 1 and sim.damage == 2, "pop after a ±1 peg is worth 2 hearts (%d)" % sim.damage)
	sim.pos = Vector2(300, 300 - 32 + 2)
	sim.vel = Vector2(0, 50)
	sim.step()
	check(sim.ball_value == 4, "a ±1 peg works once per shot")
	return true


func test_board_refills_when_too_few_pegs_are_left() -> bool:
	var fight = BounceFight.new(SeededRng.new(5), ACORN)
	for i in fight.peg_alive.size():
		fight.peg_alive[i] = false
	fight._new_shot()
	check(fight.refills == 1, "board refilled")
	check(not fight.peg_alive.has(false), "every peg is back")
	return true


func test_out_of_balls_loses_and_damage_wins() -> bool:
	var rng = SeededRng.new(9)
	var fight = BounceFight.new(rng, ACORN)
	var balls: int = fight.balls_left
	for i in balls:
		fight.name_peg((fight.choices.find(fight.answer_face) + 1) % fight.choices.size())
		check(not fight.named_right, "named wrong")
		fight.fire(0).run()
		var out: Dictionary = fight.end_shot()
		check(out["damage"] == 0, "a wrong name does no damage")
	check(fight.state == BounceFight.State.LOST, "out of balls is a loss")
	check(fight.boss_hearts == fight.boss_max_hearts, "boss untouched")

	var tuning: Dictionary = BounceFight.load_tuning()
	tuning["grades"]["1"]["boss_hearts"] = 1
	fight = BounceFight.new(SeededRng.new(9), ACORN, tuning)
	while not fight.is_over():
		fight.name_peg(fight.choices.find(fight.answer_face))
		fight.fire(_best_aim(fight))
		while fight.sim.ended == BounceSim.End.NONE:
			fight.sim.step()
			if fight.is_lethal():
				break
		fight.sim.run()
		fight.end_shot()
	check(fight.state == BounceFight.State.WON, "taking the last heart wins")
	return true


func _best_aim(fight) -> int:
	var best := 0
	var best_damage := -1
	for a in range(-650, 651, 50):
		var s = fight.preview_sim(a)
		s.run()
		if s.damage > best_damage:
			best_damage = s.damage
			best = a
	return best


func test_same_seed_same_taps_same_fight() -> bool:
	var a := _replay(77)
	check(a == _replay(77), "replay differs")
	check(a != _replay(78), "a different seed gives a different fight")
	return true


func _replay(seed_value: int) -> String:
	var rng = SeededRng.new(seed_value)
	var fight = BounceFight.new(rng, SPROUT)
	var log := []
	var taps := [0, 1, 2, 3, 2, 1]
	var aims := [-600, -250, 0, 120, 480, 650]
	for i in taps.size():
		if fight.is_over():
			break
		log.append([fight.target, fight.ball_value, fight.choices.duplicate()])
		fight.name_peg(taps[i])
		var events: Array = fight.fire(aims[i]).run()
		log.append(events)
		log.append(fight.end_shot())
	return JsonUtil.canonical(log)
