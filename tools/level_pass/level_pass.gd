## How long a full pass of each Level takes (Phase 1 review: "time a full pass
## of Level 1"), estimated headless before anyone plays it.
##   godot --headless --path . --script tools/level_pass/level_pass.gd
##   (-- --passes=50 for a quick run; default 200)
##
## A pass of Level N is Lava N, Crystal N, Bog N, Mushroom N and Space N in
## map order; each world is its crossing (ScrollRun with the real monster
## fights, as tests/test_clear_chance.gd plays it), then its miniboss duel
## (Duel at the level's own fight; a loss restarts the duel), then its boss
## (BounceFight on the world's board at the level's boss_grade; a loss is
## "Try" and the boss again), then the world map and a tap on the next world.
## Bots answer every stone, shield and boss name right with probability P
## (100% and 85%); boss aim is random in [-650, 650], as the "right name,
## random aim" bot in tests/bounce/test_bounce_bots.gd.
##
## Wall-clock time = the game's own animation timings (read from
## game/scroll_screen.gd, game/fight/fight_screen.gd with its SLOW = 1.6,
## game/ui/die_view.gd, game/bounce/bounce_screen.gd, game/world_map_screen.gd;
## the ball's flight is the real BounceSim time, with the 30% slow-mo on the
## last heart) + a child's think time per tap (THINK below). Ellwynn's voice
## never blocks play (say_right / say_answer are not awaited; the 1 s
## ANSWER_DELAY runs under the sink / slip-back animation), so voice lengths
## are reported but not added.
## Writes tools/level_pass/RESULTS.md.
extends SceneTree

const Content := preload("res://logic/core/content.gd")
const Rng := preload("res://logic/core/rng.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const Fight := preload("res://logic/fight/fight.gd")
const Duel := preload("res://logic/fight/duel.gd")
const Monsters := preload("res://logic/fight/monsters.gd")
const BounceFight := preload("res://logic/bounce/bounce_fight.gd")
const BounceSim := preload("res://logic/bounce/bounce_sim.gd")

const OUT_PATH := "res://tools/level_pass/RESULTS.md"
const BOTS := [1.0, 0.85]

# --- the child's think time (assumptions, not game code) --------------------
## Per answer (a stone, a shield, a boss name): 3 s at Level 1 (the brief),
## the same at every Level (raise THINK_PER_LEVEL to slow later Levels).
const THINK_L1 := 3.0
const THINK_PER_LEVEL := 0.0
const GO_TAP := 0.5        # the green Go / Select after picking (confirm mode)
const ROLL_TAP := 1.0      # tapping the tray to roll on the crossing
const AIM := 2.0           # drag and let go on the boss board
const DOOR_TAP := 1.5      # the crossing's door, the duel's boss door, "Try again"
const MAP_TAP := 3.0       # picking the next world on the world map

# --- the game's timings (seconds) -----------------------------------------
const SLOW := 1.6                       # fight_screen.gd: every tween and wait * SLOW
const DIE_ROLL := 0.95 + 0.15 + 0.35    # die_view.gd TUMBLE_S + SETTLE_S + TURN_S
const DIE_STAGGER := 0.12               # each die after the first starts 0.12 s later
const HOP := 0.34                       # scroll_screen.gd HOP_S
const BOUNCE := 0.08 + 0.2 + 0.07       # _bounce()
const HAPPY4 := 4 * (0.06 + 0.26) + 0.06  # _happy(HAPPY_JUMPS = 4)
const HAPPY2 := 2 * (0.06 + 0.26) + 0.06
const FADE := 0.25
const REVEAL := 0.35 + 0.25
const HEART_TAKE := 0.9 + 0.2
const SLIP_BACK := 0.18 + 0.5 + 0.25 + HOP + BOUNCE + 0.9 + 0.4
const SINK := 0.18 + 0.35 + 0.9 + 0.6
const RESTART := FADE + FADE + 0.5
const CLEARED := 0.5 + HOP + FADE       # "Yes!", the door tap, the hop through, fade
# fight_screen.gd, all * SLOW
const F_OPEN := 0.8 * SLOW
const F_WIND := 0.25 * SLOW
const F_BEAT := 0.5 * SLOW
const F_HAPPY := 2 * 0.24 * SLOW
const F_BREAK := 1.5 * SLOW
const F_BASH := (0.12 + 0.16) * SLOW + F_BREAK + 0.35 * SLOW
const F_MISS := (0.12 + 0.16 + 0.25 + 0.2 + 0.35) * SLOW
const F_PARRY := (0.18 + 0.2 + 0.15 + 0.2 + 0.2) * SLOW
const F_HIT := 0.18 * SLOW + F_BREAK + 0.35 * SLOW
const F_FOE_FADES := 0.7 * SLOW
const F_COLLAPSE := (0.8 + 1.0) * SLOW
const F_HERO_DOWN := (0.7 + 0.6) * SLOW
const F_BOSS_DOOR := (0.5 + 0.6 + 0.3) * SLOW
# bounce_screen.gd
const B_AUTO_NAME := 0.3
const B_SETTLE := 0.5
const B_WIN := 1.2 + (0.6 + 1.8 + 0.4) + 1.0  # wait, gem bucket, wait
# world_map_screen.gd: a world newly unlocked shakes its lock off
const MAP_UNLOCK := 0.5 + 0.8

var passes := 200
var think := THINK_L1
var hand: Rng
var p_right := 1.0
var t := 0.0
var c := {}
var voice := {}


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--passes="):
			passes = arg.substr(9).to_int()
	var levels := Content.levels()
	var path := Content.level_path(levels)
	var areas := {}
	for w in Content.worlds():
		areas[w["id"]] = Content.area(w["area"])
	_voice_lengths()
	var rows := []
	for num in range(1, Content.LEVEL_COUNT + 1):
		var steps := path.filter(func(l): return int(l["num"]) == num)
		think = THINK_L1 + THINK_PER_LEVEL * (num - 1)
		for p in BOTS:
			p_right = p
			rows.append(_level(num, steps, areas))
			print("Level %d at %d%%: median %.1f min" % [num, roundi(p * 100), rows[-1]["median"]])
	_write(rows)
	quit(0)


## Plays `passes` passes of one Level; returns the summary row.
func _level(num: int, steps: Array, areas: Dictionary) -> Dictionary:
	var totals := []
	var restarts := 0.0
	var per_world := {}
	var counts := {}
	for lv in steps:
		per_world[lv["world"]] = []
		counts[lv["world"]] = {}
	for i in passes:
		hand = Rng.new(777000 + 1000 * num + i + (0 if p_right >= 1.0 else 500000))
		var total := 0.0
		for k in steps.size():
			var lv: Dictionary = steps[k]
			var area: Dictionary = areas[lv["world"]]
			var seed_value := 10007 * num + 131 * k + 7919 * i
			t = 0.0
			c = {"guesses": 0, "fights": 0, "fight_q": 0, "restarts": 0, "duel_q": 0, "duel_losses": 0,
					"boss_names": 0, "boss_shots": 0, "boss_losses": 0}
			_crossing(area, lv, seed_value)
			_duel(area, lv, seed_value + 1)
			_boss(area, lv, seed_value + 2)
			t += MAP_UNLOCK + MAP_TAP
			per_world[lv["world"]].append(t / 60.0)
			for key in c:
				counts[lv["world"]][key] = counts[lv["world"]].get(key, 0.0) + c[key]
			restarts += c["restarts"]
			total += t
		totals.append(total / 60.0)
	var world_medians := []
	for lv in steps:
		world_medians.append(_pct(per_world[lv["world"]], 0.5))
		for key in counts[lv["world"]]:
			counts[lv["world"]][key] /= float(passes)
	return {"num": num, "p": p_right, "median": _pct(totals, 0.5), "p90": _pct(totals, 0.9),
			"restarts": restarts / passes, "worlds": world_medians, "counts": counts,
			"names": steps.map(func(l): return l["name"])}


func _right() -> bool:
	return hand.randi_range(1, 100) <= roundi(100.0 * p_right)


func _pick(n: int, right_index: int) -> int:
	if n < 2 or _right():
		return right_index
	var wrong := hand.randi_range(0, n - 2)
	return wrong if wrong < right_index else wrong + 1


func _roll_time(n_dice: int) -> float:
	return DIE_ROLL + DIE_STAGGER * maxi(0, n_dice - 1)


## The crossing until the far shore, restarts and all.
func _crossing(area: Dictionary, lv: Dictionary, seed_value: int) -> void:
	var run := ScrollRun.new(area, lv, seed_value)
	var guard := 0
	while run.phase != ScrollRun.CLEARED and guard < 2000:
		guard += 1
		if run.phase == ScrollRun.AWAIT_FIGHT:
			_monster_fight(run)
			continue
		t += ROLL_TAP
		var p := run.roll()
		t += _roll_time(p["dice"].size()) + 0.2  # the sign fades in
		t += think + GO_TAP
		c["guesses"] += 1
		var out := run.choose(_pick(p["choices"].size(), p["answer_index"]))
		var hops := absi(int(out["to"]) - int(out["from"]))
		if out["right"]:
			t += HAPPY4
			_walk(out)
		elif out["result"] == "miss":
			t += hops * HOP + BOUNCE + SLIP_BACK
		else:
			t += hops * HOP + BOUNCE + SINK + RESTART
			c["restarts"] += 1
	t += CLEARED + DOOR_TAP


func _walk(w: Dictionary) -> void:
	t += (int(w["to"]) - int(w["from"])) * HOP + BOUNCE
	for ch in w.get("chests", []):
		t += BOUNCE + REVEAL + 1.3 + 0.22 * (int(ch["gems"]) - 1) + 0.15
	t += w.get("hearts", []).size() * (BOUNCE + HEART_TAKE)
	match w["result"]:
		"monster":
			t += REVEAL + 0.5
		"hop", "chest", "heart":
			t += 0.3 if w["result"] == "hop" else 0.0


func _monster_fight(run: ScrollRun) -> void:
	var fg: Dictionary = run.fight_now()
	var mon := run.current_monster()
	var f := Fight.new(run.rng, int(fg["grade"]), mon, Monsters.hearts_of(mon))
	f.set_hero_hearts(run.hearts)
	f.set_top(int(fg["top"]))
	c["fights"] += 1
	t += FADE + FADE + F_OPEN
	var q := _exchanges(f, false)
	c["fight_q"] += q
	t += FADE
	var won := f.state == Fight.State.WON
	var out := run.resolve_fight(won, f.hero_hearts)
	if out["restarted"]:
		c["restarts"] += 1
		t += RESTART
	else:
		t += FADE + HAPPY2
		if out.has("walk"):
			_walk(out["walk"])


## Exchanges until the fight is over (a duel: until it is won). Returns the
## questions asked.
func _exchanges(f, duel: bool) -> int:
	var q := 0
	while q < 500:
		t += F_WIND + _roll_time(f.attack.dice.size()) + think + GO_TAP
		q += 1
		var bashing: bool = f.phase == Fight.Phase.BASH
		var out: Dictionary = f.choose(_pick(f.attack.choices.size(), f.attack.answer_index))
		t += F_BEAT
		if bashing and out["right"]:
			t += F_HAPPY + F_BASH
		elif bashing:
			t += F_MISS
		elif out["right"]:
			t += F_HAPPY + F_PARRY
		else:
			t += F_HIT
		if duel and not f.foes.is_empty() and bashing and out["right"] \
				and int(f.foes[int(out["foe"])]["hearts"]) <= 0 and out["state"] != Fight.State.WON:
			t += F_FOE_FADES
		if out["state"] == Fight.State.WON:
			t += F_COLLAPSE
			return q
		if out["state"] == Fight.State.LOST:
			t += F_HERO_DOWN
			if not duel:
				return q
			c["duel_losses"] += 1
			t += 0.5 * SLOW + DOOR_TAP
			f.restart()
			continue
		f.next_exchange()
	return q


func _duel(area: Dictionary, lv: Dictionary, seed_value: int) -> void:
	if not area.has("miniboss"):
		return
	var fg: Dictionary = lv["fight"]
	var f := Duel.new(Rng.new(seed_value), int(fg["grade"]), area["miniboss"], Monsters.hearts_of(area["miniboss"]))
	f.set_top(int(fg["top"]))
	t += F_OPEN
	c["duel_q"] += _exchanges(f, true)
	t += F_BOSS_DOOR + DOOR_TAP


func _boss(area: Dictionary, lv: Dictionary, seed_value: int) -> void:
	if not area.has("boss"):
		return
	var grade := int(lv.get("boss_grade", 1))
	var tries := 0
	while tries < 50:
		tries += 1
		var b := BounceFight.new(Rng.new(seed_value + 977 * tries), grade, {}, {}, str(area["world"]))
		while not b.is_over():
			var target: int = b.target
			t += _roll_time(1 if target <= 6 else 2) if target <= 12 else 0.0
			if b.auto_name():
				b.name_for_child()
				t += B_AUTO_NAME
			else:
				b.name_peg(_pick(b.choices.size(), b.choices.find(b.answer_face)))
				t += think
				c["boss_names"] += 1
			t += AIM
			var hearts_before: int = b.boss_hearts
			var sim = b.fire(hand.randi_range(-650, 650))
			var lethal_at := -1.0
			while sim.ended == BounceSim.End.NONE:
				sim.step()
				if lethal_at < 0.0 and sim.damage >= hearts_before:
					lethal_at = sim.t
			t += sim.t if lethal_at < 0.0 else lethal_at + (sim.t - lethal_at) / 0.3
			t += B_SETTLE
			b.end_shot()
			c["boss_shots"] += 1
		if b.state == BounceFight.State.WON:
			t += B_WIN
			return
		c["boss_losses"] += 1
		t += DOOR_TAP  # the fail screen's Try


func _pct(xs: Array, q: float) -> float:
	var s := xs.duplicate()
	s.sort()
	return s[clampi(int(floor(q * (s.size() - 1) + 0.5)), 0, s.size() - 1)]


func _voice_lengths() -> void:
	var lens := []
	for n in range(0, 21):
		var path := "res://audio/voice/ellwynn/answer-%d.mp3" % n
		if ResourceLoader.exists(path):
			var s = load(path)
			if s != null:
				lens.append(s.get_length())
	var w = load("res://audio/voice/ellwynn/placeholder-woohoo.mp3") if ResourceLoader.exists("res://audio/voice/ellwynn/placeholder-woohoo.mp3") else null
	voice = {"answers": lens.size(), "mean": 0.0 if lens.is_empty() else lens.reduce(func(a, b): return a + b) / lens.size(),
			"max": 0.0 if lens.is_empty() else lens.max(), "woohoo": 0.0 if w == null else w.get_length()}


func _write(rows: Array) -> void:
	var L := []
	L.append("# Level pass timing (headless estimate)")
	L.append("")
	L.append("`godot --headless --path . --script tools/level_pass/level_pass.gd` (%d passes per bot per Level, fixed seeds)." % passes)
	L.append("Minutes for one full pass: each world's crossing, miniboss duel and boss, then the map. Think time %.1f s per answer at Level 1, +%.1f s a Level." % [THINK_L1, THINK_PER_LEVEL])
	L.append("")
	L.append("| Level | Bot | Median min | P90 min | Mean restarts | Lava | Crystal | Bog | Mushroom | Space |")
	L.append("|---|---|---|---|---|---|---|---|---|---|")
	for r in rows:
		var ws: Array = r["worlds"].map(func(x): return "%.1f" % x)
		L.append("| %d | %d%% | %.1f | %.1f | %.2f | %s |" % [r["num"], roundi(r["p"] * 100), r["median"], r["p90"], r["restarts"], " | ".join(ws)])
	L.append("")
	L.append("Mean counts per world (Level 1 and the slowest worlds are worth a look):")
	L.append("")
	L.append("| Level | Bot | World | Guesses | Fights | Fight Qs | Restarts | Duel Qs | Duel losses | Boss names | Boss shots | Boss losses |")
	L.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
	for r in rows:
		var names: Array = r["names"]
		var k := 0
		for w in r["counts"]:
			var m: Dictionary = r["counts"][w]
			L.append("| %d | %d%% | %s | %.1f | %.1f | %.1f | %.2f | %.1f | %.2f | %.1f | %.1f | %.2f |" % [r["num"], roundi(r["p"] * 100), names[k],
					m["guesses"], m["fights"], m["fight_q"], m["restarts"], m["duel_q"], m["duel_losses"], m["boss_names"], m["boss_shots"], m["boss_losses"]])
			k += 1
	L.append("")
	L.append("Ellwynn's number lines: %d recorded, mean %.2f s, longest %.2f s; Woo-hoo %.2f s. They play over the animations (not awaited), so they add no time." % [voice["answers"], voice["mean"], voice["max"], voice["woohoo"]])
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string("\n".join(L) + "\n")
	f.close()
	print("\n".join(L))
