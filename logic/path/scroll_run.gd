## One run along a scroll area: a row of spaces crossed left to right, with
## chests and monsters on some of them. Spec: spec/logic-spec.md section 6.
## Reference: tools/ref/scroll_run.py. No timers and no nodes: the game calls
## roll/choose/resolve_fight on input and animates the returned outcome.
extends RefCounted

const Rng := preload("res://logic/core/rng.gd")
const MoveGen := preload("res://logic/core/move_gen.gd")
const LevelGen := preload("res://logic/core/level_gen.gd")

const AWAIT_ROLL := "await_roll"
const AWAIT_CHOICE := "await_choice"
const AWAIT_FIGHT := "await_fight"
const CLEARED := "cleared"
## The hero's hearts on the crossing: 3 lives (Terrence, 2026-11-07). A wrong
## stone costs one and the same guess is rolled again; the last one lost starts
## the crossing over. They carry into each fight and back out of it; a heart
## space adds one, up to MAX_HEARTS. A restart gives the 3 back.
const HERO_HEARTS := 3
const MAX_HEARTS := 5

var area: Dictionary
var grade: Dictionary
var run_seed: int
var rng: Rng
var attempt := 1
var pos := 0
var target := 0   # where the current walk ends; > pos while a fight on the way is pending
var looted := []  # chest spaces already opened; they stay empty after a restart
var gems := 0
var hearts := HERO_HEARTS
var hearts_taken := []  # heart spaces (by step) picked up this attempt; back after a restart
var rolls := 0    # rolls this attempt (the area's "rolls" [min, max] bounds a clean run)
## An area with "guesses" (Terrence 2026-11-07: a run is 9 guesses) draws this
## attempt's right answers up front, one per guess; the crossing is as long as
## their sum and its "steps" land on the spaces those answers reach.
var answers := []
var _length := 0
var problem := {}
var phase := AWAIT_ROLL
var events := []
var _spaces := {}


func _init(area_data: Dictionary, grade_data: Dictionary, seed_value: int) -> void:
	area = area_data
	grade = grade_data
	run_seed = seed_value & Rng.MASK
	rng = Rng.new(run_seed)
	if is_guessed():
		_new_answers()
	else:
		_length = int(area["length"])
		for s in area["spaces"]:
			_spaces[int(s["at"])] = s


## True for an area whose length comes from its guesses.
func is_guessed() -> bool:
	return area.has("guesses")


## Draws a fresh set of answers (one rng draw each, 1..max_answer) and lays
## the crossing out from them: step n sits on the space the first n answers reach.
func _new_answers() -> void:
	answers = []
	var top: int = grade["move"]["max_answer"]
	for k in int(area["guesses"]):
		if is_level():
			answers.append(LevelGen.draw_answer(stage(k)["move"], rng))
		else:
			answers.append(rng.randi_range(1, top))
	_lay_out()


## A level after Lava 1 (content/levels.json): generator v1.2 draws its rolls.
func is_level() -> bool:
	return grade.get("move", {}).get("draw", "op_first") != "op_first"


## The ramp stage for guess k (0 = the first): a level with "ramp" (the
## Crystal Mines, 2026-11-12) steps its math up along the crossing, each
## stage {guesses, move, fight, rails} covering that many guesses; the last
## stage runs to the end. A level without one is a single stage.
func stage(k: int) -> Dictionary:
	var r: Array = grade.get("ramp", [])
	if r.is_empty():
		return {"move": grade.get("move", {}), "fight": grade.get("fight", {"grade": grade["id"], "top": 0}),
				"rails": bool(grade.get("rails", false))}
	var left := k
	for s in r:
		if left < int(s["guesses"]):
			return s
		left -= int(s["guesses"])
	return r[r.size() - 1]


## The stage of the guess being rolled now (or the next one to roll).
func stage_now() -> Dictionary:
	var k := rolls - 1 if phase == AWAIT_CHOICE else rolls
	return stage(maxi(0, k))


## The most stones the current guess can offer.
func max_answer_now() -> int:
	return int(stage_now()["move"]["max_answer"])


## The fight for a monster met now: the stage of the guess that walked
## into it.
func fight_now() -> Dictionary:
	return stage(maxi(0, rolls - 1))["fight"]


func _lay_out() -> void:
	_spaces = {}
	var at := 0
	var landing := {}
	for k in answers.size():
		at += int(answers[k])
		landing[k + 1] = at
	_length = at
	for st in area.get("steps", []):
		var n := int(st["after"])
		if landing.has(n) and n < answers.size():
			var sp: Dictionary = st.duplicate()
			sp["at"] = landing[n]
			_spaces[int(landing[n])] = sp


# --- save and resume -------------------------------------------------------

func to_save() -> Dictionary:
	var d := {
		"area": area["id"],
		"grade": grade["id"],
		"seed": run_seed,
		"attempt": attempt,
		"pos": pos,
		"target": target,
		"looted": looted.duplicate(),
		"gems": gems,
		"hearts": hearts,
		"hearts_taken": hearts_taken.duplicate(),
		"rolls": rolls,
		"phase": phase,
		"rng_state": rng.get_state(),
	}
	if is_guessed():
		d["answers"] = answers.duplicate()
	return d


## A run saved mid-choice resumes at the roll; the same rng state rolls the
## same problem again.
func restore(data: Dictionary) -> void:
	attempt = data["attempt"]
	pos = data["pos"]
	target = maxi(pos, int(data.get("target", pos)))
	looted = data["looted"].duplicate()
	gems = data["gems"]
	hearts = clampi(int(data.get("hearts", HERO_HEARTS)), 1, MAX_HEARTS)
	hearts_taken = data.get("hearts_taken", []).duplicate()
	rolls = int(data.get("rolls", 0))
	if data["phase"] == AWAIT_CHOICE:
		rolls = maxi(0, rolls - 1)  # that roll is rolled again
	phase = AWAIT_ROLL if data["phase"] == AWAIT_CHOICE else data["phase"]
	rng.set_state(data["rng_state"])
	if is_guessed():
		if data.has("answers"):
			answers = data["answers"].duplicate()
			_lay_out()
		else:
			# a save from before the guesses (fixed 40 stones): a fresh
			# crossing from the start, gems and attempt kept
			pos = 0
			target = 0
			rolls = 0
			looted = []
			hearts = HERO_HEARTS
			hearts_taken = []
			problem = {}
			phase = AWAIT_ROLL
			_new_answers()


# --- queries ---------------------------------------------------------------

func length() -> int:
	return _length


## A heart space already picked up this attempt.
func is_heart_taken(i: int) -> bool:
	return hearts_taken.has(_loot_key(i))


## A chest space already opened. With guesses a chest is known by its step,
## so it stays empty when a restart lays out a new crossing.
func is_looted(i: int) -> bool:
	return looted.has(_loot_key(i))


func _loot_key(i: int) -> int:
	return int(space_at(i).get("after", i))


## The space's entry from the area file, or {} for a plain rock.
func space_at(i: int) -> Dictionary:
	return _spaces.get(i, {})


func has_problem() -> bool:
	return not problem.is_empty()


func current_monster() -> String:
	if phase != AWAIT_FIGHT:
		return ""
	return str(space_at(pos).get("monster", ""))


# --- inputs ----------------------------------------------------------------

func roll() -> Dictionary:
	assert(phase == AWAIT_ROLL)
	var b := answer_bounds()
	if is_guessed():
		var a: int = answers[mini(rolls, answers.size() - 1)]
		b = [a, a]
	if is_level():
		var st := stage(rolls)
		var m := mini(int(st["move"]["max_answer"]), length() - pos)
		var lv := grade
		if grade.has("ramp"):
			lv = grade.duplicate()
			lv["move"] = st["move"]
		problem = LevelGen.generate_for(lv, rng, b[0], m)
	else:
		problem = MoveGen.generate_move(grade, rng, length() - pos, b[0], b[1])
	rolls += 1
	phase = AWAIT_CHOICE
	return problem


## The answers this roll may have so a clean crossing takes the area's
## "rolls" [min, max] (Terrence 2026-11-07: 10 to 12): never so short that
## the goal comes before the min-th roll, never so long that the goal is out
## of reach by the max-th. [1, 0] (no limit) when the area sets none.
func answer_bounds() -> Array:
	if not area.has("rolls"):
		return [1, 0]
	var lo_rolls: int = area["rolls"][0]
	var hi_rolls: int = area["rolls"][1]
	var top: int = grade["move"]["max_answer"]
	var room := length() - pos
	var left := hi_rolls - rolls - 1        # rolls after this one, at most
	var lo := maxi(1, room - top * left)
	var hi := mini(top, room - maxi(0, lo_rolls - rolls - 1))
	return [lo, maxi(lo, hi)]


## A wrong space costs a heart: the hero hops back ("miss") and the same
## guess is rolled again with new dice. With no hearts left it sinks ("sink")
## and the run starts again from space 0. A right one
## walks there space by space, and everything walked onto triggers: an
## unopened chest gives gems on the way, a monster stops the walk for a fight
## (the rest of the walk follows a win), the last space clears the area.
func choose(index: int) -> Dictionary:
	assert(phase == AWAIT_CHOICE)
	assert(index >= 0 and index < problem["choices"].size())
	var dist: int = problem["choices"][index]
	var right: bool = index == problem["answer_index"]
	var out := {"result": "", "right": right, "pick": index, "from": pos, "to": pos + dist, "restarted": false}
	if not right:
		hearts -= 1
		if hearts > 0:
			out["result"] = "miss"
			_log(out)
			rolls = maxi(0, rolls - 1)  # this guess again
			problem = {}
			phase = AWAIT_ROLL
			out["hearts_left"] = hearts
			return out
		out["result"] = "sink"
		_log(out)
		_fail()
		out["restarted"] = true
		return out
	target = pos + dist
	_walk(out)
	_log(out)
	problem = {}
	return out


## The fight layer reports the result. A lost fight restarts like a sink. A
## won fight met on the way finishes the walk: its outcome is under "walk".
## hearts_left: the hero's hearts when the fight ended (-1 = unchanged); they
## carry on along the crossing.
func resolve_fight(won: bool, hearts_left := -1) -> Dictionary:
	assert(phase == AWAIT_FIGHT)
	var out := {"result": "fight_won" if won else "fight_lost", "restarted": false}
	_log(out)
	if not won:
		_fail()
		out["restarted"] = true
		return out
	if hearts_left > 0:
		hearts = mini(hearts_left, MAX_HEARTS)
	phase = AWAIT_ROLL
	if target > pos:
		var w := {"result": "", "from": pos, "to": target}
		_walk(w)
		_log(w)
		out["walk"] = w
	return out


# --- internals -------------------------------------------------------------

## Steps from pos toward target. Fills out: result (where it stopped: goal,
## monster, chest, heart or hop), to (that space), chests ([{at, gems}] opened
## on the way, in order), gems (their total, when any) and hearts (the heart
## spaces picked up on the way).
func _walk(out: Dictionary) -> void:
	var chests := []
	var got_hearts := []
	var total := 0
	phase = AWAIT_ROLL
	out["result"] = "hop"
	while pos < target:
		pos += 1
		var space := space_at(pos)
		if pos >= length():
			out["result"] = "goal"
			phase = CLEARED
			break
		if space.get("type") == "monster":
			out["result"] = "monster"
			out["monster"] = space["monster"]
			phase = AWAIT_FIGHT
			break
		if space.get("type") == "chest" and not is_looted(pos):
			var g := chest_draw(area["chest_gems"], rng)
			looted.append(_loot_key(pos))
			gems += g
			total += g
			chests.append({"at": pos, "gems": g})
			if pos == target:
				out["result"] = "chest"
		if space.get("type") == "heart" and not is_heart_taken(pos):
			hearts_taken.append(_loot_key(pos))
			hearts = mini(hearts + 1, MAX_HEARTS)
			got_hearts.append(pos)
			if pos == target:
				out["result"] = "heart"
	if phase != AWAIT_FIGHT:
		target = pos
	out["to"] = pos
	out["chests"] = chests
	out["hearts"] = got_hearts
	if not chests.is_empty():
		out["gems"] = total


## One chest's gems (2026-11-06, Terrence: "normally 1, rare 2"): one draw.
## {common, rare, rare_in}: rare when randi_range(1, rare_in) == rare_in.
## An [lo, hi] pair (the old form) draws randi_range(lo, hi).
static func chest_draw(cfg, r: Rng) -> int:
	if cfg is Array:
		return r.randi_range(int(cfg[0]), int(cfg[1]))
	var n := int(cfg["rare_in"])
	return int(cfg["rare"]) if r.randi_range(1, n) == n else int(cfg["common"])


## The fewest and most gems one chest can give.
static func chest_range(cfg) -> Array:
	if cfg is Array:
		return [int(cfg[0]), int(cfg[1])]
	return [mini(int(cfg["common"]), int(cfg["rare"])), maxi(int(cfg["common"]), int(cfg["rare"]))]


## The average gems of one chest.
static func chest_mean(cfg) -> float:
	if cfg is Array:
		return (float(cfg[0]) + float(cfg[1])) / 2.0
	var n := float(cfg["rare_in"])
	return (float(cfg["common"]) * (n - 1.0) + float(cfg["rare"])) / n


func _fail() -> void:
	attempt += 1
	rolls = 0
	pos = 0
	target = 0
	hearts = HERO_HEARTS
	hearts_taken = []
	problem = {}
	phase = AWAIT_ROLL
	if is_guessed():
		_new_answers()


func _log(out: Dictionary) -> void:
	var e := {"attempt": attempt, "pos": pos, "result": out["result"]}
	if has_problem():
		e["op"] = problem["op"]
		e["dice"] = problem["dice"].duplicate()
		e["pick"] = out["pick"]
	if out.has("gems"):
		e["gems"] = out["gems"]
	events.append(e)
