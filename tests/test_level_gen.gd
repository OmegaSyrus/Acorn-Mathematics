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


const WORLDS := ["lava_caves", "crystal_mines", "bog", "mushroom_forest", "space"]
const KINDS := ["start", "die", "top", "take_away", "hidden", "place", "ten", "rails", "track", "mix"]


## The level path (Phase 1 of the ship plan, 2026-11-16): 30 steps, Level 1
## in every world from Lava to Space, then Level 2 from Lava again. Level
## ids never change: Lava 1 is 1, the rest world x 10 + Level.
func test_the_path_is_30_steps_level_by_level() -> bool:
	var levels := Content.levels()
	var path := Content.level_path(levels)
	eq(path.size(), 30, "30 steps")
	for k in path.size():
		var lv: Dictionary = path[k]
		var n := k / 5 + 1
		var w: String = WORLDS[k % 5]
		eq(int(lv["step"]), k + 1, "%s is step %d" % [lv["name"], k + 1])
		eq(int(lv["num"]), n, "step %d is Level %d" % [k + 1, n])
		eq(String(lv["world"]), w, "step %d is in %s" % [k + 1, w])
		eq(int(lv["id"]), 1 if k == 0 else (k % 5 + 1) * 10 + n, "step %d keeps its id" % (k + 1))
		check(KINDS.has(String(lv.get("new", ""))), "%s names its new thing" % lv["name"])
	return true


func _is_patterns(mv: Dictionary) -> bool:
	return mv["draw"] == "patterns"


## One thing per step: a "top" step only raises the top number; a "rails"
## or "track" step keeps the step before's math and only turns that on; any
## other step changes the dice or signs but never raises the top number with
## them. The rails stay on in the Crystal Mines from Level 3, the track in
## Space from Level 2.
func test_each_step_adds_one_thing() -> bool:
	var path := Content.level_path(Content.levels())
	for k in range(1, path.size()):
		var lv: Dictionary = path[k]
		var prev: Dictionary = path[k - 1]
		var mv: Dictionary = lv["move"]
		var pm: Dictionary = prev["move"]
		var new := String(lv["new"])
		var name := String(lv["name"])
		match new:
			"top":
				check(_is_patterns(mv) and _is_patterns(pm), "%s: top steps are pattern draws" % name)
				eq(mv["patterns"], pm["patterns"], "%s: same signs as %s" % [name, prev["name"]])
				check(int(mv["max_answer"]) > int(pm["max_answer"]), "%s raises the top" % name)
			"rails", "track":
				var a: Dictionary = mv.duplicate()
				var b: Dictionary = pm.duplicate()
				eq(a, b, "%s: the same math as %s" % [name, prev["name"]])
				check(bool(lv.get(new, false)) and not bool(prev.get(new, false)), "%s turns on the %s" % [name, new])
			"mix":
				eq(mv["draw"], "mix", "%s mixes" % name)
			_:
				check(_allowed_signs(mv) != _allowed_signs(pm) or mv.get("options") != pm.get("options")
						or mv.get("constraint") != pm.get("constraint"), "%s changes the dice" % name)
				if _is_patterns(mv) and _is_patterns(pm):
					check(int(mv["max_answer"]) <= int(pm["max_answer"]), "%s adds %s and a bigger top" % [name, new])
		var w := String(lv["world"])
		var n := int(lv["num"])
		eq(bool(lv.get("rails", false)), w == "crystal_mines" and n >= 3, "%s rails" % name)
		eq(bool(lv.get("track", false)), w == "space" and n >= 2, "%s track" % name)
	return true


## Every level opens with 3 warm-up guesses at the step before's math and
## fight, then plays its own to the end of the crossing; Lava 1 warms up
## with one die to 3. Each roll uses its stage's math. A step that brings in
## the rails or the track leaves it out of its warm-up.
func test_every_level_warms_up_at_the_step_before() -> bool:
	var levels := Content.levels()
	var path := Content.level_path(levels)
	var areas := {}
	for aid in Content.area_ids():
		var a := Content.area(aid)
		if a.get("type") == "scroll" and a.has("world") and a.has("guesses"):
			areas[a["world"]] = a
	for k in path.size():
		var lv: Dictionary = path[k]
		var name := String(lv["name"])
		var r: Array = lv.get("ramp", [])
		eq(r.size(), 2, "%s: a warm-up and its own math" % name)
		if r.size() != 2:
			continue
		eq(int(r[0]["guesses"]), 3, "%s warms up for 3 guesses" % name)
		check(bool(r[0].get("warmup", false)), "%s marks its warm-up" % name)
		var before: Dictionary = lv["warmup"] if k == 0 else path[k - 1]
		eq(_allowed_signs(r[0]["move"]), _allowed_signs(before["move"]), "%s warms up with the step before's dice" % name)
		eq(int(r[0]["move"]["max_answer"]), int(before["move"]["max_answer"]), "%s warm-up top" % name)
		eq(r[0]["fight"], before["fight"], "%s warm-up fight" % name)
		check(r[1]["move"] == lv["move"] and r[1]["fight"] == lv["fight"], "%s then its own math" % name)
		var new := String(lv.get("new", ""))
		eq(bool(r[0]["rails"]), bool(lv.get("rails", false)) and new != "rails", "%s warm-up rails" % name)
		eq(bool(r[0]["track"]), bool(lv.get("track", false)) and new != "track", "%s warm-up track" % name)
		var area: Dictionary = areas[lv["world"]]
		for seed_value in range(1, 25):
			var run := ScrollRun.new(area, lv, seed_value)
			var guard := 0
			while run.phase != ScrollRun.CLEARED and guard < 40:
				guard += 1
				if run.phase == ScrollRun.AWAIT_FIGHT:
					run.resolve_fight(true)
					continue
				var st := run.stage(run.rolls)
				check((run.rolls < 3) == bool(st.get("warmup", false)), "%s roll %d stage" % [name, run.rolls])
				var p := run.roll()
				check(_allowed_signs(st["move"]).has(p["signs"]), "%s roll signs %s not in its stage" % [name, p["signs"]])
				check(p["answer"] <= int(st["move"]["max_answer"]), "%s answer above its stage" % name)
				run.choose(p["answer_index"])
			check(run.phase == ScrollRun.CLEARED, "%s seed %d clears" % [name, seed_value])
	return true


## Fights ask the step before (Terrence, 2026-11-12), now along the new path:
## a monster fight asks the previous step's fight, never more than the
## stones around it; Lava 1 keeps its own; the duel keeps the level's own.
func test_fights_ask_the_step_before() -> bool:
	var levels := Content.levels()
	var path := Content.level_path(levels)
	eq(levels[1]["monster_fight"], levels[1]["fight"], "Lava 1 keeps its own fight")
	for k in range(1, path.size()):
		var lv: Dictionary = path[k]
		var want := Content.step_back_fight(path[k - 1]["fight"], lv["fight"])
		eq(lv["monster_fight"], want, "%s monster fight" % lv["name"])
		for st in lv["ramp"]:
			check(int(st["monster_fight"]["top"]) <= int(path[k - 1]["fight"]["top"]), "%s stage fight top" % lv["name"])
	eq(levels[Content.level_id("crystal_mines", 1)]["monster_fight"], {"grade": 1, "top": 6},
			"Crystal 1 fights ask Lava 1 (one die)")
	eq(levels[Content.level_id("lava_caves", 2)]["monster_fight"], {"grade": 2, "top": 12},
			"Lava 2 fights ask Space 1")
	return true


## Room for 3 misses in every crossing (Phase 1): three hearts and one heart
## stone, the Bog's second stone gone. Every crossing asks about the same
## number: Lava 7 guesses, the others 8, three monsters each.
func test_every_crossing_has_one_heart_stone_and_three_monsters() -> bool:
	for aid in ["lava_scroll", "crystal_scroll", "bog_scroll", "mushroom_scroll", "space_scroll"]:
		var area := Content.area(aid)
		var hearts := 0
		var monsters := 0
		for s in area["steps"]:
			hearts += 1 if s["type"] == "heart" else 0
			monsters += 1 if s["type"] == "monster" else 0
			check(int(s["after"]) < int(area["guesses"]), "%s step %d lands before the shore" % [aid, s["after"]])
		eq(hearts, 1, "%s has one heart stone" % aid)
		eq(monsters, 3, "%s has three monsters" % aid)
		eq(int(area["guesses"]), 7 if aid == "lava_scroll" else 8, "%s guesses" % aid)
	eq(ScrollRun.HERO_HEARTS, 3, "three hearts")
	return true
