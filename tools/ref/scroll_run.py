"""Reference scroll run, mirrors logic/path/scroll_run.gd (spec section 6)."""
from rng import SeededRng
from move_gen import generate_move

AWAIT_ROLL = "await_roll"
AWAIT_CHOICE = "await_choice"
AWAIT_FIGHT = "await_fight"
CLEARED = "cleared"
HERO_HEARTS = 3
MAX_HEARTS = 5


def chest_draw(cfg, rng):
    """One chest's gems: {common, rare, rare_in} is rare when randi_range(1, rare_in) == rare_in;
    an [lo, hi] pair draws randi_range(lo, hi)."""
    if isinstance(cfg, list):
        return rng.randi_range(cfg[0], cfg[1])
    n = cfg["rare_in"]
    return cfg["rare"] if rng.randi_range(1, n) == n else cfg["common"]


def chest_range(cfg):
    if isinstance(cfg, list):
        return cfg[0], cfg[1]
    return min(cfg["common"], cfg["rare"]), max(cfg["common"], cfg["rare"])


class ScrollRun:
    def __init__(self, area, grade, seed):
        self.area = area
        self.grade = grade
        self.seed = seed & 0xFFFFFFFF
        self.rng = SeededRng(self.seed)
        self.attempt = 1
        self.pos = 0
        self.target = 0
        self.looted = []
        self.gems = 0
        self.hearts = HERO_HEARTS
        self.hearts_taken = []
        self.rolls = 0
        self.problem = None
        self.phase = AWAIT_ROLL
        self.events = []
        self.answers = []
        if self.is_guessed():
            self._new_answers()
        else:
            self._length = area["length"]
            self.spaces = {s["at"]: s for s in area["spaces"]}

    def is_guessed(self):
        return "guesses" in self.area

    def _new_answers(self):
        top = self.grade["move"]["max_answer"]
        self.answers = [self.rng.randi_range(1, top) for _ in range(self.area["guesses"])]
        self._lay_out()

    def _lay_out(self):
        landing, at = {}, 0
        for k, a in enumerate(self.answers):
            at += a
            landing[k + 1] = at
        self._length = at
        self.spaces = {}
        for st in self.area.get("steps", []):
            n = st["after"]
            if n in landing and n < len(self.answers):
                sp = dict(st)
                sp["at"] = landing[n]
                self.spaces[landing[n]] = sp

    def length(self):
        return self._length

    def _loot_key(self, i):
        sp = self.space_at(i)
        return sp["after"] if sp is not None and "after" in sp else i

    def is_heart_taken(self, i):
        return self._loot_key(i) in self.hearts_taken

    def is_looted(self, i):
        return self._loot_key(i) in self.looted

    def space_at(self, i):
        return self.spaces.get(i)

    def current_monster(self):
        if self.phase != AWAIT_FIGHT:
            return ""
        return self.space_at(self.pos)["monster"]

    def to_save(self):
        return {"area": self.area["id"], "grade": self.grade["id"], "seed": self.seed,
                "attempt": self.attempt, "pos": self.pos, "target": self.target, "looted": list(self.looted),
                "gems": self.gems, "hearts": self.hearts, "hearts_taken": list(self.hearts_taken), "rolls": self.rolls, "phase": self.phase, "rng_state": self.rng.get_state()} | (
                    {"answers": list(self.answers)} if self.is_guessed() else {})

    @classmethod
    def from_save(cls, area, grade, data):
        run = cls(area, grade, data["seed"])
        run.attempt = data["attempt"]
        run.pos = data["pos"]
        run.target = max(run.pos, data.get("target", run.pos))
        run.looted = list(data["looted"])
        run.gems = data["gems"]
        run.hearts = max(1, min(data.get("hearts", HERO_HEARTS), MAX_HEARTS))
        run.hearts_taken = list(data.get("hearts_taken", []))
        run.rolls = data.get("rolls", 0)
        run.phase = data["phase"]
        if data["phase"] == AWAIT_CHOICE:
            run.rolls = max(0, run.rolls - 1)
            run.phase = AWAIT_ROLL
        run.rng.set_state(data["rng_state"])
        if run.is_guessed():
            run.answers = list(data["answers"])
            run._lay_out()
        return run

    def roll(self):
        assert self.phase == AWAIT_ROLL
        lo, hi = self.answer_bounds()
        if self.is_guessed():
            lo = hi = self.answers[min(self.rolls, len(self.answers) - 1)]
        self.problem = generate_move(self.grade, self.rng, self.length() - self.pos, lo, hi)
        self.rolls += 1
        self.phase = AWAIT_CHOICE
        return self.problem

    def answer_bounds(self):
        if "rolls" not in self.area:
            return 1, 0
        lo_rolls, hi_rolls = self.area["rolls"]
        top = self.grade["move"]["max_answer"]
        room = self.length() - self.pos
        left = hi_rolls - self.rolls - 1
        lo = max(1, room - top * left)
        hi = min(top, room - max(0, lo_rolls - self.rolls - 1))
        return lo, max(lo, hi)

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
        self.target = self.pos + dist
        self._walk(out)
        self._log(out)
        self.problem = None
        return out

    def resolve_fight(self, won, hearts_left=-1):
        assert self.phase == AWAIT_FIGHT
        out = {"result": "fight_won" if won else "fight_lost", "restarted": False}
        self._log(out)
        if not won:
            self._fail()
            out["restarted"] = True
            return out
        if hearts_left > 0:
            self.hearts = min(hearts_left, MAX_HEARTS)
        self.phase = AWAIT_ROLL
        if self.target > self.pos:
            w = {"result": "", "from": self.pos, "to": self.target}
            self._walk(w)
            self._log(w)
            out["walk"] = w
        return out

    def _walk(self, out):
        chests = []
        got_hearts = []
        total = 0
        self.phase = AWAIT_ROLL
        out["result"] = "hop"
        while self.pos < self.target:
            self.pos += 1
            space = self.space_at(self.pos)
            if self.pos >= self.length():
                out["result"] = "goal"
                self.phase = CLEARED
                break
            if space is not None and space["type"] == "monster":
                out["result"] = "monster"
                out["monster"] = space["monster"]
                self.phase = AWAIT_FIGHT
                break
            if space is not None and space["type"] == "chest" and not self.is_looted(self.pos):
                g = chest_draw(self.area["chest_gems"], self.rng)
                self.looted.append(self._loot_key(self.pos))
                self.gems += g
                total += g
                chests.append({"at": self.pos, "gems": g})
                if self.pos == self.target:
                    out["result"] = "chest"
            if space is not None and space["type"] == "heart" and not self.is_heart_taken(self.pos):
                self.hearts_taken.append(self._loot_key(self.pos))
                self.hearts = min(self.hearts + 1, MAX_HEARTS)
                got_hearts.append(self.pos)
                if self.pos == self.target:
                    out["result"] = "heart"
        if self.phase != AWAIT_FIGHT:
            self.target = self.pos
        out["to"] = self.pos
        out["chests"] = chests
        out["hearts"] = got_hearts
        if chests:
            out["gems"] = total

    def _fail(self):
        self.attempt += 1
        self.rolls = 0
        self.pos = 0
        self.target = 0
        self.hearts = HERO_HEARTS
        self.hearts_taken = []
        self.problem = None
        self.phase = AWAIT_ROLL
        if self.is_guessed():
            self._new_answers()

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
