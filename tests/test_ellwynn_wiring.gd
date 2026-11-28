## Phase 3: every cue id the game's code names is on the cue list
## (content/ellwynn_cues.json), so a typo can't leave a screen silent; and
## the one-take helpers (cue_take, teach_take) the boss tips and Level lines
## use. Scans every script under game/, whoever owns it.
extends "res://tests/support/test_case.gd"

const EllwynnScript := preload("res://game/ellwynn.gd")
const SaveData := preload("res://logic/core/save_data.gd")

## Ellwynn's methods whose first argument is a cue id (or an old name).
const CUE_METHODS := ["cue_play", "prompt", "teach", "say", "say_own", "cue_take", "prompt_take",
		"teach_take", "menu_tap", "has_line", "lines_for", "was_taught", "_own_line"]


func _ellwynn() -> Node:
	var e: Node = EllwynnScript.new()
	e._ready()
	e.stand_in_voice = false
	return e


func _scripts(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out


## The code of a script with its comments taken out (a # outside a string).
static func _code(text: String) -> String:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var q := ""
		var cut := line.length()
		var esc := false
		for i in line.length():
			var ch := line[i]
			if esc:
				esc = false
			elif q != "":
				if ch == "\\":
					esc = true
				elif ch == q:
					q = ""
			elif ch == "\"" or ch == "'":
				q = ch
			elif ch == "#":
				cut = i
				break
		out.append(line.substr(0, cut))
	return "\n".join(out)


## True when id is a cue, an old name, or take n of a cue that has n takes
## ("T14_2": the taught mark of the boss's second tip).
func _known(e: Node, id: String) -> bool:
	if e.cues.has(e.resolve(id)):
		return true
	var m := RegEx.create_from_string("^(.+)_(\\d+)$").search(id)
	if m != null:
		var base: String = e.resolve(m.get_string(1))
		return e.cues.has(base) and int(e.cues[base].get("versions", 1)) >= m.get_string(2).to_int()
	return false


## A prefix for world_cue: "B1" is fine when B1-lava ... B1-space all are.
func _world_prefix(e: Node, p: String) -> bool:
	for k in EllwynnScript.WORLD_KEYS.values():
		if not e.cues.has("%s-%s" % [p, k]):
			return false
	return true


func test_every_cue_named_in_code_exists() -> bool:
	var e := _ellwynn()
	var call_re := RegEx.create_from_string("\\b(%s)\\(\\s*\"([^\"]*)\"" % "|".join(CUE_METHODS))
	var world_re := RegEx.create_from_string("world_cue\\(\\s*\"([^\"]*)\"")
	# any string that looks like a sheet id ("P11", "B2-lava", "T14_2")
	var shape_re := RegEx.create_from_string("\"([A-Z][0-9]{1,2}(?:_[0-9]+)?(?:-[a-z]+)?)\"")
	var number_take := RegEx.create_from_string("^[AQ][0-9]{1,2}$")
	var calls := 0
	var files := _scripts("res://game")
	check(files.size() > 20, "found the game's scripts (%d)" % files.size())
	for path in files:
		var code := _code(FileAccess.get_file_as_string(path))
		var prefixes := {}
		for m in world_re.search_all(code):
			var p := m.get_string(1)
			prefixes[p] = true
			check(_world_prefix(e, p), "%s: world_cue(\"%s\") has a cue for every world" % [path, p])
		for m in call_re.search_all(code):
			calls += 1
			var id := m.get_string(2)
			check(_known(e, id), "%s: %s(\"%s\") is on the cue list" % [path, m.get_string(1), id])
		for m in shape_re.search_all(code):
			var id := m.get_string(1)
			if prefixes.has(id) or number_take.search(id) != null:
				continue
			check(_known(e, id), "%s: \"%s\" looks like a cue id but is not on the cue list" % [path, id])
	check(calls > 20, "found the cue calls (%d)" % calls)
	e.free()
	return true


## The comment stripper keeps strings with a # in them.
func test_code_strips_comments_only() -> bool:
	eq(_code("say(\"#P1\") # say(\"X9\")"), "say(\"#P1\") ", "comment cut, string kept")
	return true


## What the map says after a boss (Ellwynn.after_boss_lines) is all on the list.
func test_map_lines() -> bool:
	var e := _ellwynn()
	eq(EllwynnScript.after_boss_lines("", false, true, 1), [], "no boss just beaten: nothing")
	eq(EllwynnScript.after_boss_lines("first", false, true, 2), [["L2", 0], ["L1", 0]], "first clear, next world opens")
	eq(EllwynnScript.after_boss_lines("replay", false, false, 2), [["L5", 0]], "a replay")
	eq(EllwynnScript.after_boss_lines("pass", true, false, 3), [["L3", 0], ["L4", 3]], "Level done: L3 then Level 3's take")
	for l in EllwynnScript.after_boss_lines("pass", true, false, 6) + EllwynnScript.after_boss_lines("first", false, true, 1):
		check(e.cues.has(String(l[0])), "%s listed" % l[0])
	check(int(e.cues["L4"]["versions"]) >= 6, "L4 has a take per Level")
	e.free()
	return true


## cue_take plays one take: file id (or id_1) for 1, id_n for n; a cue
## with no file for that take falls back as listed (quiet here).
func test_cue_take() -> bool:
	var e := _ellwynn()
	var f1 := "res://audio/voice/ellwynn/answer-1.mp3"
	var f2 := "res://audio/voice/ellwynn/answer-2.mp3"
	e.drop_files = {"t14": f1, "t14_2": f2, "l4_1": f1, "l4_3": f2}
	check(e.cue_take("T14", 2), "T14 take 2")
	eq(e._cur_file, f2, "take 2 is T14_2")
	check(e.cue_take("T14", 1), "T14 take 1")
	eq(e._cur_file, f1, "take 1 is T14")
	check(e.cue_take("L4", 1), "L4_1 counts as take 1")
	check(e.cue_take("L4", 3), "Level 3's line")
	eq(e._cur_file, f2, "L4_3")
	check(not e.cue_take("L4", 5), "no line for Level 5: quiet")
	e.drop_files = {}
	check(not e.cue_take("T14", 2), "tts take is quiet with the stand-in off")
	e.stop_voice()
	e.free()
	return true


## The boss's two tips are taught one at a time: T14 (pick) and T14_2 (aim).
func test_teach_take() -> bool:
	var e := _ellwynn()
	var sv := SaveData.new_profile("t_w")
	sv.erase("profile")  # no file write in the test
	check(e.teach_take("T14", 2, sv), "aim tip first (Acorn has no pick)")
	check(e.was_taught("T14_2", sv) and not e.was_taught("T14", sv), "only the aim tip is marked")
	check(not e.teach_take("T14", 2, sv), "aim tip once")
	check(e.teach_take("T14", 1, sv), "the pick tip still comes")
	check(e.was_taught("T14", sv), "pick tip marked as T14")
	eq(e.last_prompt, "T14", "a tip is the prompt to replay")
	eq(e._last_take, 1, "replay says the same take")
	e.clear_prompt()
	eq([e.last_prompt, e._last_take], ["", 0], "cleared")
	sv.erase("taught")  # Debug's Teach again
	check(not e.was_taught("T14", sv) and not e.was_taught("T14_2", sv), "Teach again clears both")
	e.stop_voice()
	e.free()
	return true
