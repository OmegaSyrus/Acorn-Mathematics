## The 85% bot (2026-11-12): a player who answers every question right with
## probability 0.85, stones and fights alike, plays each level's crossing
## (ScrollRun with the real fights, seeded) and the clear chance of one try
## is printed per level. Only a loose floor is asserted: the table is for
## reading, not tuning against.
extends "res://tests/support/test_case.gd"

const Content := preload("res://logic/core/content.gd")
const Rng := preload("res://logic/core/rng.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const Fight := preload("res://logic/fight/fight.gd")
const Monsters := preload("res://logic/fight/monsters.gd")

const P_RIGHT := 0.85
const RUNS := 300
## Every level clears at least this often in one try at 85% right.
const FLOOR := 0.35

var notes := []


func _right(hand: Rng) -> bool:
	return hand.randi_range(1, 100) <= roundi(100.0 * P_RIGHT)


## The right index with probability P_RIGHT, else one of the others
## (a single stone left to the shore can only be right).
func _pick(hand: Rng, n: int, right_index: int) -> int:
	if _right(hand) or n < 2:
		return right_index
	var wrong := hand.randi_range(0, n - 2)
	return wrong if wrong < right_index else wrong + 1


## One try at the crossing: true when it reaches the far shore without a
## restart (a lost last heart or a lost fight restarts it).
func _one_try(area: Dictionary, lv: Dictionary, seed_value: int, hand: Rng) -> bool:
	var run := ScrollRun.new(area, lv, seed_value)
	while run.phase != ScrollRun.CLEARED and run.attempt == 1:
		if run.phase == ScrollRun.AWAIT_FIGHT:
			var fg: Dictionary = run.fight_now()
			var mon := run.current_monster()
			var f := Fight.new(run.rng, int(fg["grade"]), mon, Monsters.hearts_of(mon))
			f.set_hero_hearts(run.hearts)
			f.set_top(int(fg["top"]))
			while not f.is_over():
				f.choose(_pick(hand, f.attack.choices.size(), f.attack.answer_index))
				if not f.is_over():
					f.next_exchange()
			run.resolve_fight(f.state == Fight.State.WON, f.hero_hearts)
			continue
		var p := run.roll()
		run.choose(_pick(hand, p["choices"].size(), p["answer_index"]))
	return run.phase == ScrollRun.CLEARED and run.attempt == 1


func test_85_percent_bot_clear_chance() -> bool:
	var levels := Content.levels()
	var areas := {}
	for aid in Content.area_ids():
		var a := Content.area(aid)
		if a.get("type") == "scroll" and a.has("world") and a.has("guesses"):
			areas[a["world"]] = a
	var rows := {}
	for lv in Content.level_path(levels):
		var area: Dictionary = areas[lv["world"]]
		var hand := Rng.new(9000 + int(lv["id"]))
		var clears := 0
		for i in RUNS:
			if _one_try(area, lv, 5000 + 131 * int(lv["id"]) + i, hand):
				clears += 1
		var chance := float(clears) / RUNS
		if not rows.has(lv["world"]):
			rows[lv["world"]] = []
		rows[lv["world"]].append("%s %d%%" % [lv["name"], roundi(100.0 * chance)])
		check(chance >= FLOOR, "%s clears %d%% at 85%% right (floor %d%%)" % [lv["name"], roundi(100.0 * chance), roundi(100.0 * FLOOR)])
	notes.append("85%% right, one try clears (%d runs a level):" % RUNS)
	for w in rows:
		notes.append("  " + ", ".join(rows[w]))
	return true
