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
	for world in ["lava_caves", "crystal_mines", "bog", "mushroom_forest", "space"]:
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
					check(run.fight_now() == run.stage(run.rolls - 1)["monster_fight"], "fight stage")
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


## Mushroom Forest ramp (2026-11-12): Mushroom N opens at Lava N's math or
## easier, each roll uses its stage's math, and four dice only come in later.
func test_mushroom_ramp_steps_up_along_the_crossing() -> bool:
	var levels := Content.levels()
	var area := Content.area("mushroom_scroll")
	for num in range(1, 7):
		var lv: Dictionary = levels[Content.level_id("mushroom_forest", num)]
		check(lv.has("ramp"), "Mushroom %d has no ramp" % num)
		var r: Array = lv["ramp"]
		check(r[r.size() - 1]["move"] == lv["move"], "Mushroom %d ends on its own math" % num)
		var lava: Dictionary = levels[Content.level_id("lava_caves", num)]
		check(int(r[0]["move"]["max_answer"]) <= int(lava["move"]["max_answer"]) + 1,
				"Mushroom %d starts above Lava %d" % [num, num])
		var first: Dictionary = r[0]["move"]
		for pt in first.get("patterns", []) + first.get("options", []).map(func(o): return o[0]):
			check(str(pt).length() <= 3, "Mushroom %d opens with four dice" % num)
		for seed_value in range(1, 60):
			var run := ScrollRun.new(area, lv, seed_value)
			var k := 0
			while run.phase != ScrollRun.CLEARED and k < 40:
				if run.phase == ScrollRun.AWAIT_FIGHT:
					check(run.fight_now() == run.stage(run.rolls - 1)["monster_fight"], "fight stage")
					run.resolve_fight(true)
					continue
				var st := run.stage(run.rolls)
				var p := run.roll()
				var mv: Dictionary = st["move"]
				var allowed: Array = mv.get("patterns", []) + mv.get("options", []).map(func(o): return o[0])
				check(allowed.has(p["signs"]), "Mushroom %d roll %d signs %s not in its stage" % [num, run.rolls, p["signs"]])
				check(p["answer"] <= int(mv["max_answer"]), "Mushroom %d answer above its stage" % num)
				check(p["dice"].size() <= 4, "more than four dice")
				if mv.get("constraint", "") == "across_ten":
					var plain := 0
					for i in p["signs"].length():
						if p["signs"][i] == "+":
							plain += int(p["dice"][i])
					check(plain >= 11, "Mushroom %d across ten: plain dice make %d" % [num, plain])
				run.choose(p["answer_index"])
				k += 1
			check(run.phase == ScrollRun.CLEARED, "Mushroom %d seed %d did not clear" % [num, seed_value])
	return true


## Space (2026-11-12): every level ramps in three stages, each roll uses its
## stage's draw, the star stones are numbered by track place, and Space 6's
## mixes (also inside its ramp) know their parts.
func test_space_ramp_and_track() -> bool:
	var levels := Content.levels()
	var area := Content.area("space_scroll")
	check(area.get("world") == "space", "space_scroll is in Space")
	for num in range(1, 7):
		var lv: Dictionary = levels[Content.level_id("space", num)]
		check(int(lv["id"]) == 50 + num, "Space %d id" % num)
		check(bool(lv.get("track", false)), "Space %d numbers stones by track place" % num)
		var r: Array = lv.get("ramp", [])
		check(r.size() == 3, "Space %d has three stages" % num)
		check(r[2]["move"] == lv["move"] and r[2]["fight"] == lv["fight"], "Space %d ends on its own math" % num)
		for st in r:
			if st["move"]["draw"] == "mix":
				check(st["move"].has("part_moves"), "Space %d mix stage has its parts" % num)
			check(not LevelGen.answers(st["move"]).is_empty(), "Space %d stage can make an answer" % num)
		for seed_value in range(1, 40):
			var run := ScrollRun.new(area, lv, seed_value)
			var k := 0
			while run.phase != ScrollRun.CLEARED and k < 40:
				if run.phase == ScrollRun.AWAIT_FIGHT:
					run.resolve_fight(true)
					continue
				var st := run.stage(run.rolls)
				var p := run.roll()
				check(p["answer"] >= 1 and p["answer"] <= int(st["move"]["max_answer"]), "Space %d answer in its stage" % num)
				if st["move"]["draw"] == "hidden":
					check(p.has("hidden"), "Space %d hidden stage hides a die" % num)
				run.choose(p["answer_index"])
				k += 1
			check(run.phase == ScrollRun.CLEARED, "Space %d seed %d clears" % [num, seed_value])
	return true


## Fights ask the step before (Terrence, 2026-11-12): along the level path
## (Lava 1 to 6, Crystal 1 to 6, Bog, Mushroom, Space) a monster fight asks
## the previous level's fight, never more than the stones around it; Lava 1
## keeps its own; the duel keeps the level's own fight.
func test_fights_ask_the_step_before() -> bool:
	var levels := Content.levels()
	var path := Content.level_path(levels)
	check(path.size() == levels.size(), "every level is on the path")
	check(path[0]["name"] == "Lava 1" and path[6]["name"] == "Crystal 1" and path[12]["name"] == "Bog 1"
			and path[18]["name"] == "Mushroom 1" and path[24]["name"] == "Space 1", "path order")
	eq(path[0]["monster_fight"], path[0]["fight"], "Lava 1 keeps its fight")
	eq(levels[12]["monster_fight"], levels[1]["fight"], "Lava 2 fights ask Lava 1 (one die)")
	eq(levels[13]["monster_fight"], levels[12]["fight"], "Lava 3 fights ask Lava 2")
	eq(levels[33]["monster_fight"], levels[32]["fight"], "Bog 3 fights ask Bog 2 (two dice, not the missing die)")
	eq(levels[41]["monster_fight"], levels[36]["fight"], "Mushroom 1 picks up where the Bog ended")
	for i in range(1, path.size()):
		var lv: Dictionary = path[i]
		var before: Dictionary = path[i - 1]["fight"]
		var stages: Array = lv.get("ramp", [])
		stages = stages + [lv]
		for st in stages:
			var mf: Dictionary = st["monster_fight"]
			check(int(mf["grade"]) == int(before["grade"]), "%s: fight rule is not the step before's" % lv["name"])
			check(int(mf["top"]) <= int(before["top"]), "%s: fight top above the step before's" % lv["name"])
			check(mf == before or mf == st["fight"], "%s: fight is neither the step before's nor its own" % lv["name"])
	# the run uses it: every monster met at Lava 3 asks Lava 2's fight
	var area := Content.area("lava_scroll")
	for seed_value in range(1, 30):
		var run := ScrollRun.new(area, levels[13], seed_value)
		while run.phase != ScrollRun.CLEARED:
			if run.phase == ScrollRun.AWAIT_FIGHT:
				eq(run.fight_now(), {"grade": 2, "top": 8}, "Lava 3 monster fight")
				run.resolve_fight(true)
				continue
			run.choose(run.roll()["answer_index"])
	return true


func _signs_of(mv: Dictionary) -> Array:
	return _allowed_signs(mv)


## Bog ramp (2026-11-12): every Bog level opens at the step before's math in
## 3 stages of 3 guesses and ends on its own; Lava 2 to 6 open with 2 of their
## 7 guesses at the Lava level before's math.
func test_bog_and_lava_warm_ups() -> bool:
	var levels := Content.levels()
	var path := Content.level_path(levels)
	var at := {}
	for i in path.size():
		at[int(path[i]["id"])] = i
	for world in ["bog", "lava_caves"]:
		var area := Content.area("bog_scroll" if world == "bog" else "lava_scroll")
		for num in range(1 if world == "bog" else 2, 7):
			var lv: Dictionary = levels[Content.level_id(world, num)]
			var r: Array = lv.get("ramp", [])
			var before: Dictionary = path[at[int(lv["id"])] - 1]
			check(r.size() == (3 if world == "bog" else 2), "%s ramp stages" % lv["name"])
			if r.is_empty():
				continue
			var total := 0
			for st in r:
				total += int(st["guesses"])
				check(not LevelGen.answers(st["move"]).is_empty(), "%s stage can make an answer" % lv["name"])
				check(int(st["move"]["max_answer"]) <= maxi(int(lv["move"]["max_answer"]), 6), "%s stage offers more stones than the level" % lv["name"])
			check(total == int(area["guesses"]), "%s ramp covers %d guesses" % [lv["name"], total])
			check(r[r.size() - 1]["move"] == lv["move"] and r[r.size() - 1]["fight"] == lv["fight"], "%s ends on its own math" % lv["name"])
			if world == "lava_caves":
				check(int(r[0]["guesses"]) == 2, "%s warms up for 2 guesses" % lv["name"])
			# the opening uses only the step before's signs (Lava 1's op-first draw is two dice)
			var old: Array = ["++", "+-"] if int(before["id"]) == 1 else _signs_of(before["move"])
			for sg in _signs_of(r[0]["move"]):
				check(old.has(sg), "%s opens with %s, not the step before's" % [lv["name"], sg])
			for seed_value in range(1, 40):
				var run := ScrollRun.new(area, lv, seed_value)
				var k := 0
				while run.phase != ScrollRun.CLEARED and k < 40:
					if run.phase == ScrollRun.AWAIT_FIGHT:
						run.resolve_fight(true)
						continue
					var st := run.stage(run.rolls)
					var p := run.roll()
					check(_signs_of(st["move"]).has(p["signs"]), "%s roll signs %s not in its stage" % [lv["name"], p["signs"]])
					check(p["answer"] <= int(st["move"]["max_answer"]), "%s answer above its stage" % lv["name"])
					run.choose(p["answer_index"])
					k += 1
				check(run.phase == ScrollRun.CLEARED, "%s seed %d clears" % [lv["name"], seed_value])
	# the Bog's second heart stone
	var hearts := 0
	for s in Content.area("bog_scroll")["steps"]:
		hearts += 1 if s["type"] == "heart" else 0
	check(hearts == 2, "the Bog has two heart stones")
	return true
