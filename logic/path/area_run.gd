## One run through an area: the task sequence, the fail rule and save state.
## Spec: spec/logic-spec.md. Reference: tools/ref/area_run.py.
## No timers and no nodes: the game calls decide_chest/roll/choose on input
## and animates the returned outcome.
extends RefCounted

const Rng := preload("res://logic/core/rng.gd")
const ProblemGen := preload("res://logic/core/problem_gen.gd")

const AWAIT_CHEST := "await_chest"
const AWAIT_ROLL := "await_roll"
const AWAIT_CHOICE := "await_choice"
const AWAIT_FIGHT := "await_fight"
const CLEARED := "cleared"

var area: Dictionary
var grade: Dictionary
var stickers: Array
var run_seed: int
var rng: Rng
var attempt := 1
var task_index := 0
var problem := {}
var phase := ""
var events := []


func _init(area_data: Dictionary, grade_data: Dictionary, sticker_ids: Array, seed_value: int) -> void:
	area = area_data
	grade = grade_data
	stickers = sticker_ids
	run_seed = seed_value & Rng.MASK
	rng = Rng.new(run_seed)
	_enter_task()


# --- save and resume -------------------------------------------------------

## Written after every task. Mid-task input isn't saved: a resumed run starts
## the same task again, and the same rng state gives the same problem.
func to_save() -> Dictionary:
	return {
		"area": area["id"],
		"grade": grade["id"],
		"seed": run_seed,
		"attempt": attempt,
		"task_index": task_index,
		"rng_state": rng.get_state(),
	}


func restore(data: Dictionary) -> void:
	attempt = data["attempt"]
	task_index = data["task_index"]
	rng.set_state(data["rng_state"])
	_enter_task()


# --- queries ---------------------------------------------------------------

func task_count() -> int:
	return area["tasks"].size()


func current_task() -> Dictionary:
	if task_index >= task_count():
		return {}
	return area["tasks"][task_index]


func has_problem() -> bool:
	return not problem.is_empty()


## The monster for the fight in progress: a fight task's "monster" id, or
## "mimic" when a mimic chest has snapped open. Empty when not fighting.
func current_monster() -> String:
	if phase != AWAIT_FIGHT:
		return ""
	var task := current_task()
	return "mimic" if task["type"] == "chest" else str(task.get("monster", ""))


# --- inputs ----------------------------------------------------------------

## A chest is optional: open_it false walks past it.
func decide_chest(open_it: bool) -> Dictionary:
	assert(phase == AWAIT_CHEST)
	if open_it:
		phase = AWAIT_ROLL
		return {"result": "chest_try"}
	var out := {"result": "walk_past"}
	_log(out)
	_complete(out)
	return out


func roll() -> Dictionary:
	assert(phase == AWAIT_ROLL)
	problem = ProblemGen.generate(current_task()["type"], grade, rng)
	phase = AWAIT_CHOICE
	return problem


func choose(index: int) -> Dictionary:
	assert(phase == AWAIT_CHOICE)
	assert(index >= 0 and index < problem["choices"].size())
	var right: bool = index == problem["answer_index"]
	var kind: String = problem["kind"]
	var out := {"result": "", "right": right, "pick": index}
	if kind == "chest" and current_task().get("mimic", false):
		# A mimic is set when the area is built. Right or wrong, its lid snaps
		# open and a real fight starts; a right answer earns the first strike.
		out["result"] = "mimic"
		out["first_strike"] = right
		_log(out)
		problem = {}
		phase = AWAIT_FIGHT
		out["cleared"] = false
		out["restarted"] = false
	elif kind == "chest":
		if right:
			out["result"] = "chest_open"
			out["sticker"] = stickers[rng.randi_range(0, stickers.size() - 1)]
		else:
			out["result"] = "chest_shut"
		_log(out)
		_complete(out)
	elif right:
		out["result"] = "door_open" if kind == "door" else "hop"
		_log(out)
		_complete(out)
	else:
		out["result"] = "trap" if kind == "door" else "fall"
		_log(out)
		_fail(out)
	return out


## For fight tasks and mimics: the fight layer reports the result. A lost
## fight restarts the area like any fail.
func resolve_fight(won: bool) -> Dictionary:
	assert(phase == AWAIT_FIGHT)
	var out := {"result": "fight_won" if won else "fight_lost"}
	_log(out)
	if won:
		_complete(out)
	else:
		_fail(out)
	return out


# --- internals -------------------------------------------------------------

func _enter_task() -> void:
	problem = {}
	var task := current_task()
	if task.is_empty():
		phase = CLEARED
	elif task["type"] == "chest":
		phase = AWAIT_CHEST
	elif task["type"] == "fight":
		phase = AWAIT_FIGHT
	else:
		phase = AWAIT_ROLL


func _complete(out: Dictionary) -> void:
	task_index += 1
	_enter_task()
	out["cleared"] = phase == CLEARED
	out["restarted"] = false


## The fail rule: back to the area's first task. The rng stream carries on,
## so the restarted area gets fresh problems.
func _fail(out: Dictionary) -> void:
	attempt += 1
	task_index = 0
	_enter_task()
	out["cleared"] = false
	out["restarted"] = true


func _log(out: Dictionary) -> void:
	var e := {
		"attempt": attempt,
		"task": task_index,
		"type": current_task()["type"],
		"result": out["result"],
	}
	if has_problem():
		e["dice"] = problem["dice"].duplicate()
		e["choices"] = problem["choices"].duplicate()
		e["pick"] = out["pick"]
	if out.has("sticker"):
		e["sticker"] = out["sticker"]
	events.append(e)
