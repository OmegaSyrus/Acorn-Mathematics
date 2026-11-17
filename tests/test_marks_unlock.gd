## Level marks and stars in every world, the Level path's unlocks (Phase 1,
## 2026-11-16: only play moves a child on), and old saves loading with the
## new fields.
extends "res://tests/support/test_case.gd"

const AreaFlow := preload("res://logic/path/area_flow.gd")
const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")


func test_new_profile_has_stars_and_no_grown_up_opens() -> bool:
	var save := SaveData.new_profile("t")
	check(save["stars"] is Dictionary and save["stars"].is_empty(), "stars empty")
	check(not save.has("parent_open"), "no grown-up opens")
	return true


## A save written before these fields (as on the tablet) loads with the
## defaults and keeps what it had.
func test_old_save_loads() -> bool:
	var old := '{"version": 1, "profile": "p", "stickers": [], "gems": 9, "marks": {"lava_caves": [1]},' \
			+ ' "run": null, "currencies": {}, "owned": [], "hero": "robodragon", "dice": "classic", "difficulty": 2}'
	var save := SaveData.from_text(old, "p")
	check(int(save["gems"]) == 9 and int(save["difficulty"]) == 2, "kept gems and difficulty")
	check(SaveData.has_mark(save, "lava_caves", 1), "kept the lava mark")
	check(save["stars"] is Dictionary, "new fields defaulted")
	# hand-broken new fields fall back too
	var broken := SaveData.from_text('{"stars": 3}', "p")
	check(broken["stars"] is Dictionary, "broken fields defaulted")
	# a save with the old Grown-ups opens drops them: they no longer open a world
	var opened := SaveData.from_text('{"parent_open": ["space"]}', "p")
	check(not opened.has("parent_open"), "old grown-up opens dropped")
	check(not AreaFlow.world_open(opened, Content.worlds(), 4, 1), "Space stays shut")
	return true


func test_marks_and_stars_in_every_world() -> bool:
	var save := SaveData.new_profile("t")
	for w in Content.worlds():
		var wid := String(w["id"])
		var ids := Content.level_ids(wid)
		check(ids.size() == 6 and not ids.has(0), "%s has six levels %s" % [wid, ids])
		var area := Content.area(String(w["area"]))
		check(String(area.get("world", "")) == wid, "%s area names its world" % wid)
		# beating level 3 marks that level only
		AreaFlow.enter(save, area, ids[2], AreaFlow.MAP)
		check(SaveData.has_mark(save, wid, ids[2]), "%s level 3 marked" % wid)
		check(not SaveData.has_mark(save, wid, ids[1]), "%s level 2 not marked" % wid)
		SaveData.add_star(save, wid, ids[2])
		SaveData.add_star(save, wid, ids[2])
		check(save["stars"][wid] == [ids[2]], "%s star once" % wid)
		check(not SaveData.has_star(save, wid, ids[0]), "%s no star at level 1" % wid)
	var back := SaveData.from_text(SaveData.to_text(save), "t")
	check(SaveData.has_star(back, "space", Content.level_id("space", 3)), "stars survive the round trip")
	check(SaveData.has_mark(back, "bog", Content.level_id("bog", 3)), "marks survive the round trip")
	return true


## Level N is one pass of the five worlds: at a Level, each world opens
## when the one before it is beaten there; Level N + 1 opens (at Lava) when
## Space is beaten at Level N. Beating a world at one Level opens nothing at
## another.
func test_level_path_opens_by_play_only() -> bool:
	var save := SaveData.new_profile("t")
	var worlds := Content.worlds()
	eq(AreaFlow.level_reached(save, worlds), 1, "a new child is at Level 1")
	eq(AreaFlow.unlocked_list(save, worlds, 1), [0], "only Lava at Level 1")
	check(not AreaFlow.level_open(save, worlds, 2), "Level 2 shut")
	eq(AreaFlow.unlocked_list(save, worlds, 2), [], "nothing at Level 2")
	for i in worlds.size():
		var w: Dictionary = worlds[i]
		check(AreaFlow.world_open(save, worlds, i, 1), "%s open at Level 1 in turn" % w["name"])
		if i + 1 < worlds.size():
			check(not AreaFlow.world_open(save, worlds, i + 1, 1), "%s shut before %s" % [worlds[i + 1]["name"], w["name"]])
		eq(AreaFlow.level_reached(save, worlds), 1, "still Level 1 before %s" % w["name"])
		var bonus := AreaFlow.boss_bonus(save, worlds, String(w["id"]), Content.level_id(String(w["id"]), 1))
		eq(bonus, "pass" if i == worlds.size() - 1 else "first", "%s pays a first-time bonus" % w["name"])
		AreaFlow.enter(save, Content.area(String(w["area"])), Content.level_id(String(w["id"]), 1), AreaFlow.MAP)
		eq(AreaFlow.boss_bonus(save, worlds, String(w["id"]), Content.level_id(String(w["id"]), 1)), "replay",
				"%s again pays small" % w["name"])
	eq(AreaFlow.level_reached(save, worlds), 2, "beating Space opens Level 2")
	eq(AreaFlow.unlocked_list(save, worlds, 2), [0], "Level 2 starts again at Lava")
	eq(AreaFlow.unlocked_count(save, worlds, 1), worlds.size(), "Level 1 all open to replay")
	# a mark at a later Level (an old save, a Debug jump) skips nothing
	AreaFlow.enter(save, Content.area("bog_scroll"), Content.level_id("bog", 2), AreaFlow.MAP)
	check(not AreaFlow.world_open(save, worlds, 1, 2), "Crystal 2 still waits for Lava 2")
	check(AreaFlow.world_open(save, worlds, 3, 2), "Mushroom 2 opens after Bog 2")
	eq(AreaFlow.level_reached(save, worlds), 2, "still Level 2")
	# Debug's "Map: all open" opens every world at every Level
	save["debug_unlock"] = true
	eq(AreaFlow.level_reached(save, worlds), Content.LEVEL_COUNT, "Debug opens every Level")
	check(AreaFlow.world_open(save, worlds, 4, 6), "Debug opens Space 6")
	return true


## A crossing is "hurt" once a heart is lost: a wrong stone, a fight that
## cost hearts, or a restart. Old saves past a restart count as hurt.
func test_crossing_hurt() -> bool:
	var area := Content.area("lava_scroll")
	var grade: Dictionary = Content.levels()[1]
	var run := ScrollRun.new(area, grade, 7)
	check(not run.hurt, "fresh crossing unhurt")
	run.roll()
	run.choose(run.problem["answer_index"])
	if run.phase == ScrollRun.AWAIT_FIGHT:
		run.resolve_fight(true, run.hearts)
	check(not run.hurt, "right stones and a clean fight keep it unhurt")
	if run.phase == ScrollRun.AWAIT_ROLL:
		run.roll()
		run.choose((run.problem["answer_index"] + 1) % run.problem["choices"].size())
		check(run.hurt, "a wrong stone hurts")
		var data := run.to_save()
		var again := ScrollRun.new(area, grade, data["seed"])
		again.restore(data)
		check(again.hurt, "hurt survives a resume")
	var old := run.to_save()
	old.erase("hurt")
	old["attempt"] = 1
	var r1 := ScrollRun.new(area, grade, old["seed"])
	r1.restore(old)
	check(not r1.hurt, "old save, first attempt: unhurt")
	old["attempt"] = 2
	var r2 := ScrollRun.new(area, grade, old["seed"])
	r2.restore(old)
	check(r2.hurt, "old save after a restart: hurt")
	return true
