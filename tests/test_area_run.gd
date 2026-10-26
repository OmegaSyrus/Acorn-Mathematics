extends "res://tests/support/test_case.gd"

const Rng := preload("res://logic/core/rng.gd")
const AreaRun := preload("res://logic/path/area_run.gd")
const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const Bots := preload("res://tests/support/bots.gd")


func _run(grade_id: int, seed_value: int) -> AreaRun:
	return AreaRun.new(Content.area("lava_1"), Content.grades()[grade_id], Content.stickers(), seed_value)


## Same seed + same inputs = same run, and it matches the Python reference.
func test_replay_vectors() -> bool:
	for c in vectors("replays.json"):
		var run := AreaRun.new(Content.area(c["area"]), Content.grades()[c["grade"]], Content.stickers(), c["seed"])
		for inp in c["inputs"]:
			Bots.apply_input(run, inp)
		eq(run.events, c["log"], "replay log grade %d seed %d" % [c["grade"], c["seed"]])
		eq(run.to_save(), c["final"], "replay final grade %d seed %d" % [c["grade"], c["seed"]])
		check(run.phase == c["phase"], "replay phase grade %d seed %d" % [c["grade"], c["seed"]])
	return true


## Gate 1: the perfect player always clears, the random one under 1 in 100.
func test_bots_thousand_runs() -> bool:
	for gid in [1, 2]:
		var perfect := 0
		var random := 0
		for i in 1000:
			if Bots.play(_run(gid, 1000 + i), "perfect", null)["cleared"]:
				perfect += 1
			if Bots.play(_run(gid, 5000 + i), "random", Rng.new(9000 + i))["cleared"]:
				random += 1
		check(perfect == 1000, "perfect bot grade %d cleared %d/1000" % [gid, perfect])
		check(random < 10, "random bot grade %d cleared %d/1000" % [gid, random])
		print("      bots grade %d: perfect %d/1000, random %d/1000" % [gid, perfect, random])
	return true


func test_fall_restarts_area() -> bool:
	var run := _run(1, 3)
	Bots.apply_input(run, "roll")
	var wrong: int = (run.problem["answer_index"] + 1) % 4
	var out := run.choose(wrong)
	check(out["result"] == "fall" and out["restarted"], "a wrong rock should fall and restart")
	check(run.task_index == 0 and run.attempt == 2 and run.phase == AreaRun.AWAIT_ROLL, "restart state")
	return true


func test_wrong_chest_only_stays_shut() -> bool:
	var run := _run(1, 5)
	while run.current_task()["type"] != "chest":
		Bots.apply_input(run, "roll")
		run.choose(run.problem["answer_index"])
	var at := run.task_index
	run.decide_chest(true)
	run.roll()
	var out := run.choose((run.problem["answer_index"] + 1) % 4)
	check(out["result"] == "chest_shut" and not out["restarted"], "wrong chest should only stay shut")
	check(run.task_index == at + 1 and run.attempt == 1, "wrong chest should move on")
	return true


## Closing the game at any task boundary resumes to the identical run.
func test_resume_at_every_task() -> bool:
	var whole := _run(2, 77)
	Bots.play(whole, "perfect", null)
	for stop in whole.task_count():
		var r := _run(2, 77)
		while r.task_index < stop:
			_perfect_step(r)
		var text := SaveData.to_text({"run": r.to_save()})
		var loaded := SaveData.from_text(text, "1")
		var r2 := _run(2, loaded["run"]["seed"])
		r2.restore(loaded["run"])
		r2.events = r.events.duplicate(true)
		Bots.play(r2, "perfect", null)
		eq(r2.events, whole.events, "resume at task %d" % stop)
	return true


func _perfect_step(r: AreaRun) -> void:
	if r.phase == AreaRun.AWAIT_CHEST:
		r.decide_chest(true)
	elif r.phase == AreaRun.AWAIT_ROLL:
		r.roll()
	elif r.phase == AreaRun.AWAIT_CHOICE:
		r.choose(r.problem["answer_index"])


func test_save_keeps_what_was_earned() -> bool:
	var s := SaveData.new_profile("1")
	SaveData.add_sticker(s, "ember")
	SaveData.add_mark(s, "lava_1", 2)
	SaveData.add_mark(s, "lava_1", 1)
	SaveData.add_mark(s, "lava_1", 2)
	var back := SaveData.from_text(SaveData.to_text(s), "1")
	eq(back["stickers"], ["ember"], "stickers survive a save")
	eq(back["marks"], {"lava_1": [1, 2]}, "marks survive a save")
	check(SaveData.has_mark(back, "lava_1", 1), "has_mark")
	eq(SaveData.from_text("not json", "1"), SaveData.new_profile("1"), "bad save gives a fresh profile")
	return true


## Fight and mimic hooks for the fight layer (logic/fight).
func test_mimic_and_fight_hooks() -> bool:
	var area := {"id": "hooks", "tasks": [{"type": "chest", "mimic": true}, {"type": "fight", "monster": "blorp"},
			{"type": "path"}, {"type": "path"}, {"type": "path"}, {"type": "path"}]}
	var run := AreaRun.new(area, Content.grades()[1], Content.stickers(), 11)
	run.decide_chest(true)
	run.roll()
	var out := run.choose(run.problem["answer_index"])
	check(out["result"] == "mimic" and out["first_strike"], "a right answer on a mimic gives the first strike")
	check(run.phase == AreaRun.AWAIT_FIGHT and run.task_index == 0, "mimic fight happens on the chest task")
	check(run.current_monster() == "mimic", "current_monster is mimic")
	out = run.resolve_fight(true)
	check(out["result"] == "fight_won" and run.task_index == 1, "a won mimic fight moves on")
	check(run.phase == AreaRun.AWAIT_FIGHT and run.current_monster() == "blorp", "fight task names its monster")
	out = run.resolve_fight(false)
	check(out["restarted"] and run.task_index == 0 and run.attempt == 2, "a lost fight restarts the area")
	run.decide_chest(true)
	run.roll()
	out = run.choose((run.problem["answer_index"] + 1) % 4)
	check(out["result"] == "mimic" and not out["first_strike"], "a wrong answer on a mimic still starts the fight")
	var walker := AreaRun.new(area, Content.grades()[1], Content.stickers(), 12)
	check(walker.decide_chest(false)["result"] == "walk_past" and walker.task_index == 1, "a mimic can be walked past")
	return true
