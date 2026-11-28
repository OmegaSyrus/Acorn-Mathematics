## The Grown-ups Level buttons (Terrence 2026-11-17: a parent may pick the
## Level; worlds inside a Level still open only by play): AreaFlow.pick_level
## and save["grown_up_level"], and moving on after a lower Level is beaten.
extends "res://tests/support/test_case.gd"

const AreaFlow := preload("res://logic/path/area_flow.gd")
const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")


## Beats world i at Level n the way the boss does (the mini map step).
func _beat(save: Dictionary, worlds: Array, i: int, n: int) -> void:
	var w: Dictionary = worlds[i]
	AreaFlow.enter(save, Content.area(String(w["area"])), Content.level_id(String(w["id"]), n), AreaFlow.MAP)


func test_pick_opens_lava_only_at_that_level() -> bool:
	var save := SaveData.new_profile("t")
	var worlds := Content.worlds()
	AreaFlow.pick_level(save, 4)
	eq(AreaFlow.grown_up_level(save), 4, "the pick is saved")
	eq(int(save["difficulty"]), 4, "the menu plays the picked Level")
	eq(AreaFlow.level_reached(save, worlds), 4, "the child is at Level 4")
	eq(AreaFlow.unlocked_list(save, worlds, 4), [0], "only Lava open at Level 4")
	for n in range(2, 4):
		eq(AreaFlow.unlocked_list(save, worlds, n), [0], "Lava only at Level %d too" % n)
	check(not AreaFlow.level_open(save, worlds, 5), "Level 5 still shut")
	# the worlds after Lava still open by play
	_beat(save, worlds, 0, 4)
	eq(AreaFlow.unlocked_list(save, worlds, 4), [0, 1], "beating Lava 4 opens Crystal 4")
	check(not AreaFlow.world_open(save, worlds, 2, 4), "Bog 4 waits for Crystal 4")
	# survives the save file
	var back := SaveData.from_text(SaveData.to_text(save), "t")
	eq(AreaFlow.grown_up_level(back), 4, "grown_up_level round trip")
	return true


func test_picking_lower_keeps_earned_levels() -> bool:
	var save := SaveData.new_profile("t")
	var worlds := Content.worlds()
	for n in [1, 2]:
		for i in worlds.size():
			_beat(save, worlds, i, n)
	eq(AreaFlow.level_reached(save, worlds), 3, "Level 3 earned by play")
	AreaFlow.pick_level(save, 1)
	eq(int(save["difficulty"]), 1, "the menu moves back to Level 1")
	eq(AreaFlow.level_reached(save, worlds), 3, "Level 3 still open")
	eq(AreaFlow.unlocked_count(save, worlds, 2), worlds.size(), "Level 2 all still open")
	check(AreaFlow.world_beaten(save, "space", 2), "marks kept")
	return true


func test_each_child_has_their_own_pick() -> bool:
	var a := SaveData.new_profile("p_a")
	var b := SaveData.new_profile("p_b")
	var worlds := Content.worlds()
	AreaFlow.pick_level(a, 5)
	AreaFlow.pick_level(b, 2)
	eq(AreaFlow.grown_up_level(a), 5, "child A at 5")
	eq(AreaFlow.grown_up_level(b), 2, "child B at 2")
	eq(AreaFlow.level_reached(a, worlds), 5, "A reached 5")
	eq(AreaFlow.level_reached(b, worlds), 2, "B reached 2")
	var c := SaveData.new_profile("p_c")
	eq(AreaFlow.grown_up_level(c), 0, "a new child has no pick")
	eq(AreaFlow.level_reached(c, worlds), 1, "a new child starts at Level 1")
	return true


## The audit's bug: a parent picked 5, the child then beat every world at
## Level 2; the last boss must move them on to Level 3, at Lava.
func test_beating_a_lower_picked_level_moves_on() -> bool:
	var save := SaveData.new_profile("t")
	var worlds := Content.worlds()
	AreaFlow.pick_level(save, 5)
	for i in worlds.size():
		var before := AreaFlow.level_beaten(save, worlds, 2)
		_beat(save, worlds, i, 2)
		var next := AreaFlow.move_on_level(save, worlds, 2, before)
		eq(next, 3 if i == worlds.size() - 1 else 0, "after %s 2" % worlds[i]["name"])
	eq(AreaFlow.unlocked_list(save, worlds, 3), [0], "Level 3 opens at Lava")
	# a replay of a beaten Level stays put
	var before2 := AreaFlow.level_beaten(save, worlds, 2)
	_beat(save, worlds, 4, 2)
	eq(AreaFlow.move_on_level(save, worlds, 2, before2), 0, "a replay does not move on")
	# bonuses as before: the last world finishing a Level pays the pass
	for i in worlds.size() - 1:
		_beat(save, worlds, i, 3)
	eq(AreaFlow.boss_bonus(save, worlds, "space", Content.level_id("space", 3)), "pass", "pass bonus at Level 3")
	# without a pick: finishing Level 1 moves on to 2, as before
	var fresh := SaveData.new_profile("u")
	for i in worlds.size():
		var b := AreaFlow.level_beaten(fresh, worlds, 1)
		_beat(fresh, worlds, i, 1)
		if i == worlds.size() - 1:
			eq(AreaFlow.move_on_level(fresh, worlds, 1, b), 2, "Level 1 done moves on to 2")
	# the last Level has nowhere to go
	var top := SaveData.new_profile("v")
	AreaFlow.pick_level(top, Content.LEVEL_COUNT)
	for i in worlds.size():
		_beat(top, worlds, i, Content.LEVEL_COUNT)
	eq(AreaFlow.move_on_level(top, worlds, Content.LEVEL_COUNT, false), 0, "no Level after the last")
	return true


func test_pick_clears_a_mid_run_save() -> bool:
	var worlds := Content.worlds()
	var save := SaveData.new_profile("t")
	var crystal2 := Content.level_id("crystal_mines", 2)
	save["run"] = {"area": String(worlds[1]["area"]), "grade": crystal2, "seed": 7, "pos": 3}
	eq(AreaFlow.run_level(save["run"]), 2, "the run is at Level 2")
	AreaFlow.pick_level(save, 2)
	check(save["run"] is Dictionary, "picking the run's own Level keeps it")
	AreaFlow.pick_level(save, 4)
	check(save["run"] == null, "picking another Level drops the crossing")
	# a duel or boss saved after the door goes too
	AreaFlow.enter(save, Content.area(String(worlds[0]["area"])), Content.level_id("lava_caves", 1), AreaFlow.BOSS)
	check(AreaFlow.is_stage_run(save["run"]), "boss saved")
	AreaFlow.pick_level(save, 3)
	check(save["run"] == null, "picking another Level drops the boss step")
	return true
