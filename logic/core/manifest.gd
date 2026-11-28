## What this game version offers parents (family.manifest v1,
## docs/contract/schemas/manifest.v1.schema.json), built from content. The
## parent app draws controls, names and skill lists from it.
##
## Level and world unlocks are left out on purpose: parents do not move
## children through the game (Terrence, 2026-11-16). Each setting names the
## version code it arrived in; the family add-on (addons/acorn_family,
## family_limits.gd) applies them.
extends RefCounted

const BuildInfo := preload("res://logic/core/build_info.gd")
const Content := preload("res://logic/core/content.gd")
const Store := preload("res://logic/core/store.gd")
const Profiles := preload("res://logic/core/profiles.gd")
const Skills := preload("res://logic/core/skills.gd")

## The version code the time limits arrive in (the build after 0.29.0 / 48).
const LIMITS_SINCE := 49
## Settings this build applies. Shape: {key, type, default, label,
## since_code, min?, max?, help?, scope?}. Both are per child per game
## (scope child_game) and enforced on the tablet: daily_minutes 0 means no
## limit, a null bedtime means none (night runs from bedtime to 05:00).
const SETTINGS := [
	{"key": "daily_minutes", "type": "int", "min": 0, "max": 240, "default": 0, "label": "Minutes a day",
			"help": "Play stops gently after this many minutes each day. 0 means no limit.",
			"since_code": LIMITS_SINCE, "scope": "child_game"},
	{"key": "bedtime", "type": "time", "default": null, "label": "Bedtime",
			"help": "No play from this time until the morning. Empty means none.",
			"since_code": LIMITS_SINCE, "scope": "child_game"},
]


static func build() -> Dictionary:
	var labels := {}
	for w in Content.worlds():
		labels[str(w["id"])] = str(w["name"])
	var levels := []
	var by_id := Content.levels()
	var ids := by_id.keys()
	ids.sort()
	for id in ids:
		levels.append({"id": int(id), "world": str(by_id[id]["world"]), "num": int(by_id[id]["num"])})
	# the profile pictures' display names: each hero's shop name (Bolt, Blaze, ...)
	var picture_labels := {}
	var cat := Store.catalog()
	for id in Profiles.PICTURES:
		var it := Store.item(cat, id)
		if not it.is_empty():
			picture_labels[id] = str(it.get("name", id))
	return {"schema": "family.manifest", "v": 1, "game": BuildInfo.GAME, "title": BuildInfo.TITLE,
			"app": BuildInfo.APP, "code": BuildInfo.CODE, "cv": BuildInfo.cv(), "settings": SETTINGS.duplicate(true),
			"skills": Skills.ids(), "labels": labels, "levels": levels, "pictures": Profiles.PICTURES.duplicate(),
			"picture_labels": picture_labels}
