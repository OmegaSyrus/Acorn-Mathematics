## Bounce, the boss-only mode (Phase 6, 2026-11-28): it opens with the first
## boss beaten, lists the beaten bosses, plays each at the child's Level,
## and a win pays the small mode bucket (2 of the world's currency) and
## changes nothing else: no mark, no star, no Level, the saved run kept.
extends "res://tests/support/test_case.gd"

const Content := preload("res://logic/core/content.gd")
const Book := preload("res://logic/core/book.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const Store := preload("res://logic/core/store.gd")
const AreaFlow := preload("res://logic/path/area_flow.gd")
const Modes := preload("res://logic/modes/modes.gd")
const BounceFight := preload("res://logic/bounce/bounce_fight.gd")


func test_bounce_opens_with_a_boss() -> bool:
	var s := SaveData.new_profile("p_000000000001")
	check(not Modes.is_open(s, Modes.BOUNCE), "no boss beaten: locked")
	eq(Modes.bounce_bosses(s), [], "nothing to pick")
	SaveData.add_mark(s, "crystal_mines", Content.level_id("crystal_mines", 1))
	check(Modes.is_open(s, Modes.BOUNCE), "one boss beaten: open")
	check(Modes.is_new(s, Modes.BOUNCE), "New!")
	SaveData.add_mark(s, "lava_caves", 1)
	eq(Modes.bounce_bosses(s), [{"world": "lava_caves", "name": "Lava Caves"},
			{"world": "crystal_mines", "name": "Crystal Mines"}], "beaten bosses in map order")
	return true


func test_bounce_board_follows_the_level() -> bool:
	var levels := Content.levels()
	for w in Content.worlds():
		for n in range(1, Content.LEVEL_COUNT + 1):
			var b := Modes.bounce_board(String(w["id"]), n, levels)
			var id := Content.level_id(String(w["id"]), n)
			eq(b, {"level_id": id, "boss_grade": int(levels[id]["boss_grade"])}, "%s at Level %d" % [w["id"], n])
	return true


func test_bounce_pays_small_and_nothing_else() -> bool:
	var s := SaveData.new_profile("p_000000000001")
	SaveData.add_mark(s, "lava_caves", 1)
	SaveData.add_mark(s, "crystal_mines", Content.level_id("crystal_mines", 1))
	SaveData.add_star(s, "lava_caves", 1)
	s["difficulty"] = 2
	s["run"] = {"area": "bog_scroll", "grade": Content.level_id("bog", 2), "stage": "boss"}
	var before := s.duplicate(true)
	var level_before := AreaFlow.level_reached(s, Content.worlds())
	eq(Modes.bounce_pay(), 2, "the mode's bucket is 2")
	for wid in ["lava_caves", "crystal_mines"]:
		var cur := Store.currency_of_world(Store.catalog(), wid)
		var had := Store.balance(s, cur)
		eq(Modes.bank_bounce(s, wid, Modes.bounce_pay()), cur, "the world's currency")
		eq(Store.balance(s, cur), had + 2, "%s pays 2 %s" % [wid, cur])
	eq(s["marks"], before["marks"], "no marks added")
	eq(s["stars"], before["stars"], "no stars added")
	eq(s["run"], before["run"], "the saved run kept")
	eq(s["difficulty"], before["difficulty"], "the menu's Level kept")
	eq(AreaFlow.level_reached(s, Content.worlds()), level_before, "the Level reached kept")
	# the path's buckets stay as they were, and bigger
	var screen_cfg: Dictionary = BounceFight.load_tuning()["screen"]
	for kind in ["win_gems", "pass_gems", "replay_gems"]:
		check(int(screen_cfg[kind]) > Modes.bounce_pay(), "%s pays more than the mode" % kind)
	return true
