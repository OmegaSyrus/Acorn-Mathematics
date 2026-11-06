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
var target := 0   # where the current walk ends; > pos while a fight on the way is pending
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
		"target": target,
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
	target = maxi(pos, int(data.get("target", pos)))
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
func resolve_fight(won: bool) -> Dictionary:
	assert(phase == AWAIT_FIGHT)
	var out := {"result": "fight_won" if won else "fight_lost", "restarted": false}
	_log(out)
	if not won:
		_fail()
		out["restarted"] = true
		return out
	phase = AWAIT_ROLL
	if target > pos:
		var w := {"result": "", "from": pos, "to": target}
		_walk(w)
		_log(w)
		out["walk"] = w
	return out


# --- internals -------------------------------------------------------------

## Steps from pos toward target. Fills out: result (where it stopped: goal,
## monster, chest or hop), to (that space), chests ([{at, gems}] opened on the
## way, in order) and gems (their total, when any).
func _walk(out: Dictionary) -> void:
	var chests := []
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
		if space.get("type") == "chest" and not looted.has(pos):
			var g := chest_draw(area["chest_gems"], rng)
			looted.append(pos)
			gems += g
			total += g
			chests.append({"at": pos, "gems": g})
			if pos == target:
				out["result"] = "chest"
	if phase != AWAIT_FIGHT:
		target = pos
	out["to"] = pos
	out["chests"] = chests
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
	pos = 0
	target = 0
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
