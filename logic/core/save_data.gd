## One JSON save per profile, written after every task (plan section 15).
## Pure data: the game layer does the file IO (game/save_store.gd).
##
## Version 2 (acorn.save, docs/contract/games/acorn-math/): a schema name,
## the game id, a random profile id, and gem_counts, each device's gems
## earned and spent, so snapshots from several tablets merge exactly
## (merge() below). Version 1 saves upgrade in from_text.
extends RefCounted

const JsonUtil := preload("res://logic/core/json_util.gd")
const BuildInfo := preload("res://logic/core/build_info.gd")

const SCHEMA := "acorn.save"
const VERSION := 2

## This install's device id (game/device_id.gd sets it at launch), for the
## gem counts. Tests leave it "local" or set their own.
static var device := "local"


static func new_profile(profile_id: String) -> Dictionary:
	return {
		"schema": SCHEMA,
		"version": VERSION,
		"game": BuildInfo.GAME,
		"profile": profile_id,
		"stickers": [],
		"gems": 0,
		# {device id: {"earned": n, "spent": n}}: only this device's entry changes here
		"gem_counts": {},
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
	}


## Nothing earned is taken away: stickers append, marks only grow.
static func add_sticker(save: Dictionary, sticker_id: String) -> void:
	save["stickers"].append(sticker_id)


static func add_gems(save: Dictionary, n: int) -> void:
	save["gems"] = int(save.get("gems", 0)) + n
	count_gems(save, n)


## Tallies a gem change on this device: n > 0 earned, n < 0 spent.
static func count_gems(save: Dictionary, n: int) -> void:
	if n == 0:
		return
	if typeof(save.get("gem_counts")) != TYPE_DICTIONARY:
		save["gem_counts"] = {}
	var counts: Dictionary = save["gem_counts"]
	if typeof(counts.get(device)) != TYPE_DICTIONARY:
		counts[device] = {"earned": 0, "spent": 0}
	var mine: Dictionary = counts[device]
	if n > 0:
		mine["earned"] = int(mine.get("earned", 0)) + n
	else:
		mine["spent"] = int(mine.get("spent", 0)) - n


## Gems from the counts: every device's earned minus every device's spent.
static func gems_from_counts(counts: Dictionary) -> int:
	var total := 0
	for d in counts:
		total += int(counts[d].get("earned", 0)) - int(counts[d].get("spent", 0))
	return total


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


static func to_text(save: Dictionary) -> String:
	return JSON.stringify(save, "\t", true)


## Returns a fresh profile if the text is missing or unreadable. Any older
## version upgrades here (the one upgrader for saves): a version 1 save's
## gem balance becomes this device's earned gems. The profile id is always
## the one given (the file it was read from).
static func from_text(text: String, profile_id: String) -> Dictionary:
	var json := JSON.new()
	if text.is_empty() or json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return new_profile(profile_id)
	var save: Dictionary = JsonUtil.normalize(json.data)
	var old_version := int(save.get("version", 1)) if typeof(save.get("version")) == TYPE_INT else 1
	var fresh := new_profile(profile_id)
	for k in fresh:
		if not save.has(k):
			save[k] = fresh[k]
	# saves from before the store load with its defaults; a hand-broken store
	# field falls back to its default too
	for k in ["currencies", "owned", "hero", "dice", "stars", "marks", "gem_counts", "stickers"]:
		if typeof(save[k]) != typeof(fresh[k]):
			save[k] = fresh[k]
	if typeof(save["gems"]) != TYPE_INT:
		save["gems"] = 0
	if old_version < 2 and save["gem_counts"].is_empty() and int(save["gems"]) > 0:
		save["gem_counts"] = {device: {"earned": int(save["gems"]), "spent": 0}}
	save["schema"] = SCHEMA
	save["version"] = maxi(VERSION, old_version)
	save["game"] = BuildInfo.GAME
	save["profile"] = profile_id
	# the Grown-ups panel no longer opens worlds (Phase 1, 2026-11-16): only
	# play moves a child on, so an old save's grown-up opens are dropped
	save.erase("parent_open")
	return save


# --- snapshots and restore (docs/contract/schemas/snapshot.v1.schema.json) ---

## This save in a family.snapshot wrapper, for upload.
static func snapshot(save: Dictionary, dev: String, rev: int, now: int, child = null) -> Dictionary:
	return {"schema": "family.snapshot", "v": 1, "game": BuildInfo.GAME, "dev": dev,
			"profile": str(save.get("profile", "")), "child": child, "rev": rev, "saved_at": now,
			"app": BuildInfo.APP, "code": BuildInfo.CODE, "cv": BuildInfo.cv(), "save_schema": SCHEMA,
			"save_v": int(save.get("version", VERSION)), "save": save.duplicate(true)}


## One child's progress from every device's snapshot (and this device's
## save, as a snapshot too). Nothing earned on any device is lost:
## marks, stars and owned items by union, stickers by the most copies,
## gems from each device's highest counts. Hero, dice and difficulty come
## from the newest snapshot. The run (a level in progress) stays with its
## device: keep_run is this device's own, put back as it was.
static func merge(snapshots: Array, profile_id: String, keep_run = null) -> Dictionary:
	var snaps := snapshots.duplicate()
	snaps.sort_custom(func(a, b): return int(a.get("saved_at", 0)) > int(b.get("saved_at", 0)))
	var out := new_profile(profile_id)
	var newest_first := []
	for s in snaps:
		newest_first.append(from_text(JSON.stringify(s.get("save", {})), profile_id))
	# unknown fields and the newest picks: oldest first, newer overwrite
	for i in range(newest_first.size() - 1, -1, -1):
		for k in newest_first[i]:
			out[k] = newest_first[i][k]
	var counts := {}
	var stickers := {}
	var owned := []
	var marks := {}
	var stars := {}
	var currencies := {}
	var intro := false
	for sv in newest_first:
		for d in sv["gem_counts"]:
			var c: Dictionary = sv["gem_counts"][d]
			var have: Dictionary = counts.get(d, {"earned": 0, "spent": 0})
			counts[d] = {"earned": maxi(have["earned"], int(c.get("earned", 0))),
					"spent": maxi(have["spent"], int(c.get("spent", 0)))}
		var tally := {}
		for st in sv["stickers"]:
			tally[st] = int(tally.get(st, 0)) + 1
		for st in tally:
			stickers[st] = maxi(int(stickers.get(st, 0)), tally[st])
		for o in sv["owned"]:
			if not owned.has(o):
				owned.append(o)
		_union_lists(marks, sv["marks"])
		_union_lists(stars, sv["stars"])
		for c in sv["currencies"]:
			currencies[c] = maxi(int(currencies.get(c, 0)), int(sv["currencies"][c]))
		intro = intro or bool(sv.get("ellwynn_intro_seen", false))
	out["gem_counts"] = counts
	out["gems"] = gems_from_counts(counts)
	var sticker_list := []
	for st in stickers:
		for n in stickers[st]:
			sticker_list.append(st)
	out["stickers"] = sticker_list
	out["owned"] = owned
	out["marks"] = marks
	out["stars"] = stars
	out["currencies"] = currencies
	if intro:
		out["ellwynn_intro_seen"] = true
	out["run"] = keep_run
	out["profile"] = profile_id
	return out


static func _union_lists(into: Dictionary, from: Dictionary) -> void:
	for k in from:
		if typeof(from[k]) != TYPE_ARRAY:
			continue
		if not into.has(k):
			into[k] = []
		for x in from[k]:
			if not into[k].has(x):
				into[k].append(x)
		into[k].sort()
