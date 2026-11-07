## Content checks (plan section 16): every JSON file parses and areas are
## well formed.
extends "res://tests/support/test_case.gd"

const Content := preload("res://logic/core/content.gd")

const TASK_TYPES := ["path", "door", "chest", "fight"]


func test_every_content_json_parses() -> bool:
	for path in _json_files("res://content"):
		check(JsonUtil.load_file(path) != null, "bad JSON " + path)
	return true


func test_grades() -> bool:
	var grades := Content.grades()
	for gid in [1, 2, 3, 4]:
		check(grades.has(gid), "missing grade %d" % gid)
	for gid in grades:
		var g: Dictionary = grades[gid]
		for key in ["key", "name", "available", "rule", "dice", "choices", "min_choice", "max_choice"]:
			check(g.has(key), "grade %d missing %s" % [gid, key])
		if g["available"]:
			check(Content.IMPLEMENTED_RULES.has(g["rule"]), "grade %d available but rule not implemented" % gid)
	return true


func test_areas_have_6_to_10_tasks() -> bool:
	var ids := Content.area_ids()
	check(ids.has("lava_1"), "lava_1 missing")
	for id in ids:
		var a := Content.area(id)
		check(a.get("id") == id, "area id must match file name: " + id)
		if a.get("type") == "scroll":
			_check_scroll(a)
			continue
		var n: int = a["tasks"].size()
		check(n >= 6 and n <= 10, "area %s has %d tasks" % [id, n])
		for t in a["tasks"]:
			check(TASK_TYPES.has(t["type"]), "area %s unknown task %s" % [id, str(t["type"])])
			if t["type"] == "fight":
				check(str(t.get("monster", "")) != "", "area %s fight task without a monster id" % id)
			if t.has("mimic"):
				check(t["type"] == "chest" and t["mimic"] is bool, "area %s: mimic is a true/false flag on chests" % id)
	return true


## Scroll areas: a row of spaces, chests and monsters on some of them, only
## grades that have a "move" config.
func _check_scroll(a: Dictionary) -> void:
	var id: String = a["id"]
	for gid in a["grades"]:
		check(Content.grades()[int(gid)].has("move"), "scroll %s grade %d has no move config" % [id, gid])
	var entries: Array
	var key: String
	var top: int
	if a.has("guesses"):
		# a run of guesses: the steps land on the stones the answers reach
		top = int(a["guesses"])
		check(top >= 3, "scroll %s too few guesses" % id)
		entries = a["steps"]
		key = "after"
	else:
		top = int(a["length"])
		check(top >= 10, "scroll %s too short" % id)
		entries = a["spaces"]
		key = "at"
	var seen := {}
	for s in entries:
		var at: int = s[key]
		check(at > 0 and at < top and not seen.has(at), "scroll %s bad %s %d" % [id, key, at])
		seen[at] = true
		check(["chest", "monster"].has(s["type"]), "scroll %s unknown space type" % id)
		if s["type"] == "monster":
			check(str(s.get("monster", "")) != "", "scroll %s monster space without an id" % id)


func test_stickers() -> bool:
	check(Content.stickers().size() > 0, "no stickers")
	return true


func _json_files(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_json_files(dir.path_join(d)))
	return out


## The mini map's worlds: the five in order, every playable one points at a
## real area, and that area's miniboss is a duel fighter.
func test_worlds() -> bool:
	const Monsters := preload("res://logic/fight/monsters.gd")
	var worlds := Content.worlds()
	var ids := []
	for w in worlds:
		ids.append(w["id"])
	check(ids == ["lava_caves", "crystal_mines", "bog", "mushroom_forest", "space"], "worlds in order: %s" % [ids])
	for w in worlds:
		if w.has("area"):
			var a := Content.area(w["area"])
			check(not a.is_empty(), "world %s area %s missing" % [w["id"], w["area"]])
			check(a.get("world") == w["id"], "area %s is not in world %s" % [w["area"], w["id"]])
			if a.has("miniboss"):
				check(Monsters.ROSTER.has(a["miniboss"]) and Monsters.ROSTER[a["miniboss"]]["role"] == "miniboss",
						"area %s miniboss %s" % [w["area"], a["miniboss"]])
	return true
