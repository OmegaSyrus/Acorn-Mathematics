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


func test_wrong_space_sinks_and_restarts() -> bool:
	var run := ScrollRun.new(Content.area("lava_scroll"), Content.grades()[1], 7)
	run.roll()
	var wrong: int = (run.problem["answer_index"] + 1) % run.problem["choices"].size()
	var out := run.choose(wrong)
	check(out["result"] == "sink" and out["restarted"], "wrong space should sink and restart")
	check(run.pos == 0 and run.attempt == 2 and run.phase == ScrollRun.AWAIT_ROLL, "restart state")
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
		check(run.phase == ScrollRun.CLEARED and run.attempt == 1 and run.pos == 40, "perfect run %d" % i)
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
