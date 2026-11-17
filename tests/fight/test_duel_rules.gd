extends "res://tests/fight/fight_test_base.gd"
## Phase 0 (2026-11-16): each miniboss has a rule of its own
## (logic/fight/duel.gd). The math stays the level's; the rules change how
## the dice show, and the Bog's pair splits the miniboss's hearts between
## two foes who take turns.

const Fight = preload("res://logic/fight/fight.gd")
const Duel = preload("res://logic/fight/duel.gd")
const Attack = preload("res://logic/fight/attack.gd")
const Monsters = preload("res://logic/fight/monsters.gd")
const Bots = preload("res://tests/fight/bots.gd")
const SeededRng = preload("res://logic/core/rng.gd")
const Content = preload("res://logic/core/content.gd")

const SPROUT := 2
const SAPLING := 3


## Every world's miniboss (its area file) has a rule, and no two share one.
func test_every_miniboss_has_its_own_rule() -> bool:
	var seen := []
	for w in Content.worlds():
		var mb: String = Content.area(w["area"])["miniboss"]
		check(Duel.RULES.has(mb), "%s has a rule" % mb)
		var r := Duel.rule_of(mb)
		check(not seen.has(r), "%s's rule %s is its own" % [mb, r])
		seen.append(r)
		check(Duel.OPENERS.has(r), "rule %s has an opener" % r)
	return true


## How each rule shows the dice, for two dice and for one.
func test_die_faces_by_rule() -> bool:
	var want := {
		"lava_miniboss": [Duel.PIPS, Duel.PIPS],
		"crystal_miniboss": [Duel.FLASH, Duel.FLASH],
		"bog_miniboss": [Duel.PIPS, Duel.PIPS],
		"mushroom_miniboss": [Duel.NUMERAL, Duel.PIPS],
		"space_miniboss": [Duel.NUMERAL, Duel.NUMERAL],
	}
	for mb in want:
		var d = Duel.new(SeededRng.new(3), SPROUT, mb)
		check(d.attack.dice.size() == 2, "%s swings two dice at Sprout" % mb)
		check([d.die_face(0), d.die_face(1)] == want[mb], "%s shows %s" % [mb, str([d.die_face(0), d.die_face(1)])])
		# one die: a numeral against numeral shields would only be matching
		var one = Duel.new(SeededRng.new(3), 1, mb)
		check(one.attack.dice.size() == 1, "%s swings one die at Acorn" % mb)
		check(one.die_face(0) != Duel.NUMERAL, "%s shows dots for a single die" % mb)
	# Sapling (a die and a target): the written rules write the die
	var sap = Duel.new(SeededRng.new(4), SAPLING, "space_miniboss")
	check(sap.attack.kind == Attack.Kind.DIE_AND_TARGET, "Sapling swing")
	check(sap.die_face(0) == Duel.NUMERAL and sap.target_as_numeral(), "Ratatoskr writes 4 + ? = 7")
	return true


## The pair: hearts add up to the miniboss's, a bash hits the foe who just
## swung, the turn passes after each bash, and both must fall.
func test_pair_takes_turns_and_both_must_fall() -> bool:
	var d = Duel.new(SeededRng.new(11), SPROUT, "bog_miniboss")
	check(d.foes.size() == 2, "two foes")
	var total := 0
	for f in d.foes:
		total += int(f["hearts"])
	check(total == Monsters.hearts_of("bog_miniboss"), "the pair's hearts add up to %d" % total)
	check(d.foe == 0 and d.phase == Fight.Phase.BLOCK, "the king swings first")
	# king swings, blocked; hero bashes the king
	d.choose(d.attack.answer_index)
	d.next_exchange()
	var out: Dictionary = d.choose(d.attack.answer_index)
	check(out["foe"] == 0 and int(d.foes[0]["hearts"]) == 1, "the bash hit the king")
	d.next_exchange()
	check(d.foe == 1, "then the queen's turn")
	# a wrong bash misses the queen and costs nobody a heart
	d.choose(d.attack.answer_index)
	d.next_exchange()
	d.choose((d.attack.answer_index + 1) % 4)
	check(int(d.foes[1]["hearts"]) == 2, "a missed bash leaves the queen")
	d.next_exchange()
	check(d.foe == 0, "back to the king")
	# play the rest right: the king falls first, then the queen alone
	var guard := 0
	while not d.is_over() and guard < 50:
		guard += 1
		out = d.choose(d.attack.answer_index)
		if d.is_over():
			break
		d.next_exchange()
		if int(d.foes[0]["hearts"]) <= 0:
			check(d.foe == 1 or d.phase == Fight.Phase.BASH, "a fallen king never swings again")
	check(d.state == Fight.State.WON, "won the duel")
	check(int(d.foes[0]["hearts"]) == 0 and int(d.foes[1]["hearts"]) == 0, "both foes are out")
	check(d.monster_hearts == 0, "and the duel's hearts with them")
	d.restart()
	check(d.foe == 0 and int(d.foes[0]["hearts"]) == 2 and int(d.foes[1]["hearts"]) == 2, "a rematch brings both back")
	return true


## The rules never make a duel easier to guess or impossible to win: the
## same bots as gate 2 for every miniboss.
func test_bots_vs_every_miniboss() -> bool:
	for mb in Duel.RULES:
		for g in [1, 2, 3, 4]:
			var line := "%s, grade %d:" % [mb, g]
			for bot in ["perfect", "random"]:
				var game_rng = SeededRng.new(7100 + g)
				var bot_rng = SeededRng.new(9100 + g)
				var wins := 0
				var n := 1500
				for i in n:
					if Bots.play(Duel.new(game_rng, g, mb), bot, bot_rng):
						wins += 1
				var rate := float(wins) / n
				line += " %s %.1f%%" % [bot, rate * 100.0]
				if bot == "perfect":
					check(wins == n, "%s perfect bot lost %d" % [line, n - wins])
				else:
					check(rate <= 0.15, "%s random bot won %.1f%%" % [line, rate * 100.0])
			notes.append(line)
	return true
