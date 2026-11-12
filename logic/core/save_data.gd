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
		# the store (content/store.json, logic/core/store.gd). "gems" above stays
		# the gem balance; other currencies live in "currencies" by id.
		"currencies": {},
		"owned": [],
		"hero": "robodragon",
		"dice": "classic",
		# a level's crossing cleared without losing a heart: {world_id: [level ids]}
		"stars": {},
		# worlds a grown-up opened from the menu's Grown-ups panel (world ids)
		"parent_open": [],
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


## The brighter mark: a crossing cleared without losing a heart.
static func add_star(save: Dictionary, world_id: String, grade_id: int) -> void:
	var stars: Dictionary = save["stars"]
	if not stars.has(world_id):
		stars[world_id] = []
	if not stars[world_id].has(grade_id):
		stars[world_id].append(grade_id)
		stars[world_id].sort()


static func has_star(save: Dictionary, world_id: String, grade_id: int) -> bool:
	return save["stars"].has(world_id) and save["stars"][world_id].has(grade_id)


## The Grown-ups panel opens (or closes again) a world on the map.
static func set_parent_open(save: Dictionary, world_id: String, open: bool) -> void:
	var list: Array = save["parent_open"]
	if open and not list.has(world_id):
		list.append(world_id)
	elif not open:
		list.erase(world_id)


static func is_parent_open(save: Dictionary, world_id: String) -> bool:
	return save["parent_open"].has(world_id)


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
	# saves from before the store load with its defaults; a hand-broken store
	# field falls back to its default too
	for k in ["currencies", "owned", "hero", "dice", "stars", "parent_open", "marks"]:
		if typeof(save[k]) != typeof(fresh[k]):
			save[k] = fresh[k]
	return save
