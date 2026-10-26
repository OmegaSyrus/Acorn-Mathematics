import json
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))


def load(rel):
    with open(os.path.join(ROOT, rel)) as f:
        return json.load(f)


def grades():
    return {g["id"]: g for g in load("content/grades.json")["grades"]}


def area(area_id):
    return load("content/areas/%s.json" % area_id)


def stickers():
    return load("content/stickers.json")["stickers"]


IMPLEMENTED_RULES = ("single", "sum")
