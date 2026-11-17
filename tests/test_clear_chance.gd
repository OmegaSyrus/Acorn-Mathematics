## The 85% bot (2026-11-12): a player who answers every question right with
## probability 0.85, stones and fights alike, plays each level's crossing
## (ScrollRun with the real fights, seeded) and the clear chance of one try
## is printed per level. Phase 1 of the ship plan (2026-11-16): every
## crossing clears 55% to 70% of tries (3 misses allowed: three hearts and
## one heart stone; Lava 7 guesses, the rest 8, three monsters each).
## Every enemy has a heart less since 2026-11-17 (Terrence: enemies had too
## much health), so fights end sooner and the band is now 55% to 82%.
extends "res://tests/support/test_case.gd"

const Content := preload("res://logic/core/content.gd")
const Rng := preload("res://logic/core/rng.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const Fight := preload("res://logic/fight/fight.gd")
const Monsters := preload("res://logic/fight/monsters.gd")

const P_RIGHT := 0.85
const RUNS := 800
## Every level clears this often in one try at 85% right.
const FLOOR := 0.55
const CEILING := 0.82

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
	var path := Content.level_path(levels)
	eq(path.size(), 30, "the 30-step path")
	for lv in path:
		var area: Dictionary = areas[lv["world"]]
		var hand := Rng.new(9000 + int(lv["id"]))
		var clears := 0
		for i in RUNS:
			if _one_try(area, lv, 5000 + 131 * int(lv["id"]) + i, hand):
				clears += 1
		var chance := float(clears) / RUNS
		var row := "Level %d" % int(lv["num"])
		if not rows.has(row):
			rows[row] = []
		rows[row].append("%s %d%%" % [lv["name"], roundi(100.0 * chance)])
		check(chance >= FLOOR and chance <= CEILING, "%s clears %d%% at 85%% right (want %d%% to %d%%)" % [
				lv["name"], roundi(100.0 * chance), roundi(100.0 * FLOOR), roundi(100.0 * CEILING)])
	notes.append("85%% right, one try clears (%d runs a level):" % RUNS)
	for w in rows:
		notes.append("  " + ", ".join(rows[w]))
	return true
