## Phase 3 voice cues: the cue list, the drop-in names, fallbacks and the
## taught-once marks (game/ellwynn.gd, content/ellwynn_cues.json).
extends "res://tests/support/test_case.gd"

const EllwynnScript := preload("res://game/ellwynn.gd")
const SaveData := preload("res://logic/core/save_data.gd")


func _ellwynn() -> Node:
	var e: Node = EllwynnScript.new()
	e._ready()  # not in a tree: the runner has none yet
	e.stand_in_voice = false
	return e


func test_cue_list_matches_sheet() -> bool:
	var e := _ellwynn()
	var basic := 0
	for id in e.cues:
		var c: Dictionary = e.cues[id]
		check(String(c["fallback"]) in ["placeholder", "tts", "quiet"], "%s fallback" % id)
		check(c["fallback"] != "tts" or String(c["say"]) != "", "%s tts needs words" % id)
		if c["need"] == "basic":
			basic += 1
	for id in ["K1", "M1", "T1", "T15", "P1", "P13", "W5", "N11", "C3", "F7", "D8",
			"B1-lava", "B2-space", "B4", "H7", "R3", "L5", "S3"]:
		check(e.cues.has(id), "sheet cue %s listed" % id)
	check(basic > 60, "basic cues %d" % basic)
	e.free()
	return true


func test_aliases() -> bool:
	var e := _ellwynn()
	eq([e.resolve("intro"), e.resolve("welcome"), e.resolve("play"), e.resolve("shop"),
			e.resolve("enemy"), e.resolve("chest"), e.resolve("count_then"),
			e.resolve("count_back_then"), e.resolve("count_quiet"), e.resolve("T3")],
			["M1", "M2", "M3", "M5", "F5", "C5", "H3", "H4", "H7", "T3"], "old names map to sheet ids")
	eq(EllwynnScript.world_cue("B2", "mushroom_forest"), "B2-mushroom", "world cue")
	eq(EllwynnScript.world_cue("B1", "lava_caves"), "B1-lava", "world cue lava")
	e.free()
	return true


## Files are matched by id, any case, with _2, _3 ... as more takes; the
## numbers A/Q override the answer takes.
func test_drop_in_names() -> bool:
	var e := _ellwynn()
	var f1 := "res://audio/voice/ellwynn/answer-1.mp3"
	var f2 := "res://audio/voice/ellwynn/answer-2.mp3"
	e.drop_files = {"p3": f1, "p3_2": f2, "m1": f1, "m1_3": f2, "a5": f2, "q4": f1}
	eq(e.lines_for("P3").map(func(l): return l["file"]), [f1, f2], "P3 two takes")
	eq(e.lines_for("intro").map(func(l): return l["file"]), [f1, f2], "intro by alias, in order")
	check(e.has_line("P3") and not e.has_line("P4"), "has_line")
	eq(e.answer_file(5), f2, "A5 replaces answer-5")
	eq(e.answer_file(6), "res://audio/voice/ellwynn/answer-6.mp3", "answer-6 kept")
	eq(e._number_file(4), f1, "Q4 is the plain count take")
	eq(e._number_file(6), e.answer_file(6), "no Q6: counting uses A6")
	e.free()
	return true


func test_scan_is_case_blind() -> bool:
	var e := _ellwynn()
	e.scan_drop_folder("res://audio/voice/ellwynn/")
	check(e.drop_files.has("answer-3"), "scan finds imported files")
	check(not e.drop_files.has("readme"), "only audio")
	e.free()
	return true


func test_fallbacks() -> bool:
	var e := _ellwynn()
	e.drop_files = {}
	check(e.cue_play("M2"), "welcome falls back to a placeholder")
	check(not e.cue_play("H3"), "count_then stays quiet")
	check(not e.cue_play("P3"), "a tts prompt is quiet with the stand-in voice off (and headless)")
	e.stop_voice()
	e.free()
	return true


func test_teach_once_per_child() -> bool:
	var e := _ellwynn()
	var a := SaveData.new_profile("t_a")
	a.erase("profile")  # no file write in the test
	var b := {}
	check(not e.was_taught("T2", a), "not yet")
	e.teach("T2", a)
	check(e.was_taught("T2", a), "marked")
	check(not e.teach("T2", a), "second time does nothing")
	check(not e.was_taught("T2", b), "another child still gets it")
	eq(e.last_prompt, "T2", "a taught line is the prompt to replay")
	e.stop_voice()
	e.free()
	return true


func test_taught_merges() -> bool:
	var one := SaveData.new_profile("p")
	one["taught"] = {"T1": true}
	var two := SaveData.new_profile("p")
	two["taught"] = {"T2": true}
	var out := SaveData.merge([{"saved_at": 1, "save": one}, {"saved_at": 2, "save": two}], "p")
	eq(out.get("taught", {}), {"T1": true, "T2": true}, "taught is a union")
	return true
