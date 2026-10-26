"""Reference area run, mirrors logic/path/area_run.gd (spec/logic-spec.md)."""
from rng import SeededRng
from generator import generate

AWAIT_CHEST = "await_chest"
AWAIT_ROLL = "await_roll"
AWAIT_CHOICE = "await_choice"
AWAIT_FIGHT = "await_fight"
CLEARED = "cleared"


class AreaRun:
    def __init__(self, area, grade, stickers, seed):
        self.area = area
        self.grade = grade
        self.stickers = stickers
        self.seed = seed & 0xFFFFFFFF
        self.rng = SeededRng(self.seed)
        self.attempt = 1
        self.task_index = 0
        self.problem = None
        self.phase = None
        self.events = []
        self._enter_task()

    # --- save and resume -------------------------------------------------
    def to_save(self):
        return {"area": self.area["id"], "grade": self.grade["id"], "seed": self.seed,
                "attempt": self.attempt, "task_index": self.task_index,
                "rng_state": self.rng.get_state()}

    @classmethod
    def from_save(cls, area, grade, stickers, data):
        run = cls(area, grade, stickers, data["seed"])
        run.attempt = data["attempt"]
        run.task_index = data["task_index"]
        run.rng.set_state(data["rng_state"])
        run._enter_task()
        return run

    # --- queries ---------------------------------------------------------
    def task_count(self):
        return len(self.area["tasks"])

    def current_monster(self):
        if self.phase != AWAIT_FIGHT:
            return ""
        task = self.current_task()
        return "mimic" if task["type"] == "chest" else str(task.get("monster", ""))

    def current_task(self):
        if self.task_index >= self.task_count():
            return None
        return self.area["tasks"][self.task_index]

    # --- inputs ----------------------------------------------------------
    def decide_chest(self, open_it):
        assert self.phase == AWAIT_CHEST
        if open_it:
            self.phase = AWAIT_ROLL
            return {"result": "chest_try"}
        out = {"result": "walk_past"}
        self._log(out)
        self._complete(out)
        return out

    def roll(self):
        assert self.phase == AWAIT_ROLL
        self.problem = generate(self.current_task()["type"], self.grade, self.rng)
        self.phase = AWAIT_CHOICE
        return self.problem

    def choose(self, index):
        assert self.phase == AWAIT_CHOICE
        p = self.problem
        assert 0 <= index < len(p["choices"])
        right = index == p["answer_index"]
        kind = p["kind"]
        out = {"result": "", "right": right, "pick": index}
        if kind == "chest" and self.current_task().get("mimic", False):
            out["result"] = "mimic"
            out["first_strike"] = right
            self._log(out)
            self.problem = None
            self.phase = AWAIT_FIGHT
            out["cleared"] = False
            out["restarted"] = False
        elif kind == "chest":
            if right:
                out["result"] = "chest_open"
                out["sticker"] = self.stickers[self.rng.randi_range(0, len(self.stickers) - 1)]
            else:
                out["result"] = "chest_shut"
            self._log(out)
            self._complete(out)
        elif right:
            out["result"] = "door_open" if kind == "door" else "hop"
            self._log(out)
            self._complete(out)
        else:
            out["result"] = "trap" if kind == "door" else "fall"
            self._log(out)
            self._fail(out)
        return out

    def resolve_fight(self, won):
        assert self.phase == AWAIT_FIGHT
        out = {"result": "fight_won" if won else "fight_lost"}
        self._log(out)
        if won:
            self._complete(out)
        else:
            self._fail(out)
        return out

    # --- internals -------------------------------------------------------
    def _enter_task(self):
        self.problem = None
        task = self.current_task()
        if task is None:
            self.phase = CLEARED
        elif task["type"] == "chest":
            self.phase = AWAIT_CHEST
        elif task["type"] == "fight":
            self.phase = AWAIT_FIGHT
        else:
            self.phase = AWAIT_ROLL

    def _complete(self, out):
        self.task_index += 1
        self._enter_task()
        out["cleared"] = self.phase == CLEARED
        out["restarted"] = False

    def _fail(self, out):
        self.attempt += 1
        self.task_index = 0
        self._enter_task()
        out["cleared"] = False
        out["restarted"] = True

    def _log(self, out):
        e = {"attempt": self.attempt, "task": self.task_index,
             "type": self.current_task()["type"], "result": out["result"]}
        if self.problem is not None:
            e["dice"] = list(self.problem["dice"])
            e["choices"] = list(self.problem["choices"])
            e["pick"] = out["pick"]
        if "sticker" in out:
            e["sticker"] = out["sticker"]
        self.events.append(e)
