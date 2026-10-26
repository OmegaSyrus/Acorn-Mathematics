extends RefCounted
## One monster attack: what the monster shows and the four choices.
## Plain data. In C++ this is a struct.

## How the attack is shown (see the grade table in the plan, section 05).
enum Kind {
	ONE_DIE,        ## Acorn: one die, match its count.
	TWO_DICE,       ## Sprout: two dice, the total.
	DIE_AND_TARGET, ## Sapling: a die and a target, the missing number.
	MOVE_AND_SLIP,  ## Oak: a move die and a red slip die, the difference.
}

var grade: int
var kind: int
## The dice the monster swings with. Oak: [move, slip].
var dice: Array[int] = []
## Sapling only: the number the die must reach. 0 otherwise.
var target: int = 0
var answer: int
## Four values in display order. Exactly one equals answer.
var choices: Array[int] = []
var answer_index: int


func is_right(index: int) -> bool:
	return index == answer_index


func to_dict() -> Dictionary:
	return {
		"grade": grade,
		"kind": kind,
		"dice": dice.duplicate(),
		"target": target,
		"answer": answer,
		"choices": choices.duplicate(),
		"answer_index": answer_index,
	}
