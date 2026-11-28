extends "res://tests/support/test_case.gd"

const CountHelp := preload("res://logic/core/count_help.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const Content := preload("res://logic/core/content.gd")
const Attack := preload("res://logic/fight/attack.gd")
const Rng := preload("res://logic/core/rng.gd")
const MoveGen := preload("res://logic/core/move_gen.gd")


func _said(steps: Array) -> Array:
	var out := []
	for st in steps:
		out.append(st["n"] if st.has("n") else st["cue"])
	return out


## "four, then five, six, seven": the first die whole, then a pip of the
## second die per number.
func test_count_on_two_dice() -> bool:
	var steps := CountHelp.plan([4, 3], "++")
	eq(_said(steps), [4, "count_then", 5, 6, 7], "4 + 3 counts on")
	eq(steps[0], {"n": 4, "die": 0, "pip": -1}, "first die whole")
	eq(steps[2], {"n": 5, "die": 1, "pip": 0}, "five lights pip 0 of die 2")
	eq(steps[4], {"n": 7, "die": 1, "pip": 2}, "seven lights pip 2 of die 2")
	check(CountHelp.plan_answer(steps) == 7, "ends on the answer")
	return true


func test_count_on_across_dice() -> bool:
	var steps := CountHelp.plan([2, 1, 3], "+++")
	eq(_said(steps), [2, "count_then", 3, 4, 5, 6], "carries across each die")
	eq(steps[3], {"n": 4, "die": 2, "pip": 0}, "four is the third die's first pip")
	return true


## "six, then five, four": a take-away counts back on the red dice.
func test_count_back() -> bool:
	var steps := CountHelp.plan([6, 2], "+-")
	eq(_said(steps), [6, "count_back_then", 5, 4], "6 - 2 counts back")
	eq(_said(CountHelp.plan([5, 1, 2], "+--")), [5, "count_back_then", 4, 3, 2], "two red dice")
	check(CountHelp.plan_answer(CountHelp.plan([5, 5], "+-")) == 0, "down to zero")
	return true


## Not a plain count: she says the answer instead.
func test_no_plan() -> bool:
	check(CountHelp.plan([4], "+").is_empty(), "one die")
	check(CountHelp.plan([4, 3, 2], "++-").is_empty(), "mixed signs")
	check(CountHelp.plan([4, 3], "-+").is_empty(), "red first")
	check(CountHelp.plan([4, 3], "+").is_empty(), "signs don't match the dice")
	check(CountHelp.plan([6, 6, 6, 6], "++++").is_empty(), "18 steps is too long")
	check(not CountHelp.plan([6, 6, 6], "+++").is_empty(), "12 steps is fine")
	check(CountHelp.plan([0, 3], "++").is_empty(), "not a die face")
	check(CountHelp.plan([2, 4], "+-").is_empty(), "below zero")
	check(CountHelp.plan_answer([]) == -1, "no plan, no answer")
	return true


func test_fight_signs() -> bool:
	check(CountHelp.fight_signs(Attack.Kind.TWO_DICE) == "++", "Sprout adds")
	check(CountHelp.fight_signs(Attack.Kind.MOVE_AND_SLIP) == "+-", "Oak takes away")
	check(CountHelp.fight_signs(Attack.Kind.ONE_DIE) == "", "one die")
	check(CountHelp.fight_signs(Attack.Kind.DIE_AND_TARGET) == "", "missing number")
	return true


## Every Acorn move (the crossing's two dice) has a plan that ends on its answer.
func test_every_move_counts_to_its_answer() -> bool:
	var grade: Dictionary = Content.grades()[1]
	var r := Rng.new(77)
	for i in 2000:
		var p := MoveGen.generate_move(grade, r, 1 + i % 8)
		var signs := "+" + ("-" if p["op"] == "sub" else "+")
		var steps := CountHelp.plan(p["dice"], signs)
		if CountHelp.plan_answer(steps) != int(p["answer"]):
			failures.append("move %s counts to %d" % [JsonUtil.canonical(p), CountHelp.plan_answer(steps)])
			return true
	return true


func test_quiet_after_two_monsters() -> bool:
	check(CountHelp.COUNT_HELP_MONSTERS == 2, "two monsters")
	check(CountHelp.counts_aloud(0) and CountHelp.counts_aloud(1), "counts before")
	check(not CountHelp.counts_aloud(2) and not CountHelp.counts_aloud(3), "quiet after")
	check(CountHelp.just_went_quiet(2) and not CountHelp.just_went_quiet(1) and not CountHelp.just_went_quiet(3),
			"the quiet line once, at the second")
	return true


const FIXED := {
	"id": "fixed_scroll", "type": "scroll", "grades": [1], "length": 40,
	"chest_gems": {"common": 1, "rare": 2, "rare_in": 6},
	"spaces": [
		{"at": 4, "type": "chest"}, {"at": 9, "type": "monster", "monster": "blorp"},
		{"at": 22, "type": "monster", "monster": "surtling"},
		{"at": 35, "type": "monster", "monster": "craggy"},
	],
}


func _force_move(run: ScrollRun, dist: int) -> int:
	run.roll()
	run.problem["answer_index"] = dist - 1
	return dist - 1


## Monsters beaten in this crossing: counted once each fight is won, kept
## through a lost heart, back to 0 when the crossing starts over.
func test_monsters_beaten_in_the_crossing() -> bool:
	var run := ScrollRun.new(FIXED, Content.grades()[1], 5)
	run.pos = 7
	run.target = 7
	run.choose(_force_move(run, 2))
	check(run.phase == ScrollRun.AWAIT_FIGHT and run.monsters_beaten() == 0, "the fight isn't won yet")
	run.resolve_fight(true)
	check(run.monsters_beaten() == 1, "one beaten")
	run.pos = 20
	run.target = 20
	run.choose(_force_move(run, 2))
	run.resolve_fight(true)
	check(run.monsters_beaten() == 2, "two beaten")
	run.roll()
	var miss := run.choose((run.problem["answer_index"] + 1) % run.problem["choices"].size())
	check(miss["result"] == "miss" and run.monsters_beaten() == 2, "a lost heart keeps them")
	var data := run.to_save()
	var again := ScrollRun.new(FIXED, Content.grades()[1], data["seed"])
	again.restore(data)
	check(again.monsters_beaten() == 2, "a resumed crossing knows them")
	while run.attempt == 1:
		run.roll()
		run.choose((run.problem["answer_index"] + 1) % run.problem["choices"].size())
	check(run.pos == 0 and run.monsters_beaten() == 0, "a restart starts the count again")
	return true


## The cue ids the lines sheet asks for are in the lines file.
func test_count_cues_listed() -> bool:
	var lines = JsonUtil.load_file("res://content/ellwynn_lines.json")
	var cues: Dictionary = lines.get("cues", {})
	for c in [CountHelp.COUNT_THEN, CountHelp.COUNT_BACK_THEN, CountHelp.COUNT_QUIET]:
		check(cues.has(c), "cue %s missing" % c)
	return true
