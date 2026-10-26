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
