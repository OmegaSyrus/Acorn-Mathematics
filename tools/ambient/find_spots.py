"""Finds where the ambient effects sit on the existing art (2026-11-12).

Writes content/ambient_spots.json, read by game/ui/ambient.gd:
  glints:   bright crystal / gold / coin pixels that twinkle (art px of a 480x270 backdrop)
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


# Since the art grid plan (2026-11-24) the backdrops are 480x270 PixelLab Pro
# pictures with many shades, so spots are picked by colour tests, not exact
# palette entries. Coordinates are art pixels of the 480x270 backdrop.

def where(im, test, box=None):
    w, h = im.size
    x0, y0, x1, y1 = box or (0, 0, w, h)
    out = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = im.getpixel((x, y))
            if a > 0 and test(r, g, b):
                out.append((x, y))
    return out


def crystal(r, g, b):  # bright violet, ice blue or white crystal highlights
    return max(r, g, b) >= 225 and b >= 200 and b >= g


def gold(r, g, b):  # bright coin and gem highlights
    return r >= 235 and g >= 200 and b <= 170


def warm_light(r, g, b):  # lantern flames
    return r >= 245 and g >= 215 and b >= 120


def lava_hot(r, g, b):  # the brightest lava
    return r >= 250 and 150 <= g <= 235 and b <= 120


def pale_coin(r, g, b):  # the brightest bits of the Bog hoard (old brass and silver)
    return r + g + b >= 500


spots = {}
spots["res://art/crystal/cave-bg.png"] = {"glints": thin(where(load("art/crystal/cave-bg.png"), crystal), 9, 18)}
crystal_fight = load("art/crystal/fight-bg.png")
spots["res://art/crystal/fight-bg.png"] = {
    "glints": thin(where(crystal_fight, crystal, (0, 150, 480, 270)), 12, 16),
    "lamps": [c[:2] for c in clusters(where(crystal_fight, warm_light, (0, 0, 480, 200)), 2)][:4],
}
crystal_treasure = load("art/crystal/treasure-room.png")
spots["res://art/crystal/treasure-room.png"] = {
    "glints": thin(where(crystal_treasure, crystal), 13, 22),
    "lamps": [c[:2] for c in clusters(where(crystal_treasure, warm_light, (0, 0, 480, 200)), 2)][:1],
}
spots["res://art/boss/treasure-cave.png"] = {"glints": thin(where(load("art/boss/treasure-cave.png"), gold), 13, 24)}
spots["res://art/bog/treasure-room.png"] = {"glints": thin(where(load("art/bog/treasure-room.png"), pale_coin, (40, 110, 320, 230)), 9, 16)}
lava_fight = load("art/lava/fight-bg.png")
fall = where(lava_fight, lava_hot, (400, 40, 460, 200))
spots["res://art/lava/fight-bg.png"] = {
    "lava": thin(where(lava_fight, lava_hot, (120, 160, 400, 215)), 15, 10),
    # the lavafall on the right: x span and top/bottom (art px)
    "fall": [min(p[0] for p in fall), max(p[0] for p in fall), min(p[1] for p in fall), max(p[1] for p in fall)] if fall else [420, 432, 60, 190],
}
for i in range(4):
    p = "art/crystal/ceiling-%d.png" % i
    spots["res://" + p] = {"tips": tips(load(p), 3)}

out = os.path.join(ROOT, "content", "ambient_spots.json")
with open(out, "w") as f:
    json.dump(spots, f, indent=1)
for k, v in spots.items():
    print(k, {kk: len(vv) for kk, vv in v.items()}, v.get("lamps", ""), v.get("tips", ""))
