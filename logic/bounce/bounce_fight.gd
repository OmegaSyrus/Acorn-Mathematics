extends RefCounted
## One Match Bounce boss fight: shots until the boss is out of hearts (WON)
## or the child is out of balls (LOST, the fail screen with Try and Map).
## Pure logic, all randomness from the injected SeededRng, no timers.
##
##   NAMING --name_peg()--> AIMING --fire()--> FLYING --end_shot()--> NAMING ...
##                                                               \--> WON / LOST
##
## Each shot: the boss rolls its target (and the ball its die, above Acorn),
## the child names the peg face that completes it, aims, and fires. A wrong
## name is not a lost turn of aiming: the ball still flies, but every peg is
## a ghost and the boss laughs. The ball is spent either way.

const BounceSim = preload("res://logic/bounce/bounce_sim.gd")
const BounceRules = preload("res://logic/bounce/bounce_rules.gd")
const JsonUtil = preload("res://logic/core/json_util.gd")

enum State { NAMING, AIMING, FLYING, WON, LOST }

const TUNING_PATH := "res://content/bounce/tuning.json"
const BOARD_DIR := "res://content/bounce/boards/"

var rng
var grade: int
var phys: Dictionary
var cfg: Dictionary
var board: Dictionary
var rule: String

var state: int = State.NAMING
var boss_hearts: int
var boss_max_hearts: int
var balls_left: int
var peg_alive: Array[bool] = []
## How many times the board was filled again because too few pegs were left.
var refills := 0

## This shot.
var target := 0
var ball_value := 0
var answer_face := 0
var choices: Array[int] = []
var named_face := 0
var named_right := false
var aim := 0
var sim
var shot_count := 0
var total_pops := 0


static func load_tuning() -> Dictionary:
	return JsonUtil.load_file(TUNING_PATH)


static func load_board(id: String) -> Dictionary:
	return JsonUtil.load_file(BOARD_DIR + id + ".json")


## tuning and p_board default to the content files; tests pass their own.
func _init(p_rng, p_grade: int, tuning := {}, p_board := {}) -> void:
	rng = p_rng
	grade = p_grade
	if tuning.is_empty():
		tuning = load_tuning()
	phys = tuning["physics"]
	cfg = tuning["grades"][str(grade)]
	rule = cfg["rule"]
	board = p_board if not p_board.is_empty() else load_board(cfg["board"])
	boss_max_hearts = cfg["boss_hearts"]
	boss_hearts = boss_max_hearts
	balls_left = cfg["balls"]
	_fill_board()
	_new_shot()


func _fill_board() -> void:
	peg_alive.clear()
	for p in board["pegs"]:
		peg_alive.append(true)


## Faces on the board in its JSON (all of them, popped or not), smallest first.
func board_faces() -> Array:
	var faces := []
	for p in board["pegs"]:
		if not faces.has(int(p["face"])):
			faces.append(int(p["face"]))
	faces.sort()
	return faces


func pegs_left(face: int) -> int:
	var n := 0
	for i in board["pegs"].size():
		if peg_alive[i] and int(board["pegs"][i]["face"]) == face:
			n += 1
	return n


## Faces that can be the answer: enough pegs left, and the rule can reach it.
func _eligible_faces() -> Array:
	var out := []
	for f in board_faces():
		if pegs_left(f) < int(cfg["min_live"]):
			continue
		if rule == "difference" and f > 5:
			continue
		out.append(f)
	return out


## Draw order (spec): refill if needed, the needed face, the ball die, then
## the choice shuffle.
func _new_shot() -> void:
	var faces := _eligible_faces()
	if faces.is_empty():
		_fill_board()
		refills += 1
		faces = _eligible_faces()
	answer_face = faces[rng.randi_range(0, faces.size() - 1)]
	var bt: Array = BounceRules.roll_shot(rng, rule, answer_face)
	ball_value = bt[0]
	target = bt[1]
	choices = BounceRules.choices(rng, rule, answer_face, ball_value, int(cfg["choices"]), board_faces())
	named_face = 0
	named_right = false
	sim = null
	state = State.NAMING


## The child taps choice `index`. Returns true if it was the right face.
func name_peg(index: int) -> bool:
	assert(state == State.NAMING, "BounceFight.name_peg: not naming")
	named_face = choices[index]
	named_right = named_face == answer_face
	state = State.AIMING
	return named_right


func live_count() -> int:
	var n := 0
	for i in board["pegs"].size():
		if peg_alive[i] and named_right and BounceRules.peg_matches(rule, int(board["pegs"][i]["face"]), ball_value, target):
			n += 1
	return n


## Builds the flight without starting the shot: for the screen's aim
## preview tests and for bots that try angles.
func preview_sim(aim_decideg: int):
	return BounceSim.new(phys, board, peg_alive, rule, target, ball_value, named_right, aim_decideg)


## Fires. Returns the sim; the game steps it (or calls run()) and then calls
## end_shot().
func fire(aim_decideg: int):
	assert(state == State.AIMING, "BounceFight.fire: not aiming")
	aim = BounceSim.clamp_aim(aim_decideg, phys)
	sim = preview_sim(aim)
	state = State.FLYING
	return sim


## True when the damage so far in this shot takes the boss's last heart.
func is_lethal() -> bool:
	return sim != null and sim.damage >= boss_hearts


## Applies the finished shot. Returns {pops, damage, boss_hearts, balls_left, state}.
func end_shot() -> Dictionary:
	assert(state == State.FLYING and sim != null and sim.ended != BounceSim.End.NONE)
	shot_count += 1
	balls_left -= 1
	total_pops += sim.popped.size()
	peg_alive.assign(sim.peg_alive)
	boss_hearts = maxi(0, boss_hearts - sim.damage)
	var out := {
		"pops": sim.popped.size(),
		"damage": sim.damage,
		"boss_hearts": boss_hearts,
		"balls_left": balls_left,
	}
	if boss_hearts <= 0:
		state = State.WON
	elif balls_left <= 0:
		state = State.LOST
	else:
		_new_shot()
	out["state"] = state
	return out


func is_over() -> bool:
	return state == State.WON or state == State.LOST
