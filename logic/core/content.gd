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
	return out


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
