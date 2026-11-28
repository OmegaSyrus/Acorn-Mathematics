## What follows a crossing (Terrence, 2026-11-07): through the door to the
## area's miniboss duel, then its boss fight, then the mini map to pick the
## next area. An area file names its "miniboss" and "boss"; either can be
## left out and that step is skipped.
##
## The step in progress is the saved run while it lasts:
##   {"area": "lava_scroll", "grade": 1, "stage": "duel"}
## so closing the app after the door opens the duel again (and after the
## duel, the boss). Pure data, no nodes.
extends RefCounted

const SaveData := preload("res://logic/core/save_data.gd")
const Content := preload("res://logic/core/content.gd")

const DUEL := "duel"
const BOSS := "boss"
const MAP := "map"   # all done: the mini map
const STAGES := [DUEL, BOSS, MAP]


## The step after `stage` ("" is the crossing itself).
static func next_stage(area: Dictionary, stage: String) -> String:
	var order := ["", DUEL, BOSS, MAP]
	var i := order.find(stage)
	for k in range(i + 1, order.size()):
		var s: String = order[k]
		if s == DUEL and not area.has("miniboss"):
			continue
		if s == BOSS and not area.has("boss"):
			continue
		return s
	return MAP


## The saved run for a step between the door and the mini map.
static func stage_run(area: Dictionary, grade_id: int, stage: String) -> Dictionary:
	return {"area": area["id"], "grade": grade_id, "stage": stage}


## A saved run that is one of these steps (not a crossing in progress).
static func is_stage_run(run) -> bool:
	return run is Dictionary and STAGES.has(run.get("stage", ""))


## Moves the save on to `stage`: the saved run for a duel or boss, or none
## once the mini map is reached, with the world marked beaten at the grade.
static func enter(save: Dictionary, area: Dictionary, grade_id: int, stage: String) -> void:
	if stage == MAP:
		save["run"] = null
		SaveData.add_mark(save, area.get("world", area["id"]), grade_id)
	else:
		save["run"] = stage_run(area, grade_id, stage)


## The Level path (Phase 1 of the ship plan, 2026-11-16): Level N is one
## pass of the five worlds, each at Level N. At a Level, the first world is
## open once the Level is, and each world after it once the world before it
## has been beaten at that Level. Level 1 is always open; Level N+1 opens
## when every world has been beaten at Level N (beating Space finishes the
## pass). A grown-up can also pick the Level on the Grown-ups panel
## (pick_level). The Debug screen's "Map: all open" (save["debug_unlock"])
## opens every world at every Level, for testing.
## A world that isn't built yet (no "area") can't be beaten, so the world
## after it looks back past it to the last built one.
static func world_unlocked(save: Dictionary, worlds: Array, i: int, level := 1) -> bool:
	if i < 0 or i >= worlds.size():
		return false
	if bool(save.get("debug_unlock", false)):
		return true
	if not level_open(save, worlds, level):
		return false
	if i == 0:
		return true
	var before := i - 1
	while before > 0 and not worlds[before].has("area"):
		before -= 1
	return world_beaten(save, String(worlds[before]["id"]), level)


## An unlocked world can be played once it has an area built.
static func world_open(save: Dictionary, worlds: Array, i: int, level := 1) -> bool:
	return world_unlocked(save, worlds, i, level) and worlds[i].has("area")


## The indexes of every unlocked world at a Level.
static func unlocked_list(save: Dictionary, worlds: Array, level := 1) -> Array:
	var out := []
	for i in worlds.size():
		if world_unlocked(save, worlds, i, level):
			out.append(i)
	return out


## How many worlds are unlocked at a Level, counting from the first.
static func unlocked_count(save: Dictionary, worlds: Array, level := 1) -> int:
	var n := 0
	while n < worlds.size() and world_unlocked(save, worlds, n, level):
		n += 1
	return n


## The world has been beaten (boss and all) at that Level; level 0 means at
## any Level.
static func world_beaten(save: Dictionary, world_id: String, level := 0) -> bool:
	var marks: Array = save["marks"].get(world_id, [])
	if level <= 0:
		return not marks.is_empty()
	var ids := Content.level_ids(world_id)
	if level > ids.size():
		return false
	# a world with no levels in content (tests, an unbuilt world): ids by number
	var id := int(ids[level - 1]) if int(ids[level - 1]) > 0 else level
	return marks.has(id)


## Every built world beaten at Level n: the full pass is done.
static func level_beaten(save: Dictionary, worlds: Array, n: int) -> bool:
	if n < 1:
		return false
	var any := false
	for w in worlds:
		if not w.has("area"):
			continue
		any = true
		if not world_beaten(save, String(w["id"]), n):
			return false
	return any


## Level 1 is always open; Level n once Level n - 1 is beaten, or once a
## grown-up has picked Level n or higher on the Grown-ups panel.
static func level_open(save: Dictionary, worlds: Array, n: int) -> bool:
	if n < 1 or n > Content.LEVEL_COUNT:
		return false
	if n == 1 or bool(save.get("debug_unlock", false)) or n <= grown_up_level(save):
		return true
	return level_beaten(save, worlds, n - 1)


## The Level a grown-up picked on the Grown-ups panel (Terrence 2026-11-17:
## a parent sets the Level), 0 for none. It opens that Level and the ones
## before it; play can still take the child past it.
static func grown_up_level(save: Dictionary) -> int:
	return int(save.get("grown_up_level", 0))


## A grown-up picks Level n: it is open, and the menu plays it next. Picking
## a lower Level than one already earned only moves the menu back to it.
## A run saved at another Level (a crossing mid-way, or its duel or boss) is
## dropped, so the next play starts fresh at the picked Level.
static func pick_level(save: Dictionary, n: int) -> void:
	n = clampi(n, 1, Content.LEVEL_COUNT)
	save["grown_up_level"] = n
	save["difficulty"] = n
	var run = save.get("run")
	if run is Dictionary and run_level(run) != n:
		save["run"] = null


## The Level number of a saved run (its level id's "num"), 0 if unknown.
static func run_level(run: Dictionary) -> int:
	var l = Content.levels().get(int(run.get("grade", 0)))
	return int(l.get("num", 0)) if l is Dictionary else 0


## After a boss at Level n: the Level to move on to, or 0 to stay. When that
## boss finished Level n (every world beaten at it, and it wasn't before) and
## Level n + 1 is open, the child moves on to it, at Lava. This holds after a
## grown-up picked a higher Level too: beating a lower Level still moves on.
static func move_on_level(save: Dictionary, worlds: Array, n: int, beaten_before: bool) -> int:
	if beaten_before or not level_beaten(save, worlds, n):
		return 0
	return n + 1 if level_open(save, worlds, n + 1) else 0


## The child's Level: the highest one open.
static func level_reached(save: Dictionary, worlds: Array) -> int:
	var n := 1
	while n < Content.LEVEL_COUNT and level_open(save, worlds, n + 1):
		n += 1
	return n


## Big bonuses come once (Phase 1): what beating this world's boss at this
## level pays. "pass" is the first clear that finishes a Level (every other
## world already beaten at it), "first" any other first clear of the world at
## the level, "replay" a world already beaten there.
static func boss_bonus(save: Dictionary, worlds: Array, world_id: String, grade_id: int) -> String:
	if save["marks"].get(world_id, []).has(grade_id):
		return "replay"
	var n := 0
	var ids := Content.level_ids(world_id)
	n = ids.find(grade_id) + 1
	if n < 1:
		return "first"
	for w in worlds:
		if w.has("area") and String(w["id"]) != world_id and not world_beaten(save, String(w["id"]), n):
			return "first"
	return "pass"
