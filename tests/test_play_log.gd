extends "res://tests/support/test_case.gd"

const PlayLog := preload("res://game/play_log.gd")
const AppLife := preload("res://game/app_life.gd")
const Attack := preload("res://logic/fight/attack.gd")
const AttackGen := preload("res://logic/fight/attack_gen.gd")
const BounceFight := preload("res://logic/bounce/bounce_fight.gd")
const SeededRng := preload("res://logic/core/rng.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const Content := preload("res://logic/core/content.gd")

const CTX := {"profile": "1", "world": "lava_caves", "area": "lava_scroll", "level": 1, "level_id": 1}


func _temp_path(name: String) -> String:
	var p := OS.get_temp_dir().path_join("acorn_%s_%d.jsonl" % [name, Time.get_ticks_usec()])
	for q in [p, PlayLog.rotated_path(p)]:
		if FileAccess.file_exists(q):
			DirAccess.remove_absolute(q)
	return p


func _lines(p: String) -> Array:
	if not FileAccess.file_exists(p):
		return []
	var out := []
	for l in FileAccess.get_file_as_string(p).split("\n", false):
		out.append(JSON.parse_string(l))
	return out


func _cleanup(p: String) -> void:
	for q in [p, PlayLog.rotated_path(p)]:
		if FileAccess.file_exists(q):
			DirAccess.remove_absolute(q)


func test_stone_answer_line() -> bool:
	var shown := PlayLog.stone_shown({"op": "add", "dice": [3, 2], "answer": 5, "choices": [1, 2, 3, 4, 5]})
	var e := PlayLog.answer_entry(1763000000, CTX, "stone", shown, 5, 4, 3.44)
	var line := PlayLog.to_line(e)
	check(line.begins_with('{"v":1,"t":1763000000,"kind":"answer","profile":"1","world":"lava_caves"'), line)
	check(not line.contains("\n"), "one line")
	var back = JSON.parse_string(line)
	eq(back["q"], "3 + 2 = ?", "question as shown")
	eq(back["answer"], 5, "answer")
	eq(back["pick"], 4, "pick")
	check(back["right"] == false, "wrong pick is wrong")
	eq(back["secs"], 3.4, "seconds to a tenth")
	eq(back["where"], "stone", "where")
	check(PlayLog.answer_entry(0, CTX, "stone", shown, 5, 5, 1.0)["right"], "right pick is right")
	return true


func test_stone_shown_signs_and_hidden() -> bool:
	eq(PlayLog.stone_shown({"op": "sub", "dice": [6, 2]})["q"], "6 - 2 = ?", "two dice take away")
	eq(PlayLog.stone_shown({"op": "sub", "signs": "++-", "dice": [3, 4, 2]})["q"], "3 + 4 - 2 = ?", "three dice")
	var h := PlayLog.stone_shown({"op": "add", "signs": "++", "dice": [3, 2], "hidden": 1, "total": 5})
	eq(h["q"], "3 + ? = 5", "face-down die")
	eq(h["hidden"], 1, "hidden place kept")
	return true


func test_real_rolls_read_right() -> bool:
	# every crossing roll at every level reads as a sum that comes to the answer
	var levels := Content.levels()
	for id in levels:
		var lv: Dictionary = levels[id]
		var area := Content.area("lava_scroll")
		var run := ScrollRun.new(area, lv, 7 + int(id))
		for k in 5:
			var p := run.roll()
			var s := PlayLog.stone_shown(p)
			var q: String = s["q"]
			var answer := int(p["answer"])
			if p.has("hidden"):
				q = q.replace("?", str(answer)).split(" = ")[0]
			else:
				q = q.split(" = ")[0]
			var expr := Expression.new()
			check(expr.parse(q) == OK, "level %d parses: %s" % [id, s["q"]])
			eq(expr.execute(), int(p.get("total", answer)) if p.has("hidden") else answer, "level %d: %s" % [id, s["q"]])
			run.choose(int(p["answer_index"]))
			if run.phase != ScrollRun.AWAIT_ROLL:
				break
	return true


func test_fight_and_boss_shown() -> bool:
	var a := Attack.new()
	a.kind = Attack.Kind.DIE_AND_TARGET
	a.dice.assign([3])
	a.target = 7
	a.answer = 4
	a.choices.assign([2, 4, 5, 6])
	var s := PlayLog.fight_shown(a, "block")
	eq(s["q"], "3 + ? = 7", "die and target")
	eq(s["phase"], "block", "phase")
	a.kind = Attack.Kind.ONE_DIE
	eq(PlayLog.fight_shown(a, "bash")["q"], "count 3", "one die")
	for g in [1, 2, 3, 4]:
		var atk = AttackGen.generate(SeededRng.new(g), g, 0)
		check(PlayLog.fight_shown(atk, "block")["q"] != "", "grade %d swing reads" % g)
	var bf := BounceFight.new(SeededRng.new(5), 2)
	var b := PlayLog.boss_shown(bf)
	eq(b["target"], bf.target, "boss number")
	check(str(b["q"]).contains(str(bf.target)), "boss question names the number")
	check(PlayLog.to_line(PlayLog.answer_entry(0, CTX, "boss", b, bf.answer_face, bf.answer_face, 2.0)) != "", "boss line")
	return true


func test_event_line() -> bool:
	var e := PlayLog.event_entry(1763000000, CTX, "restart", {"why": "fall", "attempt": 2})
	eq(PlayLog.to_line(e),
		'{"v":1,"t":1763000000,"kind":"event","profile":"1","world":"lava_caves","area":"lava_scroll","level":1,"level_id":1,"event":"restart","why":"fall","attempt":2}',
		"event line")
	eq(PlayLog.event_entry(5, {}, "app_paused")["event"], "app_paused", "no place yet is fine")
	return true


func test_append_and_rotate() -> bool:
	var p := _temp_path("log")
	PlayLog.append('{"a":1}', p)
	PlayLog.append('{"a":2}', p)
	eq(_lines(p), [{"a": 1}, {"a": 2}], "appends in order")
	# fill past 1 MB: it moves to .1 and a new file starts
	var big := '{"pad":"%s"}' % "x".repeat(1000)
	var f := FileAccess.open(p, FileAccess.READ_WRITE)
	f.seek_end()
	for i in 1000:
		f.store_line(big)
	f.close()
	PlayLog.append('{"a":3}', p)
	eq(_lines(p), [{"a": 3}], "a fresh file after the move")
	check(FileAccess.file_exists(PlayLog.rotated_path(p)), "old lines kept in .1")
	var old_size := FileAccess.open(PlayLog.rotated_path(p), FileAccess.READ).get_length()
	check(old_size > PlayLog.MAX_BYTES, "the .1 file is the full one")
	check(PlayLog.rotated_path("user://play_log.jsonl") == "user://play_log.1.jsonl", "rotated name")
	_cleanup(p)
	return true


func test_static_writes_use_path_and_place() -> bool:
	var p := _temp_path("place")
	var keep_path := PlayLog.path
	var keep_place := PlayLog.place.duplicate()
	PlayLog.path = p
	PlayLog.set_profile("2")
	PlayLog.set_place({"id": "crystal_scroll", "world": "crystal_mines"}, 21, 1)
	PlayLog.event("run_start")
	PlayLog.answer("duel", {"q": "4 + 1 = ?"}, 5, 5, 1.25)
	var lines := _lines(p)
	PlayLog.path = keep_path
	PlayLog.place = keep_place
	eq(lines.size(), 2, "two lines")
	if lines.size() == 2:
		eq(lines[0]["event"], "run_start", "event")
		eq(lines[0]["world"], "crystal_mines", "world")
		eq(lines[1]["level_id"], 21, "level id")
		eq(lines[1]["profile"], "2", "profile")
		check(lines[1]["right"] == true, "right")
		check(lines[1]["t"] > 1700000000, "unix time")
	_cleanup(p)
	return true


# --- the app's back gesture and pause ----------------------------------------

func test_back_never_quits() -> bool:
	check(ProjectSettings.get_setting("application/config/quit_on_go_back", true) == false,
		"project.godot: quit_on_go_back is false")
	eq(AppLife.action_for(Node.NOTIFICATION_WM_GO_BACK_REQUEST, true), "back", "back is taken")
	var life := AppLife.new()
	var calls := []
	life.save_now = func(): calls.append("save")
	life._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	eq(calls, [], "back does nothing else")
	eq(life.back_requests, 1, "counted")
	life.free()
	return true


func test_pause_saves_and_holds_music_once() -> bool:
	var p := _temp_path("life")
	var keep_path := PlayLog.path
	PlayLog.path = p
	var life := AppLife.new()
	life.mobile = true
	var calls := []
	life.save_now = func(): calls.append("save")
	life.pause_music = func(): calls.append("pause")
	life.resume_music = func(): calls.append("resume")
	life._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	life._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	life._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	life._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	eq(calls, ["save", "pause", "resume"], "one pause and one resume on a tablet")
	var events := []
	for l in _lines(p):
		events.append(l["event"])
	eq(events, ["app_paused", "app_resumed"], "logged once each")
	# a desktop losing focus only saves; the music plays on
	calls.clear()
	life.mobile = false
	life._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	life._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	eq(calls, ["save"], "desktop focus out saves only")
	PlayLog.path = keep_path
	life.free()
	_cleanup(p)
	return true
