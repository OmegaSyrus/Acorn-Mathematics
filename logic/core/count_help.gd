## Ellwynn's counting help (Phase 2 of the ship plan, 2026-11-28). Pure
## logic, no nodes: game/ellwynn.gd says the plan and the screens light the
## pips it names.
##   - Pip taps on the crossing: she says the count with each tap until the
##     child has beaten COUNT_HELP_MONSTERS monsters in that crossing.
##   - A wrong answer: she counts on from the first die while the dice light
##     up ("four, then five, six, seven"), or back for a take-away ("six,
##     then five, four"). Anything else (one die, a hidden die, a missing
##     number, mixed signs, a long count) has no plan: she says the answer.
extends RefCounted

const Attack := preload("res://logic/fight/attack.gd")

## Monsters beaten in one crossing before she stops counting pip taps.
const COUNT_HELP_MONSTERS := 2
## The most numbers counted on after the first die; longer counts fall back
## to saying the answer.
const MAX_STEPS := 12
## The cue between the first die and the counting on ("then"), and the one
## for a take-away (falls back to COUNT_THEN's line when it has none).
const COUNT_THEN := "count_then"
const COUNT_BACK_THEN := "count_back_then"
## Said once, when she goes quiet after the second monster.
const COUNT_QUIET := "count_quiet"


## True while she still says the count of the pips tapped on the crossing.
static func counts_aloud(monsters_beaten: int) -> bool:
	return monsters_beaten < COUNT_HELP_MONSTERS


## True at the moment she goes quiet: the monster just beaten was the one
## that reached the threshold.
static func just_went_quiet(monsters_beaten: int) -> bool:
	return monsters_beaten == COUNT_HELP_MONSTERS


## The count for dice shown with signs (one per die, "+" plain, "-" taken
## away; the crossing's problem["signs"], or "++" / "+-" for two dice).
## Returns the steps in order, or [] when there is no plain count:
##   {"n": first, "die": 0, "pip": -1}   the first die, all its pips
##   {"cue": COUNT_THEN or COUNT_BACK_THEN}
##   {"n": v, "die": i, "pip": j}       one number per pip of the later dice
## Counting on needs every sign "+"; counting back needs "+" then only "-".
static func plan(dice: Array, signs: String) -> Array:
	var n := dice.size()
	if n < 2 or signs.length() != n:
		return []
	for d in dice:
		if int(d) < 1 or int(d) > 6:
			return []
	var back: bool
	if signs == "+".repeat(n):
		back = false
	elif signs[0] == "+" and signs.substr(1) == "-".repeat(n - 1):
		back = true
	else:
		return []
	var steps := 0
	for i in range(1, n):
		steps += int(dice[i])
	if steps > MAX_STEPS:
		return []
	var v := int(dice[0])
	var out := [{"n": v, "die": 0, "pip": -1}, {"cue": COUNT_BACK_THEN if back else COUNT_THEN}]
	for i in range(1, n):
		for j in int(dice[i]):
			v += -1 if back else 1
			out.append({"n": v, "die": i, "pip": j})
	if v < 0:
		return []
	return out


## The number the plan ends on (the answer), -1 for no plan.
static func plan_answer(steps: Array) -> int:
	for k in range(steps.size() - 1, -1, -1):
		if steps[k].has("n"):
			return int(steps[k]["n"])
	return -1


## The signs of a fight's attack: Sprout's two dice are added, Oak's red
## slip die taken away. Other kinds (one die, Sapling's missing number) have
## no plain count.
static func fight_signs(kind: int) -> String:
	if kind == Attack.Kind.TWO_DICE:
		return "++"
	if kind == Attack.Kind.MOVE_AND_SLIP:
		return "+-"
	return ""
