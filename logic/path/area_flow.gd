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


## A world on the mini map is unlocked once the world before it has been
## beaten (Terrence 2026-11-07: the map unlocks the next area when the
## previous one is complete). The first world is always unlocked.
## The Debug screen's "Map: all open" (save["debug_unlock"]) unlocks them all.
static func world_unlocked(save: Dictionary, worlds: Array, i: int) -> bool:
	if bool(save.get("debug_unlock", false)) and i < worlds.size():
		return true
	return i == 0 or (i < worlds.size() and world_beaten(save, String(worlds[i - 1]["id"])))


## An unlocked world can be played once it has an area built.
static func world_open(save: Dictionary, worlds: Array, i: int) -> bool:
	return world_unlocked(save, worlds, i) and worlds[i].has("area")


## How many worlds are unlocked, counting from the first.
static func unlocked_count(save: Dictionary, worlds: Array) -> int:
	var n := 0
	while n < worlds.size() and world_unlocked(save, worlds, n):
		n += 1
	return n


## The world has been beaten (boss and all) at some grade.
static func world_beaten(save: Dictionary, world_id: String) -> bool:
	return save["marks"].has(world_id) and not save["marks"][world_id].is_empty()
