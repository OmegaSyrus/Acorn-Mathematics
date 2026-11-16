extends "res://logic/fight/fight.gd"
## The miniboss duel: the same parry exchange, but the miniboss swings with
## rolled dice and the child picks a big plain NUMERAL for the answer (the
## total at Sprout, the difference at Oak; see AttackGen for every grade).
## The hero gets 3 fresh hearts; the miniboss has 5 (Terrence, 2026-11-07).
## The same block / shield bash phases as a monster fight.
## Losing restarts the duel and nothing else.
## Winning leads straight into the boss, which the game handles.

const MINIBOSS_HEARTS := 5


func _init(p_rng, p_grade: int, p_miniboss_id: String, p_hearts := MINIBOSS_HEARTS) -> void:
	super(p_rng, p_grade, p_miniboss_id, p_hearts)
	choice_style = ChoiceStyle.NUMERALS
	on_loss = OnLoss.RESTART_DUEL


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
	_wind_up()
