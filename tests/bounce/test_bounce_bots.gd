extends "res://tests/fight/fight_test_base.gd"
## Gate 3 bots (plan section 16, Phase 3). The math must matter: a bot that
## names a random face loses at least 85% of boss fights. Aim must matter
## but not carry: naming right and aiming at random stays at 2 pops a ball
## or less, and a bot that names right and picks the best of 27 aims always
## wins, so every board can be beaten. Numbers print as notes for tuning.

const BounceFight = preload("res://logic/bounce/bounce_fight.gd")
const SeededRng = preload("res://logic/core/rng.gd")

const FIGHTS := 120
const BEST_AIM_FIGHTS := 15
const NAMING_FIGHTS := 150


func test_gate_3_bots() -> bool:
	for grade in [1, 2]:
		var random_name := _play(grade, FIGHTS, 1000, "random_name")
		var random_aim := _play(grade, FIGHTS, 2000, "random_aim")
		var best_aim := _play(grade, BEST_AIM_FIGHTS, 3000, "best_aim")
		notes.append("Match Bounce grade %d: random name wins %d%%; right name, random aim %.2f pops a ball, wins %d%%; right name, best aim %.2f pops a ball, wins %d%%" % [
			grade, random_name.win_pct, random_aim.pops_per_ball, random_aim.win_pct,
			best_aim.pops_per_ball, best_aim.win_pct])
		check(random_name.win_pct <= 15, "grade %d: random-name bot wins %d%% (gate: 15%% or less)" % [grade, random_name.win_pct])
		check(random_aim.pops_per_ball <= 2.0, "grade %d: random aim pops %.2f a ball (gate: 2 or less)" % [grade, random_aim.pops_per_ball])
		check(best_aim.win_pct == 100, "grade %d: best-aim bot wins only %d%%" % [grade, best_aim.win_pct])
	return true


func _play(grade: int, fights: int, seed_base: int, bot: String) -> Dictionary:
	var wins := 0
	var pops := 0
	var balls := 0
	for f in fights:
		var fight = BounceFight.new(SeededRng.new(seed_base + f), grade)
		var hand = SeededRng.new(seed_base + 50000 + f)
		while not fight.is_over():
			if bot == "random_name":
				fight.name_peg(hand.randi_range(0, fight.choices.size() - 1))
			else:
				fight.name_peg(fight.choices.find(fight.answer_face))
			var aim: int = _best_aim(fight) if bot == "best_aim" else hand.randi_range(-650, 650)
			fight.fire(aim).run()
			pops += fight.end_shot()["pops"]
			balls += 1
		if fight.state == BounceFight.State.WON:
			wins += 1
	return {"win_pct": roundi(100.0 * wins / fights), "pops_per_ball": float(pops) / balls}


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


## Naming wins the boss (2026-11-12): a reviewer's bot that names every ball
## right and aims at random beat the Lava boss about 28 times in 100 but the
## others about 3. Every world's boss (each boss_grade in content/levels.json)
## now falls to that bot 60 to 80% of the time, while a bot that names at
## random still mostly loses.
func test_naming_right_wins_most_boss_fights() -> bool:
	var Content = load("res://logic/core/content.gd")
	var by_grade := {}
	for lv in Content.levels().values():
		var g := int(lv.get("boss_grade", 1))
		if not by_grade.has(g):
			by_grade[g] = []
		if not by_grade[g].has(lv["world"]):
			by_grade[g].append(lv["world"])
	var grades := by_grade.keys()
	grades.sort()
	for g in grades:
		var right := _play(g, NAMING_FIGHTS, 7000, "random_aim")
		var wrong := _play(g, NAMING_FIGHTS, 8000, "random_name")
		notes.append("boss grade %d (%s): right name, random aim wins %d%%; random name wins %d%%" % [
			g, ", ".join(by_grade[g]), right.win_pct, wrong.win_pct])
		check(right.win_pct >= 60 and right.win_pct <= 80, "boss grade %d: naming right wins %d%% (want 60 to 80%%)" % [g, right.win_pct])
		check(wrong.win_pct <= 15, "boss grade %d: random naming wins %d%% (want 15%% or less)" % [g, wrong.win_pct])
	return true
