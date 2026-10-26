"""Reference scroll run, mirrors logic/path/scroll_run.gd (spec section 6)."""
from rng import SeededRng
from move_gen import generate_move

AWAIT_ROLL = "await_roll"
AWAIT_CHOICE = "await_choice"
AWAIT_FIGHT = "await_fight"
CLEARED = "cleared"


class ScrollRun:
    def __init__(self, area, grade, seed):
        self.area = area
        self.grade = grade
        self.seed = seed & 0xFFFFFFFF
        self.rng = SeededRng(self.seed)
        self.attempt = 1
        self.pos = 0
        self.looted = []
        self.gems = 0
        self.problem = None
        self.phase = AWAIT_ROLL
        self.events = []
        self.spaces = {s["at"]: s for s in area["spaces"]}

    def length(self):
        return self.area["length"]

    def space_at(self, i):
        return self.spaces.get(i)

    def current_monster(self):
        if self.phase != AWAIT_FIGHT:
            return ""
        return self.space_at(self.pos)["monster"]

    def to_save(self):
        return {"area": self.area["id"], "grade": self.grade["id"], "seed": self.seed,
                "attempt": self.attempt, "pos": self.pos, "looted": list(self.looted),
                "gems": self.gems, "phase": self.phase, "rng_state": self.rng.get_state()}

    @classmethod
    def from_save(cls, area, grade, data):
        run = cls(area, grade, data["seed"])
        run.attempt = data["attempt"]
        run.pos = data["pos"]
        run.looted = list(data["looted"])
        run.gems = data["gems"]
        run.phase = data["phase"]
        run.rng.set_state(data["rng_state"])
        return run

    def roll(self):
        assert self.phase == AWAIT_ROLL
        self.problem = generate_move(self.grade, self.rng, self.length() - self.pos)
        self.phase = AWAIT_CHOICE
        return self.problem

    def choose(self, index):
        assert self.phase == AWAIT_CHOICE
        p = self.problem
        assert 0 <= index < len(p["choices"])
        dist = p["choices"][index]
        right = index == p["answer_index"]
        out = {"result": "", "right": right, "pick": index, "from": self.pos,
               "to": self.pos + dist, "restarted": False}
        if not right:
            out["result"] = "sink"
            self._log(out)
            self._fail()
            out["restarted"] = True
            return out
        self.pos += dist
        space = self.space_at(self.pos)
        self.phase = AWAIT_ROLL
        if self.pos >= self.length():
            out["result"] = "goal"
            self.phase = CLEARED
        elif space is not None and space["type"] == "monster":
            out["result"] = "monster"
            out["monster"] = space["monster"]
            self.phase = AWAIT_FIGHT
        elif space is not None and space["type"] == "chest" and self.pos not in self.looted:
            lo, hi = self.area["chest_gems"]
            out["result"] = "chest"
            out["gems"] = self.rng.randi_range(lo, hi)
            self.looted.append(self.pos)
            self.gems += out["gems"]
        else:
            out["result"] = "hop"
        self._log(out)
        self.problem = None
        return out

    def resolve_fight(self, won):
        assert self.phase == AWAIT_FIGHT
        out = {"result": "fight_won" if won else "fight_lost", "restarted": False}
        self._log(out)
        if won:
            self.phase = AWAIT_ROLL
        else:
            self._fail()
            out["restarted"] = True
        return out

    def _fail(self):
        self.attempt += 1
        self.pos = 0
        self.problem = None
        self.phase = AWAIT_ROLL

    def _log(self, out):
        e = {"attempt": self.attempt, "pos": self.pos, "result": out["result"]}
        if self.problem is not None:
            e["op"] = self.problem["op"]
            e["dice"] = list(self.problem["dice"])
            e["pick"] = out["pick"]
        if "gems" in out:
            e["gems"] = out["gems"]
        self.events.append(e)


def play_scroll(run, policy, bot_rng, max_inputs=20000):
    """Drive until cleared or the first restart. Fights: perfect wins, random
    wins when its bot rng says so (1 in 10). Returns (cleared, inputs)."""
    inputs = []
    start = run.attempt
    while run.phase != CLEARED and run.attempt == start and len(inputs) < max_inputs:
        if run.phase == AWAIT_ROLL:
            inputs.append("roll")
            run.roll()
        elif run.phase == AWAIT_CHOICE:
            n = len(run.problem["choices"])
            i = run.problem["answer_index"] if policy == "perfect" else bot_rng.randi_range(0, n - 1)
            inputs.append("pick:%d" % i)
            run.choose(i)
        else:
            won = policy == "perfect" or bot_rng.randi_range(0, 9) == 0
            inputs.append("win" if won else "lose")
            run.resolve_fight(won)
    return run.phase == CLEARED, inputs


def apply_scroll_input(run, inp):
    if inp == "roll":
        return run.roll()
    if inp == "win":
        return run.resolve_fight(True)
    if inp == "lose":
        return run.resolve_fight(False)
    if inp.startswith("pick:"):
        return run.choose(int(inp[5:]))
    raise ValueError(inp)
