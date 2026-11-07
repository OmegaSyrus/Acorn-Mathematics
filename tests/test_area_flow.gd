## The steps after a crossing: door, miniboss duel, boss, mini map.
extends "res://tests/support/test_case.gd"

const AreaFlow := preload("res://logic/path/area_flow.gd")
const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")


func test_lava_door_leads_to_duel_then_boss_then_map() -> bool:
	var area := Content.area("lava_scroll")
	check(AreaFlow.next_stage(area, "") == AreaFlow.DUEL, "door -> duel")
	check(AreaFlow.next_stage(area, AreaFlow.DUEL) == AreaFlow.BOSS, "duel -> boss")
	check(AreaFlow.next_stage(area, AreaFlow.BOSS) == AreaFlow.MAP, "boss -> map")
	return true


func test_missing_steps_are_skipped() -> bool:
	check(AreaFlow.next_stage({"id": "x", "boss": "b"}, "") == AreaFlow.BOSS, "no miniboss -> boss")
	check(AreaFlow.next_stage({"id": "x", "miniboss": "m"}, AreaFlow.DUEL) == AreaFlow.MAP, "no boss -> map")
	check(AreaFlow.next_stage({"id": "x"}, "") == AreaFlow.MAP, "neither -> map")
	return true


func test_save_follows_the_steps() -> bool:
	var area := Content.area("lava_scroll")
	var save := SaveData.new_profile("t")
	AreaFlow.enter(save, area, 1, AreaFlow.DUEL)
	check(AreaFlow.is_stage_run(save["run"]), "duel is saved")
	check(save["run"]["area"] == "lava_scroll" and save["run"]["grade"] == 1, "duel run %s" % [save["run"]])
	# survives the save file round trip
	var back := SaveData.from_text(SaveData.to_text(save), "t")
	check(AreaFlow.is_stage_run(back["run"]) and back["run"]["stage"] == AreaFlow.DUEL, "round trip %s" % [back["run"]])
	check(not AreaFlow.world_beaten(save, "lava_caves"), "not beaten before the boss")
	AreaFlow.enter(save, area, 1, AreaFlow.BOSS)
	check(save["run"]["stage"] == AreaFlow.BOSS, "boss is saved")
	AreaFlow.enter(save, area, 1, AreaFlow.MAP)
	check(save["run"] == null, "nothing to resume on the map")
	check(AreaFlow.world_beaten(save, "lava_caves"), "lava caves beaten")
	return true


func test_a_crossing_run_is_not_a_stage_run() -> bool:
	check(not AreaFlow.is_stage_run(null), "null")
	check(not AreaFlow.is_stage_run({"area": "lava_scroll", "seed": 5, "pos": 3}), "crossing run")
	return true


func test_only_lava_is_open() -> bool:
	var open := []
	for w in Content.worlds():
		if AreaFlow.world_open(w):
			open.append(w["id"])
	check(open == ["lava_caves"], "open worlds %s" % [open])
	return true
