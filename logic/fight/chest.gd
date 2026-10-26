extends RefCounted
## Chest outcomes (plan section 03, "Mimics" and "Failing").
##
## Whether a chest is a mimic is set when the area is built, never by a
## wrong answer. The path layer asks the lock question; this decides what
## happens next:
##   normal chest, right answer -> OPENED
##   normal chest, wrong answer -> STAYS_SHUT (nothing else happens)
##   mimic, either answer       -> MIMIC_FIGHT (a real fight; a right answer
##                                 gives the first strike, so the mimic
##                                 starts one heart down)

const Fight = preload("res://logic/fight/fight.gd")
const Monsters = preload("res://logic/fight/monsters.gd")

enum Result { OPENED, STAYS_SHUT, MIMIC_FIGHT }


static func resolve(is_mimic: bool, answered_right: bool) -> int:
	if is_mimic:
		return Result.MIMIC_FIGHT
	return Result.OPENED if answered_right else Result.STAYS_SHUT


## The fight a mimic starts. Losing it restarts the area like any fight.
static func mimic_fight(rng, grade: int, answered_right: bool, mimic_id := "mimic"):
	return Fight.new(rng, grade, mimic_id, Monsters.hearts_of(mimic_id), answered_right)
