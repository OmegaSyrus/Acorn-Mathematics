extends RefCounted
## Players for the fight tests. Each bot looks at the attack and returns the
## index it taps. "random" and "perfect" are the gate bots from the plan;
## the others try simple patterns a child might stumble on, so we can see
## that the answer's position gives nothing away.

const Fight = preload("res://logic/fight/fight.gd")

const NAMES := ["random", "perfect", "biggest", "smallest", "middle_of_run", "not_middle"]


static func pick(bot: String, attack, rng) -> int:
	var c: Array = attack.choices
	match bot:
		"perfect":
			return attack.answer_index
		"biggest":
			return c.find(c.max())
		"smallest":
			return c.find(c.min())
		"middle_of_run":
			# Tap a number whose neighbours on both sides are also choices.
			var hits: Array[int] = []
			for i in c.size():
				if c.has(c[i] - 1) and c.has(c[i] + 1):
					hits.append(i)
			if not hits.is_empty():
				return hits[rng.randi_range(0, hits.size() - 1)]
			return rng.randi_range(0, c.size() - 1)
		"not_middle":
			# The opposite hunch: never tap a number boxed in by its neighbours.
			var free: Array[int] = []
			for i in c.size():
				if not (c.has(c[i] - 1) and c.has(c[i] + 1)):
					free.append(i)
			if not free.is_empty():
				return free[rng.randi_range(0, free.size() - 1)]
			return rng.randi_range(0, c.size() - 1)
		_:
			return rng.randi_range(0, c.size() - 1)


## Plays a whole fight. Returns true if the hero won.
static func play(fight, bot: String, bot_rng) -> bool:
	while true:
		var out: Dictionary = fight.choose(pick(bot, fight.attack, bot_rng))
		if out.state == Fight.State.WON:
			return true
		if out.state == Fight.State.LOST:
			return false
		fight.next_exchange()
	return false
