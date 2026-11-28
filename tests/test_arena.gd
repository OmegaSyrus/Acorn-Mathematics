## The Arena (Phase 6, 2026-11-28): logic/modes/arena_run.gd. Unit checks
## (opening, the round, no gentle failing, the reward once, the same math as
## the path) and bots at every Level: a round is 5 fights from the book with
## 3 hearts carried through and no refills.
extends "res://tests/support/test_case.gd"

const Content := preload("res://logic/core/content.gd")
const Rng := preload("res://logic/core/rng.gd")
const Book := preload("res://logic/core/book.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ArenaRun := preload("res://logic/modes/arena_run.gd")
const Modes := preload("res://logic/modes/modes.gd")
const Fight := preload("res://logic/fight/fight.gd")
const Monsters := preload("res://logic/fight/monsters.gd")

const RUNS := 400
## Gates for one round at each Level. Measured 2026-11-28: always right
## clears 100%, 85% right clears 62% to 68%, a random guesser 0%.
const BOT_85_FLOOR := 0.45
const BOT_85_CEILING := 0.85
const RANDOM_CEILING := 0.03

var notes := []


func _save_with(ids: Array) -> Dictionary:
	var s := SaveData.new_profile("p_000000000001")
	for id in ids:
		Book.record(s, id, 1)
	return s


## Every plain monster the path meets.
func _all_monsters() -> Array:
	var out := []
	for id in Monsters.ROSTER:
		if Monsters.ROSTER[id]["role"] == "monster" and ArenaRun.world_of(id) != "":
			out.append(id)
	return out


func test_arena_opens_with_three_monsters() -> bool:
	var s := _save_with(["blorp", "surtling"])
	check(not ArenaRun.is_open(s), "two cards: still locked")
	check(not Modes.is_open(s, Modes.ARENA), "Modes agrees")
	Book.record(s, "lava_miniboss", 1)
	check(not ArenaRun.is_open(s), "a miniboss card does not count")
	Book.record(s, "craggy", 1)
	check(ArenaRun.is_open(s), "three monster cards: open")
	check(Modes.is_new(s, Modes.ARENA), "just opened: New!")
	Modes.mark_seen(s, Modes.ARENA)
	check(not Modes.is_new(s, Modes.ARENA), "tapped once: no more New!")
	eq(s[Modes.SEEN_KEY], ["arena"], "kept in the save")
	Modes.mark_seen(s, Modes.ARENA)
	eq(s[Modes.SEEN_KEY], ["arena"], "only once")
	check(not Modes.is_new(_save_with([]), Modes.ARENA), "a locked mode is not new")
	return true


func test_round_draw() -> bool:
	var pool := _all_monsters()
	eq(pool.size(), 15, "15 monsters on the path (3 a world)")
	for seed_value in 200:
		var run := ArenaRun.new(pool, 1, seed_value)
		eq(run.monsters.size(), ArenaRun.ROUND_FIGHTS, "5 fights a round")
		var seen := {}
		for i in run.monsters.size():
			check(pool.has(run.monsters[i]), "from the book")
			seen[run.monsters[i]] = true
		check(seen.size() == ArenaRun.ROUND_FIGHTS, "a big book: 5 different monsters")
	var small := ["blorp", "surtling", "craggy"]
	for seed_value in 200:
		var run := ArenaRun.new(small, 2, seed_value)
		eq(run.monsters.size(), ArenaRun.ROUND_FIGHTS, "5 fights from 3 cards")
		var seen := {}
		for i in run.monsters.size():
			seen[run.monsters[i]] = true
			if i > 0:
				check(run.monsters[i] != run.monsters[i - 1], "never the same one twice in a row")
		eq(seen.size(), 3, "every card comes up")
	eq(ArenaRun.new(small, 1, 7).monsters, ArenaRun.new(small, 1, 7).monsters, "seeded: the same round again")
	check(ArenaRun.new(["tiddy_mun"], 1, 1).monsters.is_empty(), "a monster no crossing holds is left out")
	return true


## The Arena asks what the path asks for that monster in its world at the
## Level, with the Debug fight switch, the same as ScrollRun.fight_now().
func test_arena_math_is_the_paths() -> bool:
	var levels := Content.levels()
	var areas := {}
	for w in Content.worlds():
		if w.has("area"):
			areas[w["id"]] = Content.area(w["area"])
	var met := 0
	for lv in levels.values():
		var area: Dictionary = areas.get(lv["world"], {})
		if area.is_empty():
			continue
		for math in [ScrollRun.FIGHTS_STEP_BEFORE, ScrollRun.FIGHTS_OWN]:
			var run := ScrollRun.new(area, lv, 77 + int(lv["id"]))
			run.fight_math = math
			while run.phase != ScrollRun.CLEARED:
				if run.phase == ScrollRun.AWAIT_FIGHT:
					var mon := run.current_monster()
					eq(ArenaRun.fight_for(mon, int(lv["num"]), math), run.fight_now(),
							"%s %s at %s (%s)" % [mon, lv["world"], lv["name"], math])
					eq(ScrollRun.monster_fight(area, lv, mon, math), run.fight_now(), "the shared helper")
					met += 1
					run.resolve_fight(true, run.hearts)
					continue
				var p := run.roll()
				run.choose(p["answer_index"])
	eq(met, 30 * 3 * 2, "every monster of every level, both switch settings")
	var a := ArenaRun.new(["blorp", "surtling", "craggy"], 3, 5, ScrollRun.FIGHTS_OWN)
	eq(a.fight_now(), ArenaRun.fight_for(a.monster_now(), 3, ScrollRun.FIGHTS_OWN), "the run asks its Level and switch")
	eq(a.level_id_now(), Content.level_id("lava_caves", 3), "Lava 3's id")
	return true


func test_loss_restarts_at_fight_one_with_no_pay() -> bool:
	var s := _save_with(["blorp", "surtling", "craggy"])
	var gems := int(s["gems"])
	var run := ArenaRun.new(Book.arena_monsters(s), 2, 11)
	var round := run.monsters.duplicate()
	eq(run.resolve(true, 2), "next", "fight 1 won")
	eq(run.hearts, 2, "hearts carried")
	eq(run.resolve(true, 2), "next", "fight 2 won")
	eq(run.resolve(false, 0), ArenaRun.LOST, "fight 3 lost: the round is over")
	eq(run.reward(s), 0, "nothing paid")
	eq(int(s["gems"]), gems, "gems as they were")
	run.restart()
	eq(run.at, 0, "back to fight 1")
	eq(run.hearts, ArenaRun.HERO_HEARTS, "3 hearts again")
	eq(run.phase, ArenaRun.READY, "ready for Go")
	eq(run.monsters, round, "the same monsters")
	eq(run.tries, 2, "second try")
	return true


func test_reward_once() -> bool:
	var s := _save_with(["blorp", "surtling", "craggy"])
	var gems := int(s["gems"])
	var run := ArenaRun.new(Book.arena_monsters(s), 1, 3)
	eq(run.reward(s), 0, "nothing before the round is won")
	for i in ArenaRun.ROUND_FIGHTS - 1:
		eq(run.resolve(true, 3), "next", "fight %d won" % (i + 1))
	eq(run.resolve(true, 1), ArenaRun.WON, "the last fight wins the round")
	eq(run.reward(s), ArenaRun.REWARD_GEMS, "3 gems")
	eq(run.reward(s), 0, "only once")
	eq(int(s["gems"]), gems + ArenaRun.REWARD_GEMS, "banked once")
	check(ArenaRun.REWARD_GEMS < 10, "smaller than any path boss bucket")
	check(not s.has("run") or s["run"] == null, "the saved run untouched")
	return true


# --- bots ------------------------------------------------------------------

## One round: true when all 5 fights are won.
func _round(run: ArenaRun, hand: Rng, p_right: float) -> bool:
	while run.phase == ArenaRun.READY:
		var fg := run.fight_now()
		var mon := run.monster_now()
		var f := Fight.new(Rng.new(run.fight_seed()), int(fg["grade"]), mon, Monsters.hearts_of(mon))
		f.set_hero_hearts(run.hearts)
		f.set_top(int(fg["top"]))
		while not f.is_over():
			var n: int = f.attack.choices.size()
			var pick: int
			if p_right < 0.0:
				pick = hand.randi_range(0, n - 1)  # a random guesser
			elif hand.randi_range(1, 100) <= roundi(100.0 * p_right):
				pick = f.attack.answer_index
			else:
				var wrong := hand.randi_range(0, n - 2)
				pick = wrong if wrong < f.attack.answer_index else wrong + 1
			f.choose(pick)
			if not f.is_over():
				f.next_exchange()
		run.resolve(f.state == Fight.State.WON, f.hero_hearts)
	return run.phase == ArenaRun.WON


func _clear_rate(level: int, p_right: float, salt: int) -> float:
	var pool := _all_monsters()
	var hand := Rng.new(4100 + 17 * level + salt)
	var wins := 0
	for i in RUNS:
		var run := ArenaRun.new(pool, level, 900 + 1000 * level + 7 * salt + i)
		if _round(run, hand, p_right):
			wins += 1
	return float(wins) / RUNS


func test_arena_bots_every_level() -> bool:
	var rows := []
	for level in range(1, Content.LEVEL_COUNT + 1):
		var perfect := _clear_rate(level, 1.0, 1)
		var good := _clear_rate(level, 0.85, 2)
		var guess := _clear_rate(level, -1.0, 3)
		eq(perfect, 1.0, "Level %d: always right clears every round" % level)
		check(good >= BOT_85_FLOOR and good <= BOT_85_CEILING, "Level %d: 85%% right clears %d%% (want %d%% to %d%%)" % [
				level, roundi(100.0 * good), roundi(100.0 * BOT_85_FLOOR), roundi(100.0 * BOT_85_CEILING)])
		check(guess <= RANDOM_CEILING, "Level %d: a random guesser clears %.1f%% (want at most %d%%)" % [
				level, 100.0 * guess, roundi(100.0 * RANDOM_CEILING)])
		rows.append("Level %d: right %d%%, 85%% %d%%, random %.1f%%" % [
				level, roundi(100.0 * perfect), roundi(100.0 * good), 100.0 * guess])
	notes.append("Arena, one round of 5 fights clears (%d rounds each):" % RUNS)
	for r in rows:
		notes.append("  " + r)
	return true
