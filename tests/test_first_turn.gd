## Phase 3: the taught first turn, the first-time math lines and who may
## speak when (logic/core/first_turn.gd, logic/core/voice_turns.gd).
extends "res://tests/support/test_case.gd"

const FirstTurn := preload("res://logic/core/first_turn.gd")
const VoiceTurns := preload("res://logic/core/voice_turns.gd")
const Content := preload("res://logic/core/content.gd")


func _cues() -> Dictionary:
	var out := {}
	var data = JsonUtil.load_file("res://content/ellwynn_cues.json")
	for c in data["cues"]:
		out[String(c["id"])] = c
	return out


## A child's taught marks as the game keeps them (save["taught"]).
func _model(save: Dictionary) -> FirstTurn:
	return FirstTurn.new(func(id: String) -> bool: return bool(save.get("taught", {}).get(id, false)))


func _mark(save: Dictionary, id: String) -> void:
	if not save.has("taught"):
		save["taught"] = {}
	save["taught"][id] = true


func test_cue_ids_are_on_the_sheet() -> bool:
	var cues := _cues()
	for id in FirstTurn.FIRST_TURN + FirstTurn.HINTED:
		check(cues.has(id), "%s on the sheet" % id)
		check(bool(cues.get(id, {}).get("once", false)), "%s is once per child" % id)
	for w in FirstTurn.WORLD_ORDER:
		check(cues.has(FirstTurn.world_number_cue("W", w)), "world arrival for %s" % w)
		check(cues.has(FirstTurn.world_number_cue("D", w)), "duel intro for %s" % w)
	for n in range(1, 12):
		check(bool(cues.get("N%d" % n, {}).get("once", false)), "N%d is once per child" % n)
	return true


func test_world_cues_by_world_order() -> bool:
	eq([FirstTurn.world_number_cue("W", "lava_caves"), FirstTurn.world_number_cue("W", "crystal_mines"),
			FirstTurn.world_number_cue("W", "bog"), FirstTurn.world_number_cue("W", "mushroom_forest"),
			FirstTurn.world_number_cue("W", "space")], ["W1", "W2", "W3", "W4", "W5"], "W1..W5")
	eq(FirstTurn.world_number_cue("D", "bog"), "D3", "Bog miniboss intro")
	eq(FirstTurn.world_number_cue("W", "nowhere"), "W1", "unknown world reads as Lava")
	return true


## Every step of the level path that adds something has its first-time
## line, and each line is one the sheet lists for it.
func test_level_cues_follow_the_path() -> bool:
	var levels := Content.levels()
	var want := {1: "", 21: "N1", 31: "N2", 12: "N3", 22: "N4", 52: "N5", 23: "N6", 14: "N7",
			15: "N8", 45: "N9", 16: "N10", 46: "N11", 56: "N11"}
	for id in want:
		eq(FirstTurn.level_cue(levels[id]), want[id], "level %d" % id)
	var cues := _cues()
	for id in levels:
		var c := FirstTurn.level_cue(levels[id])
		check(c == "" or cues.has(c), "level %d cue %s listed" % [id, c])
		check(c != "" or String(levels[id].get("new", "")) == "start", "level %d has a first-time line" % id)
	return true


func _stage(level: Dictionary, warm: bool) -> Dictionary:
	return level["ramp"][0 if warm else 1]


func test_new_math_from_the_roll() -> bool:
	var lv := Content.levels()
	# Lava 1: one die, nothing new
	eq(FirstTurn.new_math_cues({"op": "add", "dice": [3], "signs": "+"}, _stage(lv[1], false), lv[1]), [], "one die")
	# Crystal 1: its warm-up is Lava 1's one die, then two dice
	eq(FirstTurn.new_math_cues({"op": "add", "dice": [2], "signs": "+"}, _stage(lv[21], true), lv[21]), [], "warm-up")
	eq(FirstTurn.new_math_cues({"op": "add", "dice": [2, 3], "signs": "++"}, _stage(lv[21], false), lv[21]), ["N1"], "two dice")
	# Bog 1: two dice to 8, the top goes up
	eq(FirstTurn.new_math_cues({"op": "add", "dice": [4, 3], "signs": "++"}, _stage(lv[31], false), lv[31])[0], "N2", "bigger numbers")
	eq(FirstTurn.new_math_cues({"op": "add", "dice": [4, 3], "signs": "++"}, _stage(lv[31], true), lv[31]), ["N1"], "Bog 1 warm-up: no N2")
	# Lava 2: the red die
	eq(FirstTurn.new_math_cues({"op": "sub", "dice": [5, 2], "signs": "+-"}, _stage(lv[12], false), lv[12]), ["N3", "N1"], "take-away first")
	# Crystal 2: three dice
	eq(FirstTurn.new_math_cues({"op": "add", "dice": [1, 2, 3], "signs": "+++"}, _stage(lv[22], false), lv[22])[0], "N4", "three dice")
	# Space 2: the star track, on its own stage only
	eq(FirstTurn.new_math_cues({"op": "add", "dice": [1, 2, 3], "signs": "+++"}, _stage(lv[52], false), lv[52])[0], "N5", "track")
	check(not FirstTurn.new_math_cues({"op": "add", "dice": [1, 2], "signs": "++"}, _stage(lv[52], true), lv[52]).has("N5"), "no track in its warm-up")
	# Crystal 3: the rails
	eq(FirstTurn.new_math_cues({"op": "add", "dice": [1, 2, 3], "signs": "+++"}, _stage(lv[23], false), lv[23])[0], "N6", "rails")
	# Lava 4: four dice
	eq(FirstTurn.new_math_cues({"op": "add", "dice": [1, 2, 3, 4], "signs": "++++"}, _stage(lv[14], false), lv[14])[0], "N7", "four dice")
	# Lava 5: the hidden die; Mushroom 5: hidden in any place
	eq(FirstTurn.new_math_cues({"op": "add", "dice": [3, 2], "signs": "++", "hidden": 1, "total": 5}, _stage(lv[15], false), lv[15])[0], "N8", "hidden")
	eq(FirstTurn.new_math_cues({"op": "add", "dice": [3, 2, 1], "signs": "+++", "hidden": 0, "total": 6}, _stage(lv[45], false), lv[45])[0], "N9", "hidden anywhere")
	# Lava 6 and Mushroom 6: about the level, on its own stage
	eq(FirstTurn.new_math_cues({"op": "sub", "dice": [6, 6, 3], "signs": "++-"}, _stage(lv[16], false), lv[16])[0], "N10", "across ten")
	eq(FirstTurn.new_math_cues({"op": "add", "dice": [6, 6], "signs": "++"}, _stage(lv[46], false), lv[46])[0], "N11", "mixed")
	return true


func test_warmup_done() -> bool:
	var lv: Dictionary = Content.levels()[21]
	check(FirstTurn.warmup_done(lv["ramp"][0], lv["ramp"][1]), "warm-up to own")
	check(not FirstTurn.warmup_done(lv["ramp"][0], lv["ramp"][0]), "still warming up")
	check(not FirstTurn.warmup_done(lv["ramp"][1], lv["ramp"][1]), "own to own")
	return true


## The first turn in order, each step once; the same child again gets no
## hint and no line anywhere; another child still gets them all.
func test_first_turn_once_per_child() -> bool:
	var save := {}
	var ft := _model(save)
	var order := []
	for id in ["T2", "T3", "T4", "T5"]:
		check(ft.begin(id), "%s taught to a new child" % id)
		check(ft.is_on(id), "%s hint on" % id)
		order.append(ft.current)
		check(ft.finish(id), "%s done" % id)
		_mark(save, id)
		check(not ft.is_on(id), "%s hint off" % id)
	eq(order, ["T2", "T3", "T4", "T5"], "steps in order")
	for id in ["T2", "T3", "T4", "T5"]:
		check(not ft.begin(id), "%s not again for this child" % id)
		eq(ft.current, "", "no hint for a taught child")
	var other := _model({"taught": {"T2": true}})
	check(not other.begin("T2") and other.begin("T3"), "another child: by their own marks")
	return true


## Finishing a step that isn't the one shown does nothing (a pip tap with
## no T3 on, a pick after the step already ended).
func test_finish_only_the_step_shown() -> bool:
	var ft := _model({})
	check(not ft.finish("T3"), "nothing on")
	ft.begin("T4")
	check(not ft.finish("T3"), "another step")
	check(ft.is_on("T4"), "T4 still on")
	return true


## No tap at a taught step: the line once more after IDLE_REPLAY_S of quiet,
## and only once; the wait doesn't count while she talks or before the line.
func test_idle_replay_once() -> bool:
	var ft := _model({})
	ft.begin("T2")
	eq(ft.tick(FirstTurn.IDLE_REPLAY_S + 1.0, false), "", "no replay before the line was said")
	ft.line_said("T2")
	eq(ft.tick(FirstTurn.IDLE_REPLAY_S + 1.0, true), "", "her talking doesn't count")
	eq(ft.tick(FirstTurn.IDLE_REPLAY_S - 0.5, false), "", "not yet")
	eq(ft.tick(1.0, false), "replay", "replayed after the wait")
	var again := ""
	for i in 40:
		again += ft.tick(1.0, false)
	eq(again, "", "only once")
	check(ft.is_on("T2"), "the hint stays until the step is done")
	return true


## T3 (count the dots) has nothing to tap: it ends by itself after its line.
func test_t3_moves_on() -> bool:
	var ft := _model({})
	ft.begin("T3", FirstTurn.T3_MOVE_ON_S)
	eq(ft.tick(5.0, false), "", "waits for the line")
	ft.line_said("T3")
	eq(ft.tick(FirstTurn.T3_MOVE_ON_S + 0.1, false), "done", "moves on after the line")
	return true


## The right number, the answer and the count come first: a prompt never
## starts while one is due (say_answer waits ANSWER_DELAY quietly: any line
## then would drop it) or being said, and never cuts one.
func test_prompt_never_cuts_the_answer() -> bool:
	VoiceTurns.reset()
	var t0 := 100000
	VoiceTurns.numbers_said(t0, 1.0, 1.6)   # a wrong stone: say_answer
	eq(VoiceTurns.decide("prompt", 0.5, t0 + 500, false, false), "wait", "quiet before the answer: wait")
	eq(VoiceTurns.decide("teach", 0.5, t0 + 1100, false, false), "wait", "the answer is due: even a taught line waits")
	eq(VoiceTurns.decide("prompt", 1.4, t0 + 1400, true, false), "wait", "the answer playing: wait")
	eq(VoiceTurns.decide("teach", 9.0, t0 + 1400, true, false), "wait", "a taught line never cuts the answer")
	eq(VoiceTurns.decide("prompt", 3.0, t0 + 3000, false, false), "play", "after it: the prompt")
	# a prompt that would come far too late is left out, not stacked up
	VoiceTurns.reset()
	VoiceTurns.numbers_said(t0, 1.0, 1.6)
	eq(VoiceTurns.decide("prompt", VoiceTurns.PROMPT_WAIT_S + 0.1, t0 + 1500, true, false), "skip", "too late")
	VoiceTurns.reset()
	return true


func test_count_on_holds_everyone() -> bool:
	VoiceTurns.reset()
	var t0 := 200000
	VoiceTurns.numbers_said(t0, 1.0, 2.0)
	eq(VoiceTurns.decide("event", 1.0, t0 + 6000, false, true), "wait", "counting")
	# the count just ended but its last number still rings
	eq(VoiceTurns.decide("event", 1.0, t0 + 6100, true, false), "wait", "the last number's tail")
	eq(VoiceTurns.decide("event", 1.0, t0 + 6100 + int(VoiceTurns.COUNT_TAIL_S * 1000.0) + 10, false, false), "play", "then free")
	VoiceTurns.reset()
	return true


## Prompts and event lines never cut a cheer either; a taught line waits a
## while, then may (never a number).
func test_lines_wait_their_turn() -> bool:
	VoiceTurns.reset()
	var t := 300000
	eq(VoiceTurns.decide("prompt", 0.1, t, false, false), "play", "free: play")
	eq(VoiceTurns.decide("prompt", 1.0, t, true, false), "wait", "she is talking: wait")
	eq(VoiceTurns.decide("event", VoiceTurns.EVENT_WAIT_S + 0.1, t, true, false), "skip", "event too late")
	eq(VoiceTurns.decide("prompt", VoiceTurns.PROMPT_WAIT_S + 0.1, t, true, false), "skip", "prompt never cuts")
	eq(VoiceTurns.decide("teach", 1.0, t, true, false), "wait", "taught line waits")
	eq(VoiceTurns.decide("teach", VoiceTurns.TEACH_WAIT_S + 0.1, t, true, false), "play", "then speaks over a cheer")
	# a pip count (no delay) holds lines only while it rings
	VoiceTurns.numbers_said(t, 0.0, 0.9)
	eq(VoiceTurns.decide("teach", 9.0, t + 300, true, false), "wait", "pip count ringing")
	eq(VoiceTurns.decide("teach", 0.1, t + 300, false, false), "play", "pip count done early")
	VoiceTurns.reset()
	return true
