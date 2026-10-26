## One JSON save per profile, written after every task (plan section 15).
## Pure data: the game layer does the file IO (game/save_store.gd).
extends RefCounted

const JsonUtil := preload("res://logic/core/json_util.gd")

const VERSION := 1


static func new_profile(profile_id: String) -> Dictionary:
	return {
		"version": VERSION,
		"profile": profile_id,
		"stickers": [],
		"gems": 0,
		"marks": {},
		"run": null,
	}


## Nothing earned is taken away: stickers append, marks only grow.
static func add_sticker(save: Dictionary, sticker_id: String) -> void:
	save["stickers"].append(sticker_id)


static func add_gems(save: Dictionary, n: int) -> void:
	save["gems"] = int(save.get("gems", 0)) + n


static func add_mark(save: Dictionary, area_id: String, grade_id: int) -> void:
	var marks: Dictionary = save["marks"]
	if not marks.has(area_id):
		marks[area_id] = []
	if not marks[area_id].has(grade_id):
		marks[area_id].append(grade_id)
		marks[area_id].sort()


static func has_mark(save: Dictionary, area_id: String, grade_id: int) -> bool:
	return save["marks"].has(area_id) and save["marks"][area_id].has(grade_id)


static func to_text(save: Dictionary) -> String:
	return JSON.stringify(save, "\t", true)


## Returns a fresh profile if the text is missing or unreadable.
static func from_text(text: String, profile_id: String) -> Dictionary:
	var json := JSON.new()
	if text.is_empty() or json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return new_profile(profile_id)
	var save: Dictionary = JsonUtil.normalize(json.data)
	var fresh := new_profile(profile_id)
	for k in fresh:
		if not save.has(k):
			save[k] = fresh[k]
	return save
