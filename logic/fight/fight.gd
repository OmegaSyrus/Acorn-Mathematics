extends RefCounted
## One fight: a run of exchanges until the hero or the monster is out of
## hearts. Pure logic, no timers: the game calls choose() on a tap and
## next_exchange() when the block or bash has finished playing.
##
##   WIND_UP --choose()--> RESOLVING --next_exchange()--> WIND_UP ...
##                     \--> WON  (monster collapses)
##                     \--> LOST (hero collapses)
##
## Two phases take turns (Terrence, 2026-11-07), the monster first:
##   BLOCK: the monster attacks; the child picks the right shield to block it.
##          A wrong shield lets the blow land: the hero loses a heart.
##   BASH:  the hero's "Shield bash"; a right shield costs the monster a
##          heart, a wrong one just misses (no heart lost).
## The monster holds its wind-up for as long as the child needs.

const AttackGen = preload("res://logic/fight/attack_gen.gd")
const GradesLib = preload("res://logic/core/grades.gd")

enum State { WIND_UP, RESOLVING, WON, LOST }

## Whose turn the current question is: the monster's attack or the hero's bash.
enum Phase { BLOCK, BASH }

## What the choices look like on screen. Monster fights use dice faces,
## except at Acorn: there the rolled die shows dots and the shields show big
## numerals, so the child picks the number that matches the dots instead of
## matching dots to the same dots (Terrence, 2026-10-28). The miniboss duel
## uses numerals at every grade.
enum ChoiceStyle { DICE, NUMERALS }

## What losing costs. The path layer acts on this; the fight only reports it.
enum OnLoss { RESTART_AREA, RESTART_DUEL }

const HERO_HEARTS := 3

var rng
var grade: int
var monster_id: String
var choice_style: int = ChoiceStyle.DICE
var on_loss: int = OnLoss.RESTART_AREA

var hero_hearts: int = HERO_HEARTS
var monster_hearts: int
var monster_max_hearts: int
var state: int = State.WIND_UP
var phase: int = Phase.BLOCK
## Hearts the hero can have at most: 3, or more when a heart picked up on the
## crossing carries into the fight.
var hero_max_hearts: int = HERO_HEARTS
var attack
var exchange_count: int = 0
var right_count: int = 0
var wrong_count: int = 0


## first_strike: the monster starts one heart down (a mimic whose lock the
## child answered right).
func _init(p_rng, p_grade: int, p_monster_id: String, p_monster_hearts: int, first_strike := false) -> void:
	rng = p_rng
	grade = p_grade
	monster_id = p_monster_id
	monster_max_hearts = p_monster_hearts
	monster_hearts = p_monster_hearts - (1 if first_strike else 0)
	if grade == GradesLib.Grade.ACORN:
		choice_style = ChoiceStyle.NUMERALS
	assert(monster_hearts >= 1, "Fight: monster must start with a heart")
	_wind_up()


## The child taps choice `index` (0..3). Returns the outcome so the game can
## play the right reaction:
##   phase:          BLOCK or BASH, the phase this answer was for
##   right:          BLOCK: blocked (else the hit lands, a hero heart);
##                   BASH: the bash lands (a monster heart; else a miss)
##   answer_index:   which choice was right, to light it after the answer
##   answer:         the number, to fade in beside the dots
##   hero_hearts, monster_hearts: after this exchange
##   state:          RESOLVING, WON or LOST
func choose(index: int) -> Dictionary:
	assert(state == State.WIND_UP, "Fight.choose: not waiting for a choice")
	assert(index >= 0 and index < attack.choices.size())
	exchange_count += 1
	var right: bool = attack.is_right(index)
	if right:
		right_count += 1
		if phase == Phase.BASH:
			monster_hearts -= 1
	else:
		wrong_count += 1
		if phase == Phase.BLOCK:
			hero_hearts -= 1
	if monster_hearts <= 0:
		state = State.WON
	elif hero_hearts <= 0:
		state = State.LOST
	else:
		state = State.RESOLVING
	return {
		"phase": phase,
		"right": right,
		"chosen_index": index,
		"answer_index": attack.answer_index,
		"answer": attack.answer,
		"hero_hearts": hero_hearts,
		"monster_hearts": monster_hearts,
		"state": state,
	}


## Starts the next exchange after the block or bash has played: a block is
## followed by the hero's bash, a bash by the monster's next attack.
func next_exchange() -> void:
	assert(state == State.RESOLVING, "Fight.next_exchange: fight is not mid-exchange")
	phase = Phase.BASH if phase == Phase.BLOCK else Phase.BLOCK
	_wind_up()


## The hero starts with `n` hearts (a heart from the crossing can make it 4
## or more); the hearts row grows to fit.
func set_hero_hearts(n: int) -> void:
	hero_hearts = maxi(1, n)
	hero_max_hearts = maxi(HERO_HEARTS, hero_hearts)


func is_over() -> bool:
	return state == State.WON or state == State.LOST


func _wind_up() -> void:
	attack = AttackGen.generate(rng, grade)
	state = State.WIND_UP
