## Bot players, mirroring tools/ref/bots.py. The random bot draws from its
## own SeededRng, so its inputs are reproducible too.
extends RefCounted

const Rng := preload("res://logic/core/rng.gd")
const AreaRun := preload("res://logic/path/area_run.gd")


## Plays until the area is cleared or restarts. Returns {cleared, inputs}.
static func play(run: AreaRun, policy: String, bot_rng: Rng, max_inputs: int = 10000) -> Dictionary:
	var inputs := []
	var start_attempt := run.attempt
	while run.phase != AreaRun.CLEARED and run.attempt == start_attempt and inputs.size() < max_inputs:
		if run.phase == AreaRun.AWAIT_CHEST:
			var open_it := policy == "perfect" or bot_rng.randi_range(0, 1) == 1
			inputs.append("open" if open_it else "walk")
			run.decide_chest(open_it)
		elif run.phase == AreaRun.AWAIT_ROLL:
			inputs.append("roll")
			run.roll()
		elif run.phase == AreaRun.AWAIT_CHOICE:
			var n: int = run.problem["choices"].size()
			var i: int = run.problem["answer_index"] if policy == "perfect" else bot_rng.randi_range(0, n - 1)
			inputs.append("pick:%d" % i)
			run.choose(i)
		else:
			push_error("bots cannot play phase " + run.phase)
			break
	return {"cleared": run.phase == AreaRun.CLEARED, "inputs": inputs}


static func apply_input(run: AreaRun, inp: String) -> void:
	if inp == "open":
		run.decide_chest(true)
	elif inp == "walk":
		run.decide_chest(false)
	elif inp == "roll":
		run.roll()
	elif inp.begins_with("pick:"):
		run.choose(inp.substr(5).to_int())
	else:
		push_error("unknown input " + inp)
