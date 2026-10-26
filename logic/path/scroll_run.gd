## One run along a scroll area: a row of spaces crossed left to right, with
## chests and monsters on some of them. Spec: spec/logic-spec.md section 6.
## Reference: tools/ref/scroll_run.py. No timers and no nodes: the game calls
## roll/choose/resolve_fight on input and animates the returned outcome.
extends RefCounted

const Rng := preload("res://logic/core/rng.gd")
const MoveGen := preload("res://logic/core/move_gen.gd")

const AWAIT_ROLL := "await_roll"
const AWAIT_CHOICE := "await_choice"
const AWAIT_FIGHT := "await_fight"
const CLEARED := "cleared"

var area: Dictionary
var grade: Dictionary
var run_seed: int
var rng: Rng
var attempt := 1
var pos := 0
var looted := []  # chest spaces already opened; they stay empty after a restart
var gems := 0
var problem := {}
var phase := AWAIT_ROLL
var events := []
var _spaces := {}


func _init(area_data: Dictionary, grade_data: Dictionary, seed_value: int) -> void:
	area = area_data
	grade = grade_data
	run_seed = seed_value & Rng.MASK
	rng = Rng.new(run_seed)
	for s in area["spaces"]:
		_spaces[int(s["at"])] = s


# --- save and resume -------------------------------------------------------

func to_save() -> Dictionary:
	return {
		"area": area["id"],
		"grade": grade["id"],
		"seed": run_seed,
		"attempt": attempt,
		"pos": pos,
		"looted": looted.duplicate(),
		"gems": gems,
		"phase": phase,
		"rng_state": rng.get_state(),
	}


## A run saved mid-choice resumes at the roll; the same rng state rolls the
## same problem again.
func restore(data: Dictionary) -> void:
	attempt = data["attempt"]
	pos = data["pos"]
	looted = data["looted"].duplicate()
	gems = data["gems"]
	phase = AWAIT_ROLL if data["phase"] == AWAIT_CHOICE else data["phase"]
	rng.set_state(data["rng_state"])


# --- queries ---------------------------------------------------------------

func length() -> int:
	return area["length"]


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
	problem = MoveGen.generate_move(grade, rng, length() - pos)
	phase = AWAIT_CHOICE
	return problem


## A wrong space sinks and the run starts again from space 0. A right one
## moves there and resolves it: a monster starts a fight, an unopened chest
## gives gems, the last space clears the area.
func choose(index: int) -> Dictionary:
	assert(phase == AWAIT_CHOICE)
	assert(index >= 0 and index < problem["choices"].size())
	var dist: int = problem["choices"][index]
	var right: bool = index == problem["answer_index"]
	var out := {"result": "", "right": right, "pick": index, "from": pos, "to": pos + dist, "restarted": false}
	if not right:
		out["result"] = "sink"
		_log(out)
		_fail()
		out["restarted"] = true
		return out
	pos += dist
	var space := space_at(pos)
	phase = AWAIT_ROLL
	if pos >= length():
		out["result"] = "goal"
		phase = CLEARED
	elif space.get("type") == "monster":
		out["result"] = "monster"
		out["monster"] = space["monster"]
		phase = AWAIT_FIGHT
	elif space.get("type") == "chest" and not looted.has(pos):
		var range_: Array = area["chest_gems"]
		out["result"] = "chest"
		out["gems"] = rng.randi_range(range_[0], range_[1])
		looted.append(pos)
		gems += out["gems"]
	else:
		out["result"] = "hop"
	_log(out)
	problem = {}
	return out


## The fight layer reports the result. A lost fight restarts like a sink.
func resolve_fight(won: bool) -> Dictionary:
	assert(phase == AWAIT_FIGHT)
	var out := {"result": "fight_won" if won else "fight_lost", "restarted": false}
	_log(out)
	if won:
		phase = AWAIT_ROLL
	else:
		_fail()
		out["restarted"] = true
	return out


# --- internals -------------------------------------------------------------

func _fail() -> void:
	attempt += 1
	pos = 0
	problem = {}
	phase = AWAIT_ROLL


func _log(out: Dictionary) -> void:
	var e := {"attempt": attempt, "pos": pos, "result": out["result"]}
	if has_problem():
		e["op"] = problem["op"]
		e["dice"] = problem["dice"].duplicate()
		e["pick"] = out["pick"]
	if out.has("gems"):
		e["gems"] = out["gems"]
	events.append(e)
