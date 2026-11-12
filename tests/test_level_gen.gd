## Generator v1.2 for the levels after Lava 1 (docs/difficulty-plan.md 4.2,
## 4.4): every roll reads left to right to its answer, never below 1 on the
## way, with dice 1 to 6 and signs from the level's own patterns.
extends "res://tests/support/test_case.gd"

const Content := preload("res://logic/core/content.gd")
const LevelGen := preload("res://logic/core/level_gen.gd")
const Rng := preload("res://logic/core/rng.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")


func _allowed_signs(move: Dictionary) -> Array:
	match move["draw"]:
		"patterns":
			return move["patterns"]
		"hidden":
			var out := []
			for o in move["options"]:
				out.append(o[0])
			return out
		"mix":
			var out := []
			for part in move["part_moves"]:
				out.append_array(_allowed_signs(part))
			return out
	return []


func test_every_level_roll_reads_to_its_answer() -> bool:
	var levels := Content.levels()
	check(levels.size() >= 18, "levels missing")
	for id in levels:
		var lv: Dictionary = levels[id]
		var mv: Dictionary = lv["move"]
		if mv["draw"] == "op_first":
			continue
		var seen := {}
		var allowed := _allowed_signs(mv)
		for seed_value in range(1, 1500):
			var rng := Rng.new(seed_value)
			var a := LevelGen.draw_answer(mv, rng)
			seen[a] = true
			check(a >= int(mv.get("min_answer", 1)) and a <= int(mv["max_answer"]), "level %d answer %d out of range" % [id, a])
			var p := LevelGen.generate_for(lv, rng, a, int(mv["max_answer"]))
			var signs: String = p["signs"]
			check(allowed.has(signs), "level %d signs %s" % [id, signs])
			check(p["dice"].size() == signs.length(), "level %d dice count" % id)
			var total := 0
			for i in signs.length():
				var d: int = p["dice"][i]
				check(d >= 1 and d <= 6, "level %d die %d" % [id, d])
				total += d if signs[i] == "+" else -d
				check(total >= 1, "level %d goes below 1: %s %s" % [id, signs, str(p["dice"])])
			if p.has("hidden"):
				check(p["dice"][p["hidden"]] == a, "level %d hidden face is not the answer" % id)
				check(total == p["total"], "level %d total" % id)
			else:
				check(total == a, "level %d dice %s make %d not %d" % [id, str(p["dice"]), total, a])
			if mv.get("constraint", "") == "ten_pair" and signs.count("+") >= 2 and p["dice"][0] + p["dice"][1] == 10:
				pass
			check(p["choices"].size() == int(mv["max_answer"]), "level %d choices" % id)
		# every answer the level can make turns up
		for want in LevelGen.answers(mv):
			check(seen.has(want), "level %d never drew %d" % [id, want])
	return true


func test_a_perfect_run_clears_every_level() -> bool:
	var levels := Content.levels()
	for world in ["lava_caves", "crystal_mines", "bog"]:
		var area := {}
		for aid in Content.area_ids():
			var a := Content.area(aid)
			if a.get("world", "") == world and a.get("type") == "scroll":
				area = a
		check(not area.is_empty(), "no area for " + world)
		for id in levels:
			if levels[id]["world"] != world:
				continue
			var run := ScrollRun.new(area, levels[id], 77 + id)
			var guard := 0
			while run.phase != ScrollRun.CLEARED and guard < 200:
				guard += 1
				if run.phase == ScrollRun.AWAIT_FIGHT:
					run.resolve_fight(true)
					continue
				var p := run.roll()
				run.choose(p["answer_index"])
			check(run.phase == ScrollRun.CLEARED, "level %d did not clear" % id)
			check(run.attempt == 1, "level %d restarted" % id)
	return true


## Crystal Mines ramp (Terrence 2026-11-12: Crystal 1 was too big a jump from
## Lava 1): each roll uses its stage's math, the first stage of Crystal N
## starts at or near Lava N, and the stages never get easier.
func test_crystal_ramp_steps_up_along_the_crossing() -> bool:
	var levels := Content.levels()
	var area := Content.area("crystal_scroll")
	for num in range(1, 7):
		var lv: Dictionary = levels[Content.level_id("crystal_mines", num)]
		check(lv.has("ramp"), "Crystal %d has no ramp" % num)
		var r: Array = lv["ramp"]
		var lava: Dictionary = levels[Content.level_id("lava_caves", num)]
		check(int(r[0]["move"]["max_answer"]) <= int(lava["move"]["max_answer"]) + 1,
				"Crystal %d starts above Lava %d" % [num, num])
		for i in range(1, r.size()):
			check(int(r[i]["move"]["max_answer"]) >= int(r[i - 1]["move"]["max_answer"]),
					"Crystal %d stage %d gets easier" % [num, i])
		for seed_value in range(1, 60):
			var run := ScrollRun.new(area, lv, seed_value)
			var k := 0
			while run.phase != ScrollRun.CLEARED and k < 40:
				if run.phase == ScrollRun.AWAIT_FIGHT:
					check(run.fight_now() == run.stage(run.rolls - 1)["fight"], "fight stage")
					run.resolve_fight(true)
					continue
				var st := run.stage(run.rolls)
				var p := run.roll()
				check(run.stage_now() == st, "stage_now while choosing")
				var allowed: Array = st["move"]["patterns"]
				check(allowed.has(p["signs"]), "Crystal %d roll %d signs %s not in its stage" % [num, run.rolls, p["signs"]])
				check(p["answer"] <= int(st["move"]["max_answer"]), "Crystal %d answer above its stage" % num)
				run.choose(p["answer_index"])
				k += 1
	# Crystal 1 opens with every stone numbered, then the rail stops come in
	var c1: Array = levels[Content.level_id("crystal_mines", 1)]["ramp"]
	check(not c1[0]["rails"] and c1[1]["rails"], "Crystal 1 rails come in on stage 2")
	check(int(c1[0]["move"]["max_answer"]) <= 6 and c1[0]["move"]["patterns"].size() == 2, "Crystal 1 opens with two dice")
	return true
