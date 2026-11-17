## The skill id for an answered question (docs/contract/skills.json). Every
## play log answer carries one, so reports work from skills, not from a
## level's place, and reordering levels never breaks history.
##
## A skill names what the child does and the size of the biggest number:
## the total when adding, the number taken from when taking away.
extends RefCounted

const JsonUtil := preload("res://logic/core/json_util.gd")

const LIST_PATH := "res://docs/contract/skills.json"


## where: stone, fight, duel or boss. shown: the play log's shown fields
## (PlayLog.stone_shown, fight_shown, boss_shown). answer: the right number.
static func of(where: String, shown: Dictionary, answer: int) -> String:
	if where == "boss":
		return _boss(shown)
	var q := str(shown.get("q", ""))
	var dice: Array = shown.get("dice", [])
	if q.begins_with("count"):
		return "count.to6"
	var parts := q.split(" = ")
	var left := parts[0]
	var minus := left.contains(" - ")
	var plus := left.count(" + ")
	var hidden := left.contains("?")
	var terms := 1 + plus + left.count(" - ")
	if terms >= 3:
		var top := _total(dice, left, answer, shown)
		if top > 20:
			return "add.within40"
		return "addsub3.within20" if minus else "add3.within20"
	if hidden:
		var total := int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else answer
		if minus:
			return "missing_subtrahend.within10"
		return "missing_addend.within10" if total <= 10 else "missing_addend.within20"
	if minus:
		var from := int(dice[0]) if not dice.is_empty() else answer
		return _bucket("sub", from)
	var sum := answer
	if sum > 20:
		return "add.within40"
	return _bucket("add", sum)


static func _bucket(op: String, n: int) -> String:
	if n <= 6:
		return op + ".within6"
	if n <= 10:
		return op + ".within10"
	return op + ".within20"


## The biggest running number in a three-or-more-term question.
static func _total(dice: Array, _left: String, answer: int, _shown: Dictionary) -> int:
	var s := 0
	for d in dice:
		s += int(d)
	return maxi(s, answer)


static func _boss(shown: Dictionary) -> String:
	match str(shown.get("rule", "match")):
		"sum":
			return "missing_addend.within10" if int(shown.get("target", 0)) <= 10 else "missing_addend.within20"
		"difference":
			return "missing_subtrahend.within10"
	return "numeral.match.to6"


## Every skill id in the shared list.
static func ids() -> Array:
	var data = JsonUtil.load_file(LIST_PATH)
	var out := []
	if data is Dictionary:
		for s in data.get("skills", []):
			out.append(str(s["id"]))
	return out
