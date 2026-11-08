## Move problems for the levels after Lava 1 (docs/difficulty-plan.md section
## 4.2, generator v1.2): the answer first, then a sign pattern that can make
## it, then the dice. Lava 1 keeps MoveGen's op-first draw unchanged.
##
## A pattern is a string of signs, one per die: "+" a plain die added, "-" a
## red die taken away; red dice sit at the right end ("++-").
## Draws (move config "draw"):
##   patterns  answer, then a pattern (constraints ten_pair, pairs, red_heavy,
##             across_ten), then the dice
##   hidden    one die face down; the stone to pick is its face (1 to 6) and
##             the tray shows the total
##   mix       each roll is one of the "parts" (other levels' move configs)
## Rng rules: every randi written is called, even over one value; the last die
## of a group takes what is left with no call; picking from a one-entry list
## takes it with no call.
extends RefCounted

const Rng := preload("res://logic/core/rng.gd")


static func _pick(list: Array, rng: Rng):
	if list.size() == 1:
		return list[0]
	return list[rng.randi_range(0, list.size() - 1)]


static func plain_count(p: String) -> int:
	return p.count("+")


static func red_count(p: String) -> int:
	return p.count("-")


## The red total range [lo, hi] for pattern p to make answer a, or [] if p
## can't make it. With no red dice the range is [0, 0] when k <= a <= 6k.
static func red_range(p: String, a: int, constraint := "none") -> Array:
	var k := plain_count(p)
	var j := red_count(p)
	if j == 0:
		if constraint == "across_ten":
			return []
		return [0, 0] if a >= k and a <= 6 * k else []
	var lo := maxi(j, k - a)
	if constraint == "across_ten":
		lo = maxi(lo, 11 - a)
	var hi := mini(6 * j, 6 * k - a)
	return [lo, hi] if lo <= hi else []


static func can_make(p: String, a: int, constraint := "none") -> bool:
	return not red_range(p, a, constraint).is_empty()


## The patterns a roll is drawn from (red_heavy lists each red one twice).
static func pattern_list(move: Dictionary) -> Array:
	var out := []
	var heavy: bool = move.get("constraint", "none") == "red_heavy"
	for p in move.get("patterns", []):
		out.append(p)
		if heavy and red_count(p) > 0:
			out.append(p)
	return out


## Hidden-die options expanded: [[pattern, place], ...].
static func hidden_options(move: Dictionary) -> Array:
	var out := []
	for o in move.get("options", []):
		var p: String = o[0]
		if o[1] == "any":
			for i in p.length():
				out.append([p, i])
		else:
			out.append([p, p.length() - 1])
	return out


static func _hidden_can(opt: Array, a: int) -> bool:
	var p: String = opt[0]
	if a < 1 or a > 6:
		return false
	if p[opt[1]] == "+":
		return true
	# a red hidden die: the plain dice must be able to stay above it
	return a <= 6 * plain_count(p) - red_count(p)


## Every answer from min_answer to m that this move config can make.
static func answers(move: Dictionary, m := 999) -> Array:
	var top := mini(int(move["max_answer"]), m)
	var out := []
	for a in range(int(move.get("min_answer", 1)), top + 1):
		if can_answer(move, a):
			out.append(a)
	return out


static func can_answer(move: Dictionary, a: int) -> bool:
	match move["draw"]:
		"patterns":
			var c: String = move.get("constraint", "none")
			for p in move["patterns"]:
				if can_make(p, a, c):
					return true
		"hidden":
			for o in hidden_options(move):
				if _hidden_can(o, a):
					return true
		"mix":
			for part in move["part_moves"]:
				if a <= int(part["max_answer"]) and can_answer(part, a):
					return true
	return false


## One answer for a guess, evenly from what the level can make.
static func draw_answer(move: Dictionary, rng: Rng) -> int:
	return int(_pick(answers(move), rng))


## The roll for a known answer. m: how many stones are offered (choices 1..m).
static func generate_for(level: Dictionary, rng: Rng, answer: int, m: int) -> Dictionary:
	var move: Dictionary = level["move"]
	var out := _draw(move, rng, answer)
	m = maxi(m, answer)
	var choices := []
	for d in range(1, m + 1):
		choices.append(d)
	out["kind"] = "move"
	out["grade"] = level["id"]
	out["answer"] = answer
	out["choices"] = choices
	out["answer_index"] = answer - 1
	return out


static func _draw(move: Dictionary, rng: Rng, answer: int) -> Dictionary:
	match move["draw"]:
		"patterns":
			return _draw_patterns(move, rng, answer)
		"hidden":
			return _draw_hidden(move, rng, answer)
		"mix":
			var parts := []
			for part in move["part_moves"]:
				if answer <= int(part["max_answer"]) and can_answer(part, answer):
					parts.append(part)
			return _draw(_pick(parts, rng), rng, answer)
	push_error("LevelGen: unknown draw " + str(move["draw"]))
	return {}


static func _draw_patterns(move: Dictionary, rng: Rng, answer: int) -> Dictionary:
	var c: String = move.get("constraint", "none")
	var pats := []
	for p in pattern_list(move):
		if can_make(p, answer, c):
			pats.append(p)
	if pats.is_empty():
		push_error("LevelGen: no pattern makes %d" % answer)
		return {}
	var p: String = _pick(pats, rng)
	var k := plain_count(p)
	var j := red_count(p)
	var red_total := 0
	if j > 0:
		var r := red_range(p, answer, c)
		red_total = rng.randi_range(r[0], r[1])
	var plain_total := answer + red_total
	var plain := []
	if c == "ten_pair" and k >= 2 and _splittable(plain_total - 10, k - 2):
		if rng.randi_range(0, 1) == 1:
			var first := rng.randi_range(4, 6)
			plain = [first, 10 - first]
	elif c == "pairs" and k >= 2:
		var xs := []
		for x in range(1, 7):
			if _splittable(plain_total - 2 * x, k - 2):
				xs.append(x)
		if not xs.is_empty() and rng.randi_range(0, 1) == 1:
			var x: int = _pick(xs, rng)
			plain = [x, x]
	var used := 0
	for d in plain:
		used += d
	plain.append_array(split(plain_total - used, k - plain.size(), rng))
	var dice := plain + split(red_total, j, rng)
	return {"op": "sub" if j > 0 else "add", "signs": p, "dice": dice}


## Can `count` dice (1 to 6 each) add to `total`? Zero dice make only 0.
static func _splittable(total: int, count: int) -> bool:
	if count == 0:
		return total == 0
	return total >= count and total <= 6 * count


## Splits total over count dice, left to right; the last takes the rest.
static func split(total: int, count: int, rng: Rng) -> Array:
	var out := []
	var rest := total
	for i in count:
		var left := count - i - 1
		if left == 0:
			out.append(rest)
		else:
			var d := rng.randi_range(maxi(1, rest - 6 * left), mini(6, rest - left))
			out.append(d)
			rest -= d
	return out


static func _draw_hidden(move: Dictionary, rng: Rng, answer: int) -> Dictionary:
	var opts := []
	for o in hidden_options(move):
		if _hidden_can(o, answer):
			opts.append(o)
	var opt: Array = _pick(opts, rng)
	var p: String = opt[0]
	var place: int = opt[1]
	var dice := []
	var total := 0
	while true:
		dice = []
		for i in p.length():
			dice.append(answer if i == place else rng.randi_range(1, 6))
		total = 0
		var ok := true
		for i in p.length():
			total += dice[i] if p[i] == "+" else -dice[i]
			if total < 1 and i > 0:
				ok = false
		if ok and total >= 1:
			break
	return {"op": "sub" if red_count(p) > 0 else "add", "signs": p, "dice": dice,
			"hidden": place, "total": total}
