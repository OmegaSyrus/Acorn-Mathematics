"""Bot players. Inputs are recorded so runs can be replayed in Godot/C++."""
from rng import SeededRng


def play(run, policy, bot_rng, max_inputs=10000):
    """Drive run until cleared or its first restart. Returns (cleared, inputs)."""
    inputs = []
    start_attempt = run.attempt
    while run.phase != "cleared" and run.attempt == start_attempt and len(inputs) < max_inputs:
        if run.phase == "await_chest":
            open_it = True if policy == "perfect" else bot_rng.randi_range(0, 1) == 1
            inputs.append("open" if open_it else "walk")
            run.decide_chest(open_it)
        elif run.phase == "await_roll":
            inputs.append("roll")
            run.roll()
        elif run.phase == "await_choice":
            n = len(run.problem["choices"])
            i = run.problem["answer_index"] if policy == "perfect" else bot_rng.randi_range(0, n - 1)
            inputs.append("pick:%d" % i)
            run.choose(i)
        else:
            raise RuntimeError("bots cannot play phase " + run.phase)
    return run.phase == "cleared", inputs


def apply_input(run, inp):
    if inp == "open":
        return run.decide_chest(True)
    if inp == "walk":
        return run.decide_chest(False)
    if inp == "roll":
        return run.roll()
    if inp.startswith("pick:"):
        return run.choose(int(inp[5:]))
    raise ValueError(inp)
