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
