extends "res://tests/support/test_case.gd"

const Rng := preload("res://logic/core/rng.gd")
const MoveGen := preload("res://logic/core/move_gen.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const Content := preload("res://logic/core/content.gd")


func _data() -> Dictionary:
	return JsonUtil.load_file("res://tests/vectors/scroll.json")


func _apply(run: ScrollRun, inp: String) -> void:
	if inp == "roll":
		run.roll()
	elif inp == "win":
		run.resolve_fight(true)
	elif inp == "lose":
		run.resolve_fight(false)
	else:
		run.choose(inp.substr(5).to_int())


func test_move_vectors() -> bool:
	var grade: Dictionary = Content.grades()[1]
	for c in _data()["moves"]:
		var r := Rng.new(c["seed"])
		eq(MoveGen.generate_move(grade, r, c["room"]), c["problem"], "move room %d seed %d" % [c["room"], c["seed"]])
		eq(r.get_state(), c["state_after"], "move rng draws room %d seed %d" % [c["room"], c["seed"]])
	return true


func test_scroll_replay_vectors() -> bool:
	for c in _data()["cases"]:
		var run := ScrollRun.new(Content.area(c["area"]), Content.grades()[c["grade"]], c["seed"])
		for inp in c["inputs"]:
			_apply(run, inp)
		eq(run.events, c["log"], "scroll replay seed %d" % c["seed"])
		eq(run.to_save(), c["final"], "scroll final seed %d" % c["seed"])
		check(run.phase == c["phase"], "scroll phase seed %d" % c["seed"])
	return true


## Acorn moves: answer 1..5 (or less near the goal), the sum or difference
## matches the dice, dice 1..6, and every op and distance turns up.
func test_move_fuzz() -> bool:
	var grade: Dictionary = Content.grades()[1]
	var r := Rng.new(4242)
	var seen := {}
	for i in fuzz_count(100000):
		var room := 1 + i % 8
		var p := MoveGen.generate_move(grade, r, room)
		var a: int = p["dice"][0]
		var b: int = p["dice"][1]
		var m := mini(5, room)
		var ok: bool = p["answer"] >= 1 and p["answer"] <= m and a >= 1 and a <= 6 and b >= 1 and b <= 6
		ok = ok and p["answer"] == (a + b if p["op"] == "add" else a - b) and p["choices"].size() == m
		if not ok:
			failures.append("bad move %s room %d" % [JsonUtil.canonical(p), room])
			return true
		seen["%s%d" % [p["op"], p["answer"]]] = true
	for k in ["add2", "add5", "sub1", "sub5"]:
		check(seen.has(k), "never saw " + k)
	return true


## Terrence 2026-11-08: 3 lives. A wrong stone costs a heart and the same
## guess is rolled again; losing the last heart sinks and restarts.
func test_wrong_space_costs_a_heart_then_restarts() -> bool:
	var run := ScrollRun.new(Content.area("lava_scroll"), Content.grades()[1], 7)
	var answer: int = run.roll()["answer"]
	var out := run.choose((run.problem["answer_index"] + 1) % run.problem["choices"].size())
	check(out["result"] == "miss" and not out["restarted"], "first wrong stone is a miss")
	check(run.hearts == 2 and run.pos == 0 and run.attempt == 1 and run.phase == ScrollRun.AWAIT_ROLL, "a heart lost, roll again")
	check(int(run.roll()["answer"]) == answer, "the same guess is asked again")
	run.choose((run.problem["answer_index"] + 1) % run.problem["choices"].size())
	check(run.hearts == 1, "second miss")
	run.roll()
	out = run.choose((run.problem["answer_index"] + 1) % run.problem["choices"].size())
	check(out["result"] == "sink" and out["restarted"], "the last heart sinks and restarts")
	check(run.pos == 0 and run.attempt == 2 and run.hearts == 3, "restart with 3 hearts")
	return true


func test_perfect_player_crosses() -> bool:
	for i in 300:
		var run := ScrollRun.new(Content.area("lava_scroll"), Content.grades()[1], 100 + i)
		var guard := 0
		while run.phase != ScrollRun.CLEARED and guard < 500:
			guard += 1
			if run.phase == ScrollRun.AWAIT_FIGHT:
				run.resolve_fight(true)
			else:
				run.roll()
				run.choose(run.problem["answer_index"])
		check(run.phase == ScrollRun.CLEARED and run.attempt == 1 and run.pos == run.length(), "perfect run %d" % i)
	return true


## Terrence 2026-11-07: a run is 9 guesses and the crossing has as many
## stones as the 9 answers add up to. Each roll's answer is the next one
## drawn; a sink starts a new run with new answers and a new crossing.
func test_run_is_9_guesses() -> bool:
	var lengths := {}
	for i in 600:
		var run := ScrollRun.new(Content.area("lava_scroll"), Content.grades()[1], 900 + i)
		if i % 3 == 0:
			for k in ScrollRun.HERO_HEARTS:  # every heart lost: a sink
				run.roll()
				run.choose((run.problem["answer_index"] + 1) % run.problem["choices"].size())
			check(run.rolls == 0 and run.answers.size() == 9, "a sink starts a new run of 9")
		var answers: Array = run.answers.duplicate()
		var total := 0
		for a in answers:
			total += int(a)
		check(run.length() == total, "seed %d: %d stones for answers %s" % [900 + i, run.length(), answers])
		var guard := 0
		while run.phase != ScrollRun.CLEARED and guard < 100:
			guard += 1
			if run.phase == ScrollRun.AWAIT_FIGHT:
				run.resolve_fight(true)
			else:
				var p := run.roll()
				check(p["answer"] == answers[run.rolls - 1], "roll %d answers %d" % [run.rolls, p["answer"]])
				run.choose(run.problem["answer_index"])
		check(run.rolls == 9 and run.attempt == (2 if i % 3 == 0 else 1), "seed %d took %d rolls" % [900 + i, run.rolls])
		lengths[run.length()] = true
	check(lengths.size() > 10, "crossing lengths vary: %s" % [lengths.keys()])
	return true


## Every step's event sits on the stone its answers reach, so a perfect run
## meets every chest and monster; an opened chest stays empty in a new layout.
func test_steps_land_on_the_answers() -> bool:
	var area := Content.area("lava_scroll")
	var run := ScrollRun.new(area, Content.grades()[1], 31)
	var at := 0
	for k in 8:
		at += int(run.answers[k])
		var st: Dictionary = area["steps"][k]
		check(run.space_at(at).get("type") == st["type"], "step %d on stone %d" % [k + 1, at])
	run.roll()
	var first := run.choose(run.problem["answer_index"])
	check(first["result"] == "chest" and run.looted == [1], "the first stone is the first chest")
	run.roll()
	run.choose(run.problem["answer_index"])
	check(run.phase == ScrollRun.AWAIT_FIGHT, "the second stone is Blorp")
	run.resolve_fight(false)
	check(run.is_looted(int(run.answers[0])), "chest 1 stays empty after a restart")
	return true


func test_save_resume() -> bool:
	var run := ScrollRun.new(Content.area("lava_scroll"), Content.grades()[1], 11)
	for k in 4:
		if run.phase == ScrollRun.AWAIT_FIGHT:
			run.resolve_fight(true)
		run.roll()
		run.choose(run.problem["answer_index"])
	var data := run.to_save()
	var again := ScrollRun.new(Content.area("lava_scroll"), Content.grades()[1], data["seed"])
	again.restore(data)
	eq(again.to_save(), data, "resume state")
	if run.phase == ScrollRun.AWAIT_ROLL:
		eq(again.roll(), run.roll(), "resumed run rolls the same problem")
	return true


## The crossing before guesses (40 fixed stones), for the walk-over rules,
## which still hold for any area that names its spaces.
const FIXED := {
	"id": "fixed_scroll", "type": "scroll", "grades": [1], "length": 40,
	"chest_gems": {"common": 1, "rare": 2, "rare_in": 6},
	"spaces": [
		{"at": 4, "type": "chest"}, {"at": 9, "type": "monster", "monster": "blorp"},
		{"at": 13, "type": "chest"}, {"at": 18, "type": "chest"},
		{"at": 22, "type": "monster", "monster": "surtling"}, {"at": 27, "type": "chest"},
		{"at": 31, "type": "chest"}, {"at": 35, "type": "monster", "monster": "craggy"},
	],
}


## Rigs the next move so the right answer is `dist` spaces ahead.
func _force_move(run: ScrollRun, dist: int) -> int:
	run.roll()
	run.problem["answer_index"] = dist - 1
	return dist - 1


## Walking over a chest opens it on the way; walking over a monster stops
## there for the fight, and a win finishes the walk.
func test_walking_over_triggers() -> bool:
	var run := ScrollRun.new(FIXED, Content.grades()[1], 5)
	run.pos = 2
	run.target = 2
	var out := run.choose(_force_move(run, 5))  # 3..7 passes the chest on 4
	check(out["result"] == "hop" and out["to"] == 7, "walked to 7: %s" % str(out))
	eq(out["chests"].size(), 1, "one chest on the way")
	check(out["chests"][0]["at"] == 4 and run.looted.has(4), "the chest on 4 opened")
	check(run.gems == out["gems"] and out["gems"] >= 1, "its gems counted")
	out = run.choose(_force_move(run, 5))  # 8..12 meets Blorp on 9
	check(out["result"] == "monster" and out["to"] == 9 and run.pos == 9, "stopped at the monster: %s" % str(out))
	check(run.phase == ScrollRun.AWAIT_FIGHT and run.target == 12, "fight pending, walk not done")
	var save := run.to_save()
	var again := ScrollRun.new(FIXED, Content.grades()[1], save["seed"])
	again.restore(save)
	eq(again.to_save(), save, "resume mid-walk")
	var won := run.resolve_fight(true)
	check(won.has("walk") and won["walk"]["to"] == 12 and run.pos == 12, "won fight finishes the walk: %s" % str(won))
	check(run.phase == ScrollRun.AWAIT_ROLL and run.target == 12, "back to rolling")
	run.choose(_force_move(run, 1))  # lands on the chest on 13
	check(run.looted.has(13), "landing on a chest still opens it")
	return true


func test_lost_fight_on_the_way_restarts() -> bool:
	var run := ScrollRun.new(FIXED, Content.grades()[1], 6)
	run.pos = 7
	run.target = 7
	run.choose(_force_move(run, 4))
	check(run.pos == 9 and run.phase == ScrollRun.AWAIT_FIGHT, "met the monster on 9")
	var out := run.resolve_fight(false)
	check(out["restarted"] and run.pos == 0 and run.target == 0 and not out.has("walk"), "lost: back to the start")
	return true


## Terrence 2026-11-07: a heart on a stone after the first 2 right answers.
## It adds a heart, the hearts carry into and out of fights, and a restart
## gives back 3 hearts and the heart stone.
func test_heart_stone_and_hearts_carry() -> bool:
	var area := Content.area("lava_scroll")
	var run := ScrollRun.new(area, Content.grades()[1], 11)
	check(run.hearts == 3, "3 hearts to start")
	var heart_at := -1
	for i in range(1, run.length()):
		if run.space_at(i).get("type") == "heart":
			heart_at = i
	check(heart_at > 0, "the crossing has a heart stone")
	check(int(run.space_at(heart_at)["after"]) == 3, "just past Blorp")
	var took := false
	while run.phase != ScrollRun.CLEARED and run.pos < heart_at:
		if run.phase == ScrollRun.AWAIT_FIGHT:
			run.resolve_fight(true, 2)  # won, but one heart lost
			check(run.hearts == 2, "a fight's lost heart stays lost")
			continue
		var p := run.roll()
		var out := run.choose(p["answer_index"])
		if out.get("hearts", []).has(heart_at):
			took = true
	check(took and run.hearts == 3, "the heart stone gives one back (%d)" % run.hearts)
	check(run.is_heart_taken(heart_at), "taken")
	var saved := run.to_save()
	var again := ScrollRun.new(area, Content.grades()[1], 11)
	again.restore(saved)
	check(again.hearts == 3 and again.is_heart_taken(heart_at), "hearts survive a save")
	for k in 3:
		var p2 := run.roll()
		run.choose((p2["answer_index"] + 1) % p2["choices"].size())
	check(run.attempt == 2, "three misses sink")
	check(run.hearts == 3 and run.hearts_taken.is_empty(), "a restart: 3 hearts and the heart stone back")
	return true
