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


## Level id -> level (content/levels.json): the world's crossing math by level
## number. A "mix" level gets its parts' move configs as move.part_moves.
static func levels() -> Dictionary:
	var out := {}
	var data = JsonUtil.load_file(LEVELS_PATH)
	if data == null:
		return out
	for l in data["levels"]:
		out[int(l["id"])] = l
	for id in out:
		# the level's own move and each ramp stage's (Space 6 ramps through mixes)
		var moves := [out[id]["move"]]
		for st in out[id].get("ramp", []):
			moves.append(st["move"])
		for mv in moves:
			if mv["draw"] == "mix" and not mv.has("part_moves"):
				var parts := []
				for pid in mv["parts"]:
					parts.append(out[int(pid)]["move"])
				mv["part_moves"] = parts
	_step_back_fights(out)
	return out


## The levels in play order (the level path): the worlds as the map orders
## them, each world's levels by number. Each world picks up where the last
## one ended.
static func level_path(levels_by_id: Dictionary) -> Array:
	var order := []
	for w in worlds():
		var ls := []
		for l in levels_by_id.values():
			if l["world"] == w["id"]:
				ls.append(l)
		ls.sort_custom(func(a, b): return int(a["num"]) < int(b["num"]))
		order.append_array(ls)
	return order


## Fights ask the step before (Terrence, 2026-11-12): a monster fight in a
## level asks the previous level's fight (its own "fight", the last stage's)
## along the level path, so the new ideas stay on the stones. The first level
## (Lava 1) keeps its own. A ramp stage already opening below that (same
## rule, a lower top) keeps its own top. Each level and ramp stage gets the
## result as "monster_fight"; "fight" stays the level's own (the duel).
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


## A world's level ids by number: [level 1 id, ..., level 6 id] (0 where the
## world has no such level). Reads levels.json once, for drawing the marks.
static func level_ids(world_id: String, count := 6) -> Array:
	var out := []
	out.resize(count)
	out.fill(0)
	for l in levels().values():
		var n := int(l["num"])
		if l["world"] == world_id and n >= 1 and n <= count:
			out[n - 1] = int(l["id"])
	return out
