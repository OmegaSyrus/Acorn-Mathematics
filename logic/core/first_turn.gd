## The taught first turn and the first-time math lines (Phase 3, 2026-11-28).
## Pure logic, no nodes: game/ui/tutor.gd draws the hand and says the lines
## through Ellwynn; the crossing and the fights say when a step starts and
## when the child has done it.
##
## A taught step (T2 Roll, T3 count the dots, T4 pick a stone, T5 Go, T9
## pick a shield, T10 shield bash, T12 the door, T13 the duel) shows its hint
## until the child does the step, plays its line once (Ellwynn.teach), and
## if the child does nothing for IDLE_REPLAY_S after the line, says it once
## more. A child who does the step before the line is said is taught too:
## the step is marked, so it never comes back. A child already taught gets
## no hint and no line: the game plays exactly as before.
extends RefCounted

## No tap for this long after the line ends: she says the step once more.
const IDLE_REPLAY_S := 8.0
## T3 (count the dots) needs no tap: once the line is said and she is quiet
## this long, the next step (the stones) starts.
const T3_MOVE_ON_S := 2.5

## The first crossing, in the order a new child meets it.
const FIRST_TURN := ["T1", "T2", "T3", "T4", "T5", "T6"]
## Steps that wait for the child (a hint shows until they are done); the
## other T lines are said once at their moment.
const HINTED := ["T2", "T3", "T4", "T5", "T9", "T10", "T12", "T13"]

## World order (content/worlds.json): W1..W5 world arrival, D1..D5 the
## miniboss intro.
const WORLD_ORDER := ["lava_caves", "crystal_mines", "bog", "mushroom_forest", "space"]

## The level's "new" (content/levels.json) for the first-time lines that are
## about the level as a whole, not something seen in one roll.
const NEW_CUES := {"top": "N2", "ten": "N10", "mix": "N11"}

## Is a step being taught now ("" none), and has its line been said.
var current := ""
var said := false
var idle := 0.0
var replayed := false
var auto_s := -1.0
## id -> bool: true once this child has been taught that cue.
var _is_taught: Callable


func _init(is_taught: Callable) -> void:
	_is_taught = is_taught


func taught(id: String) -> bool:
	return bool(_is_taught.call(id))


## A step starts. True when it is taught now (the hint shows), false when
## this child already knows it (or another step is still being taught).
## auto_after: the step ends by itself this long after its line (T3).
func begin(id: String, auto_after := -1.0) -> bool:
	if taught(id):
		return false
	current = id
	said = false
	idle = 0.0
	replayed = false
	auto_s = auto_after
	return true


func is_on(id: String) -> bool:
	return current != "" and current == id


## Its line was just said.
func line_said(id: String) -> void:
	if is_on(id):
		said = true
		idle = 0.0


## The child did the step: true when it was the step being taught (the
## caller marks it taught and the hint goes).
func finish(id: String) -> bool:
	if not is_on(id):
		return false
	current = ""
	said = false
	return true


## Time passes. talking: Ellwynn is talking (the wait only counts once she
## is quiet). Returns "replay" once when the child has done nothing for
## IDLE_REPLAY_S after the line, "done" when an auto step is over, else "".
func tick(dt: float, talking: bool) -> String:
	if current == "" or not said or talking:
		return ""
	idle += dt
	if auto_s >= 0.0 and idle >= auto_s:
		return "done"
	if not replayed and idle >= IDLE_REPLAY_S:
		replayed = true
		idle = 0.0
		return "replay"
	return ""


# --- which line, from the content ------------------------------------------

## "W1".."W5" by world order (a world not listed is Lava's).
static func world_cue(prefix: String, world_id: String) -> String:
	var i := WORLD_ORDER.find(world_id)
	return "%s%d" % [prefix, (i if i >= 0 else 0) + 1]


## True on the first roll of the level's own math after its warm-up.
static func warmup_done(stage_before: Dictionary, stage_now: Dictionary) -> bool:
	return bool(stage_before.get("warmup", false)) and not bool(stage_now.get("warmup", false))


## The first-time math lines a rolled problem shows, most specific first
## (the level's own "new" leads): the crossing teaches the first one this
## child hasn't had. problem is ScrollRun.roll()'s, stage its ramp stage,
## level the level (content/levels.json, with "new"). Warm-up rolls ask the
## step before's math, so they only bring what the child has already seen
## (unless a grown-up skipped ahead, when it is new to them too).
static func new_math_cues(problem: Dictionary, stage: Dictionary, level: Dictionary) -> Array:
	var found := []
	var dice: Array = problem.get("dice", [])
	var n := dice.size()
	var signs := String(problem.get("signs", ""))
	if signs == "" and n > 0:
		signs = "+" + ("-" if problem.get("op", "add") == "sub" else "+").repeat(n - 1)
	var hidden := int(problem.get("hidden", -1))
	var own := not bool(stage.get("warmup", false))
	if hidden >= 0 and hidden != n - 1:
		found.append("N9")   # the hidden die can be any of them
	if hidden >= 0:
		found.append("N8")
	if bool(stage.get("track", false)):
		found.append("N5")
	if bool(stage.get("rails", false)):
		found.append("N6")
	if own and NEW_CUES.has(String(level.get("new", ""))):
		found.append(NEW_CUES[String(level.get("new", ""))])
	if n >= 4:
		found.append("N7")
	if n == 3:
		found.append("N4")
	if "-" in signs:
		found.append("N3")
	if n == 2:
		found.append("N1")
	# the level's own new thing first, when this roll shows it
	var lead := level_cue(level)
	if own and lead != "" and found.has(lead):
		found.erase(lead)
		found.push_front(lead)
	return found


## The first-time line for what a level adds (its "new"): two, three or
## four dice, the take-away, the track, the rails, the hidden die ...
## "" for Lava 1 ("start").
static func level_cue(level: Dictionary) -> String:
	var new := String(level.get("new", ""))
	match new:
		"die":
			match dice_count(level.get("move", {})):
				2:
					return "N1"
				3:
					return "N4"
				4:
					return "N7"
			return ""
		"take_away":
			return "N3"
		"track":
			return "N5"
		"rails":
			return "N6"
		"hidden":
			return "N8"
		"place":
			return "N9"
	return String(NEW_CUES.get(new, ""))


## The most dice a level's move rolls (patterns or hidden options), 0 for a
## mix (its parts are other levels).
static func dice_count(move: Dictionary) -> int:
	var most := 0
	for p in move.get("patterns", []):
		most = maxi(most, String(p).length())
	for o in move.get("options", []):
		if o is Array and not o.is_empty():
			most = maxi(most, String(o[0]).length())
	return most
