## What this game version offers parents (family.manifest v1,
## docs/contract/schemas/manifest.v1.schema.json), built from content. The
## parent app draws controls, names and skill lists from it.
##
## Level and world unlocks are left out on purpose: parents do not move
## children through the game (Terrence, 2026-11-16). Settings stays empty
## until a build can apply one (time limits come with the reports thread);
## each setting then names the version code it arrived in.
extends RefCounted

const BuildInfo := preload("res://logic/core/build_info.gd")
const Content := preload("res://logic/core/content.gd")
const Profiles := preload("res://logic/core/profiles.gd")
const Skills := preload("res://logic/core/skills.gd")

## Settings this build applies (none yet). Shape: {key, type, default,
## label, since_code, min?, max?, help?}.
const SETTINGS := []


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
	return {"schema": "family.manifest", "v": 1, "game": BuildInfo.GAME, "title": BuildInfo.TITLE,
			"app": BuildInfo.APP, "code": BuildInfo.CODE, "cv": BuildInfo.cv(), "settings": SETTINGS.duplicate(true),
			"skills": Skills.ids(), "labels": labels, "levels": levels, "pictures": Profiles.PICTURES.duplicate()}
