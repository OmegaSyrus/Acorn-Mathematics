extends "res://tests/support/test_case.gd"
## The Debug fight switch (Phase 2 of the ship plan, 2026-11-28): monster
## fights ask the step before's math (the default) or the level's own, and
## the play log notes which on every line.

const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const PlayLog := preload("res://game/play_log.gd")


func test_switch_picks_the_fight_monsters_ask() -> bool:
	# the first level on the path whose own fight is not the step before's
	var lv := {}
	for l in Content.level_path(Content.levels()):
		if l["fight"] != l["monster_fight"]:
			lv = l
			break
	check(not lv.is_empty(), "some level's own fight differs from the step before's")
	var area_id := ""
	for w in Content.worlds():
		if w["id"] == lv["world"]:
			area_id = String(w["area"])
	var run := ScrollRun.new(Content.area(area_id), lv, 5)
	eq(run.fight_math, ScrollRun.FIGHTS_STEP_BEFORE, "the default asks the step before")
	# walk past the warm-up so the stage is the level's own
	var k := 0
	while run.phase != ScrollRun.CLEARED and k < 6:
		if run.phase == ScrollRun.AWAIT_FIGHT:
			run.resolve_fight(true)
			continue
		run.roll()
		run.choose(int(run.problem["answer_index"]))
		k += 1
	var st := run.stage(maxi(0, run.rolls - 1))
	eq(run.fight_now(), st.get("monster_fight", st["fight"]), "step before: the stage's monster fight")
	run.fight_math = ScrollRun.FIGHTS_OWN
	eq(run.fight_now(), st["fight"], "own math: the stage's own fight")
	check(st["fight"] != st.get("monster_fight", st["fight"]), "%s: the two settings ask different fights" % lv["name"])
	return true


func test_setting_reads_safely_from_a_save() -> bool:
	eq(ScrollRun.fights_setting({}), ScrollRun.FIGHTS_STEP_BEFORE, "no setting: step before")
	eq(ScrollRun.fights_setting({"fight_math": "own"}), ScrollRun.FIGHTS_OWN, "own")
	eq(ScrollRun.fights_setting({"fight_math": "junk"}), ScrollRun.FIGHTS_STEP_BEFORE, "unknown: step before")
	return true


func test_play_log_notes_the_switch() -> bool:
	var ctx := {"profile": "1", "world": "lava_caves", "level": 2, "level_id": 2, "fights": "own"}
	var e := PlayLog.event_entry(100, ctx, "run_start")
	eq(e.get("fights"), "own", "run line notes the setting")
	var a := PlayLog.answer_entry(100, ctx, "fight", {"q": "3 + 2 = ?"}, 5, 5, 1.0)
	eq(a.get("fights"), "own", "answer line notes the setting")
	return true
