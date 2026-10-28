extends RefCounted
## The Match Bounce math: which peg face a ball can pop. This is the only
## place the grade's arithmetic touches the board (plan section 07, Option A:
## match the boss's number).
##   match       Acorn. No ball die; the peg face equals the target.
##   sum         Sprout and Sapling. ball + peg = target.
##   difference  Oak. ball - peg = target.


static func peg_matches(rule: String, face: int, ball: int, target: int) -> bool:
	return face == needed_face(rule, ball, target)


## The face that pops for this ball and target (may be off the die: then
## nothing on the board is live).
static func needed_face(rule: String, ball: int, target: int) -> int:
	match rule:
		"match":
			return target
		"sum":
			return target - ball
		"difference":
			return ball - target
	push_error("BounceRules: unknown rule " + rule)
	return -1


## Ball and target for a needed face. Draw order (spec): ball die first, if
## the rule has one. Returns [ball, target].
static func roll_shot(rng, rule: String, face: int) -> Array:
	match rule:
		"match":
			return [0, face]
		"sum":
			var ball: int = rng.randi_range(1, 6)
			return [ball, ball + face]
		"difference":
			# ball - face = target >= 1, so the ball is bigger than the face.
			var ball: int = rng.randi_range(face + 1, 6)
			return [ball, ball - face]
	push_error("BounceRules: unknown rule " + rule)
	return [0, 0]


## The faces offered for "name the peg", smallest first. Acorn offers every
## face on the board (1, 2, 3). Otherwise four faces from 1 to 6: the right
## one and its neighbours, then the ball's own face, then filler, so the right
## face is not always in the middle.
static func choices(rng, rule: String, answer: int, ball: int, count: int, faces: Array) -> Array[int]:
	var out: Array[int] = []
	if rule == "match":
		out.assign(faces.duplicate())
		out.sort()
		return out
	out.append(answer)
	var near: Array[int] = []
	for v in [answer - 1, answer + 1, ball]:
		if v >= 1 and v <= 6 and not out.has(v) and not near.has(v):
			near.append(v)
	rng.shuffle(near)
	for v in near:
		if out.size() < count:
			out.append(v)
	var k := 2
	while out.size() < count and k <= 6:
		for v in [answer - k, answer + k]:
			if out.size() < count and v >= 1 and v <= 6 and not out.has(v):
				out.append(v)
		k += 1
	out.sort()
	return out
