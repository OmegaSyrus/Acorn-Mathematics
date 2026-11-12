## Level marks and stars in every world, the Grown-ups unlock, and old saves
## loading with the new fields (2026-11-12).
extends "res://tests/support/test_case.gd"

const AreaFlow := preload("res://logic/path/area_flow.gd")
const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")


func test_new_profile_has_stars_and_parent_open() -> bool:
	var save := SaveData.new_profile("t")
	check(save["stars"] is Dictionary and save["stars"].is_empty(), "stars empty")
	check(save["parent_open"] is Array and save["parent_open"].is_empty(), "parent_open empty")
	return true


## A save written before these fields (as on the tablet) loads with the
## defaults and keeps what it had.
func test_old_save_loads() -> bool:
	var old := '{"version": 1, "profile": "p", "stickers": [], "gems": 9, "marks": {"lava_caves": [1]},' \
			+ ' "run": null, "currencies": {}, "owned": [], "hero": "robodragon", "dice": "classic", "difficulty": 2}'
	var save := SaveData.from_text(old, "p")
	check(int(save["gems"]) == 9 and int(save["difficulty"]) == 2, "kept gems and difficulty")
	check(SaveData.has_mark(save, "lava_caves", 1), "kept the lava mark")
	check(save["stars"] is Dictionary and save["parent_open"] is Array, "new fields defaulted")
	# hand-broken new fields fall back too
	var broken := SaveData.from_text('{"stars": 3, "parent_open": "x"}', "p")
	check(broken["stars"] is Dictionary and broken["parent_open"] is Array, "broken fields defaulted")
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


func test_grown_up_opens_any_world() -> bool:
	var save := SaveData.new_profile("t")
	var worlds := Content.worlds()
	check(not AreaFlow.world_open(save, worlds, 3), "mushroom forest locked at first")
	SaveData.set_parent_open(save, "mushroom_forest", true)
	SaveData.set_parent_open(save, "mushroom_forest", true)
	check(save["parent_open"] == ["mushroom_forest"], "listed once")
	check(AreaFlow.world_open(save, worlds, 3), "grown-up opened the mushroom forest")
	check(not AreaFlow.world_open(save, worlds, 1), "crystal mines still locked")
	check(not AreaFlow.world_unlocked_by_play(save, worlds, 3), "not opened by play")
	check(AreaFlow.unlocked_list(save, worlds) == [0, 3], "unlocked %s" % [AreaFlow.unlocked_list(save, worlds)])
	# survives the save file, then closes again
	var back := SaveData.from_text(SaveData.to_text(save), "t")
	check(AreaFlow.world_open(back, worlds, 3), "kept after a reload")
	SaveData.set_parent_open(back, "mushroom_forest", false)
	check(not AreaFlow.world_open(back, worlds, 3), "closed again")
	# play still opens the next world as before
	AreaFlow.enter(back, Content.area("lava_scroll"), 1, AreaFlow.MAP)
	check(AreaFlow.world_unlocked_by_play(back, worlds, 1) and AreaFlow.world_open(back, worlds, 1),
			"beating lava opens the crystal mines")
	# the first world can't be closed
	SaveData.set_parent_open(back, "lava_caves", false)
	check(AreaFlow.world_open(back, worlds, 0), "lava always open")
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
