"""Finds where the ambient effects sit on the existing art (2026-11-12).

Writes content/ambient_spots.json, read by game/ui/ambient.gd:
  glints:   bright crystal / gold / coin pixels that twinkle (art px of a 320x180 backdrop)
  lamps:    centres of lantern flames that flicker
  lava:     bright lava pixels where bubbles rise and pop
  tips:     stalactite tips (art px of each 240x148 ceiling piece) where drops form

    python3 tools/ambient/find_spots.py
"""
import json
import math
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")


def load(path):
    return Image.open(os.path.join(ROOT, path)).convert("RGBA")


def pixels(im, colors, box=None):
    w, h = im.size
    x0, y0, x1, y1 = box or (0, 0, w, h)
    out = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = im.getpixel((x, y))
            if a > 0 and (r, g, b) in colors:
                out.append((x, y))
    return out


def thin(points, min_d, most, seed=7):
    # a spread-out pick: walk the points in a fixed shuffled order, keep each
    # one far enough from those already kept
    pts = sorted(points, key=lambda p: (math.sin(p[0] * 12.9898 + p[1] * 78.233 + seed) * 43758.5453) % 1.0)
    kept = []
    for p in pts:
        if all((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 >= min_d * min_d for q in kept):
            kept.append(p)
            if len(kept) >= most:
                break
    return sorted(kept)


def clusters(points, gap):
    # centres of groups of touching-ish pixels
    left = set(points)
    out = []
    while left:
        seed = left.pop()
        group = [seed]
        stack = [seed]
        while stack:
            x, y = stack.pop()
            for q in list(left):
                if abs(q[0] - x) <= gap and abs(q[1] - y) <= gap:
                    left.remove(q)
                    group.append(q)
                    stack.append(q)
        if len(group) >= 6:
            out.append([round(sum(p[0] for p in group) / len(group)), round(sum(p[1] for p in group) / len(group)), len(group)])
    return sorted(out)


def tips(im, most):
    w, h = im.size
    low = []
    for x in range(w):
        bottom = -1
        for y in range(h - 1, -1, -1):
            if im.getpixel((x, y))[3] > 0:
                bottom = y
                break
        low.append(bottom)
    found = []
    for x in range(2, w - 2):
        y = low[x]
        if y < 20:
            continue
        if y >= max(low[x - 2:x + 3]) and (not found or x - found[-1][0] > 12):
            found.append([x, y])
    found.sort(key=lambda p: -p[1])
    return sorted(found[:most])


CRYSTAL_HI = {(226, 200, 255), (184, 134, 239), (244, 241, 255), (158, 230, 242)}
GOLD_HI = {(248, 236, 161), (245, 225, 170), (249, 225, 134), (251, 220, 104), (249, 227, 91),
           (245, 215, 225), (245, 179, 237), (186, 230, 236), (210, 132, 240)}
BOG_COIN = {(242, 255, 176), (200, 232, 106)}

spots = {}
spots["res://art/crystal/cave-bg.png"] = {"glints": thin(pixels(load("art/crystal/cave-bg.png"), CRYSTAL_HI), 6, 18)}
spots["res://art/crystal/fight-bg.png"] = {
    "glints": thin(pixels(load("art/crystal/fight-bg.png"), {(226, 200, 255), (244, 241, 255)}, (0, 100, 320, 180)), 8, 16),
    # the three wall lanterns (their light colour also paints the walls, so by hand)
    "lamps": [[33, 59], [208, 66], [291, 57]],
}
spots["res://art/crystal/treasure-room.png"] = {
    "glints": thin(pixels(load("art/crystal/treasure-room.png"), {(244, 241, 255), (158, 230, 242)}), 9, 22),
    "lamps": [[208, 76]],
}
spots["res://art/boss/treasure-cave.png"] = {"glints": thin(pixels(load("art/boss/treasure-cave.png"), GOLD_HI), 9, 24)}
spots["res://art/bog/treasure-room.png"] = {"glints": thin(pixels(load("art/bog/treasure-room.png"), BOG_COIN), 6, 16)}
lava_fight = load("art/lava/fight-bg.png")
spots["res://art/lava/fight-bg.png"] = {
    "lava": thin(pixels(lava_fight, {(251, 218, 88), (244, 111, 92)}, (60, 95, 300, 140)), 10, 10),
    # the lavafall on the right: x span and top/bottom (art px)
    "fall": [266, 279, 40, 99],
}
for i in range(4):
    p = "art/crystal/ceiling-%d.png" % i
    spots["res://" + p] = {"tips": tips(load(p), 3)}

out = os.path.join(ROOT, "content", "ambient_spots.json")
with open(out, "w") as f:
    json.dump(spots, f, indent=1)
for k, v in spots.items():
    print(k, {kk: len(vv) for kk, vv in v.items()}, v.get("lamps", ""), v.get("tips", ""))
