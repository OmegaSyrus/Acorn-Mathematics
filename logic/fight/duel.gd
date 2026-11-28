extends "res://logic/fight/fight.gd"
## The miniboss duel: the same parry exchange, but the miniboss swings with
## rolled dice and the child picks a big plain NUMERAL for the answer (the
## total at Sprout, the difference at Oak; see AttackGen for every grade).
## The hero gets 3 fresh hearts; the miniboss has 5 (Terrence, 2026-11-07).
## The same block / shield bash phases as a monster fight.
## Losing restarts the duel and nothing else.
## Winning leads straight into the boss, which the game handles.
##
## Each miniboss has a rule of its own (Phase 0 of the ship plan,
## 2026-11-16). The math is always the level's; the rule changes how the
## dice are shown, walking from dots toward written numbers world by world:
##   total     Surtling Chief (Lava): the dice as dots, as in every fight.
##   flash     Lantern Lord (Crystal Mines): his lantern lights the dice for
##             a moment, then they go dark. A tap on a dark die lights it
##             again, so it is a look-quick game, never a memory test.
##   pair      Wisp King and Queen (the Bog): two foes with hearts of their
##             own who take turns. A bash hits the one who just swung; the
##             duel is won when both are out.
##   count_on  Hedley Kow (Mushroom Forest): the shape-shifter turns the
##             first die into its number, so the child counts on from it.
##   numerals  Ratatoskr (Space): the messenger writes every die as a
##             number. A tap on a number shows its dots for a moment.
## A rule that needs two dice (count_on, numerals) shows dots when the
## swing has only one die: a numeral against numeral shields would be a
## matching game, not math.

const Attack = preload("res://logic/fight/attack.gd")

const MINIBOSS_HEARTS := 4

const RULES := {
	"lava_miniboss": "total",
	"crystal_miniboss": "flash",
	"bog_miniboss": "pair",
	"mushroom_miniboss": "count_on",
	"space_miniboss": "numerals",
}

## The pair's two foes, the king first. Their hearts add up to the
## miniboss's (Monsters.ROSTER), so the duel is as long as the others.
const PAIRS := {
	"bog_miniboss": [
		{"id": "wisp_king", "name": "Wisp King", "hearts": 2},
		{"id": "wisp_queen", "name": "Wisp Queen", "hearts": 2},
	],
}

## The words in the talk box as the duel starts.
const OPENERS := {
	"total": "Fight!",
	"flash": "Look fast!",
	"pair": "Two foes!",
	"count_on": "Count on!",
	"numerals": "Read it!",
}

const PIPS := "pips"
const NUMERAL := "numeral"
const FLASH := "flash"

var rule := "total"
## pair only: [{id, name, hearts, max}], and whose turn it is.
var foes: Array = []
var foe := 0


func _init(p_rng, p_grade: int, p_miniboss_id: String, p_hearts := MINIBOSS_HEARTS) -> void:
	rule = rule_of(p_miniboss_id)
	super(p_rng, p_grade, p_miniboss_id, p_hearts)
	choice_style = ChoiceStyle.NUMERALS
	on_loss = OnLoss.RESTART_DUEL
	_reset_foes()


static func rule_of(miniboss_id: String) -> String:
	return RULES.get(miniboss_id, "total")


func opener() -> String:
	return OPENERS.get(rule, "Fight!")


## How die i of the current swing is shown: PIPS, NUMERAL or FLASH.
func die_face(i: int) -> String:
	var many: bool = attack.dice.size() >= 2 or attack.kind == Attack.Kind.DIE_AND_TARGET
	match rule:
		"flash":
			return FLASH
		"count_on":
			return NUMERAL if i == 0 and many else PIPS
		"numerals":
			return NUMERAL if many else PIPS
	return PIPS


## The Sapling target ("4 + ? = 7") as a numeral instead of dots.
func target_as_numeral() -> bool:
	return rule == "numerals"


## The pair's foe whose turn it is, or {} for a single miniboss.
func active_foe() -> Dictionary:
	return foes[foe] if not foes.is_empty() else {}


func choose(index: int) -> Dictionary:
	var hit_foe := foe
	var out := super(index)
	if not foes.is_empty() and out["phase"] == Phase.BASH and out["right"]:
		foes[hit_foe]["hearts"] -= 1
	out["foe"] = hit_foe
	return out


## After a bash the other foe takes its turn, if it still stands.
func next_exchange() -> void:
	if not foes.is_empty() and phase == Phase.BASH:
		var other := 1 - foe
		if int(foes[other]["hearts"]) > 0 or int(foes[foe]["hearts"]) <= 0:
			foe = other
	super()


## Starts the duel over: fresh hearts on both sides and a new swing. The
## RNG carries on, so the rematch is not a replay of the same swings.
func restart() -> void:
	hero_hearts = HERO_HEARTS
	hero_max_hearts = HERO_HEARTS
	phase = Phase.BLOCK
	monster_hearts = monster_max_hearts
	exchange_count = 0
	right_count = 0
	wrong_count = 0
	_reset_foes()
	_wind_up()


func _reset_foes() -> void:
	foes = []
	foe = 0
	if rule != "pair" or not PAIRS.has(monster_id):
		return
	for f in PAIRS[monster_id]:
		foes.append({"id": f["id"], "name": f["name"], "hearts": int(f["hearts"]), "max": int(f["hearts"])})
