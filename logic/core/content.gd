## Loads the engine-neutral content files (content/*.json).
extends RefCounted

const JsonUtil := preload("res://logic/core/json_util.gd")

const GRADES_PATH := "res://content/grades.json"
const STICKERS_PATH := "res://content/stickers.json"
const AREA_DIR := "res://content/areas/"
const IMPLEMENTED_RULES := ["single", "sum"]


## Grade id -> grade dictionary.
static func grades() -> Dictionary:
	var out := {}
	var data = JsonUtil.load_file(GRADES_PATH)
	if data == null:
		return out
	for g in data["grades"]:
		out[g["id"]] = g
	return out


static func stickers() -> Array:
	var data = JsonUtil.load_file(STICKERS_PATH)
	return [] if data == null else data["stickers"]


static func area(area_id: String) -> Dictionary:
	var data = JsonUtil.load_file(AREA_DIR + area_id + ".json")
	return {} if data == null else data


static func area_ids() -> Array:
	var ids := []
	for f in DirAccess.get_files_at(AREA_DIR):
		if f.ends_with(".json"):
			ids.append(f.get_basename())
	ids.sort()
	return ids


const WORLDS_PATH := "res://content/worlds.json"


## The worlds in play order, for the mini map. A world with an "area" can be
## played; one without is shown locked until it is built.
static func worlds() -> Array:
	var data = JsonUtil.load_file(WORLDS_PATH)
	return [] if data == null else data["worlds"]


const LEVELS_PATH := "res://content/levels.json"


## Level id -> level (content/levels.json): the crossing math of each step
## on the level path. A "mix" move gets its parts' move configs as
## move.part_moves. Every level gets a 2-stage "ramp": 3 warm-up guesses at
## the step before's math, then its own (Phase 1 of the ship plan,
## 2026-11-16), and a "monster_fight" (the step before's fight).
static func levels() -> Dictionary:
	var out := {}
	var data = JsonUtil.load_file(LEVELS_PATH)
	if data == null:
		return out
	for l in data["levels"]:
		out[int(l["id"])] = l
	for id in out:
		var mv: Dictionary = out[id]["move"]
		if mv["draw"] == "mix" and not mv.has("part_moves"):
			var parts := []
			for pid in mv["parts"]:
				parts.append(out[int(pid)]["move"])
			mv["part_moves"] = parts
	_warm_ups(out)
	_step_back_fights(out)
	return out


## How many guesses open each crossing at the step before's math.
const WARM_UP_GUESSES := 3


## The level path: Level 1 in every world in map order (Lava, Crystal, Bog,
## Mushroom, Space), then Level 2 from Lava again, and so on. Each step is
## one place on the 30-step ladder.
static func level_path(levels_by_id: Dictionary) -> Array:
	var order := {}
	var ws := worlds()
	for i in ws.size():
		order[String(ws[i]["id"])] = i
	var out := []
	for l in levels_by_id.values():
		if order.has(String(l["world"])):
			out.append(l)
	out.sort_custom(func(a, b):
		if int(a["num"]) != int(b["num"]):
			return int(a["num"]) < int(b["num"])
		return order[String(a["world"])] < order[String(b["world"])])
	return out


## Every level opens with WARM_UP_GUESSES guesses at the step before's move
## and fight, then plays its own: "ramp" [warm-up, own]. The first step has
## no step before and uses its "warmup" entry. The rails and the star track
## are the world's: kept in the warm-up, except on the step that brings them
## in ("new"), so that step's one new thing stays out of its warm-up.
static func _warm_ups(levels_by_id: Dictionary) -> void:
	var path := level_path(levels_by_id)
	for i in path.size():
		var lv: Dictionary = path[i]
		var before: Dictionary = lv.get("warmup", {}) if i == 0 else path[i - 1]
		if before.is_empty():
			continue
		var rails := bool(lv.get("rails", false))
		var track := bool(lv.get("track", false))
		var new := String(lv.get("new", ""))
		var warm := {"guesses": WARM_UP_GUESSES, "warmup": true,
				"move": before["move"].duplicate(true), "fight": before["fight"].duplicate(),
				"rails": rails and new != "rails", "track": track and new != "track"}
		var own := {"guesses": 99, "move": lv["move"], "fight": lv["fight"], "rails": rails, "track": track}
		lv["ramp"] = [warm, own]


## Fights ask the step before (Terrence, 2026-11-12): a monster fight in a
## level asks the previous step's fight along the level path, so the new
## ideas stay on the stones. The first step keeps its own. A ramp stage
## already opening below that (same rule, a lower top) keeps its own top.
## Each level and ramp stage gets the result as "monster_fight"; "fight"
## stays the level's own (the duel).
static func _step_back_fights(levels_by_id: Dictionary) -> void:
	var path := level_path(levels_by_id)
	for i in path.size():
		var lv: Dictionary = path[i]
		var before: Dictionary = lv["fight"] if i == 0 else path[i - 1]["fight"]
		lv["monster_fight"] = step_back_fight(before, lv["fight"])
		for st in lv.get("ramp", []):
			st["monster_fight"] = step_back_fight(before, st["fight"])


## The fight a monster asks: the step before's, or `own` when it is the
## same rule with a lower top (never more than the stones around it ask).
static func step_back_fight(before: Dictionary, own: Dictionary) -> Dictionary:
	if int(own["grade"]) == int(before["grade"]) and int(own["top"]) < int(before["top"]):
		return own.duplicate()
	return before.duplicate()


static func bands() -> Dictionary:
	var data = JsonUtil.load_file(LEVELS_PATH)
	return {} if data == null else data["bands"]


## The level id for a world's level number: Lava 1 keeps id 1 (the old Acorn
## grade, so saves carry over); the rest are world x 10 + number.
static func level_id(world_id: String, num: int) -> int:
	for l in levels().values():
		if l["world"] == world_id and int(l["num"]) == num:
			return int(l["id"])
	return 1


## How many Levels the path has (each one pass of the five worlds).
const LEVEL_COUNT := 6

static var _ids_cache := {}


## A world's level ids by number: [level 1 id, ..., level 6 id] (0 where the
## world has no such level). Reads levels.json once and keeps the answer
## (the ids never change), for the marks and the Level path checks.
static func level_ids(world_id: String, count := LEVEL_COUNT) -> Array:
	if _ids_cache.is_empty():
		for l in levels().values():
			var w := String(l["world"])
			if not _ids_cache.has(w):
				var blank := []
				blank.resize(LEVEL_COUNT)
				blank.fill(0)
				_ids_cache[w] = blank
			var n := int(l["num"])
			if n >= 1 and n <= LEVEL_COUNT:
				_ids_cache[w][n - 1] = int(l["id"])
	var out := []
	out.resize(count)
	out.fill(0)
	var have: Array = _ids_cache.get(world_id, [])
	for k in mini(count, have.size()):
		out[k] = have[k]
	return out
