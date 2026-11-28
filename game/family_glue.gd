## The game's side of the family add-on (addons/acorn_family): the hooks
## Family.configure() takes, built from this game's stores. main.gd passes
## two callables for the save it holds in memory (the player's), so a
## restore of the player updates what the screens use.
extends RefCounted

const BuildInfo := preload("res://logic/core/build_info.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const SaveStore := preload("res://game/save_store.gd")
const ProfileStore := preload("res://game/profile_store.gd")
const PlayLog := preload("res://game/play_log.gd")


## get_save: () -> the player's save; set_save: (save) replaces it and writes it.
static func hooks(dev: String, get_save: Callable, set_save: Callable) -> Dictionary:
	return {
		"game": BuildInfo.GAME, "dev": dev, "app": BuildInfo.APP, "code": BuildInfo.CODE,
		"roster": roster,
		"active_profile": active_profile,
		"read_save": read_save.bind(get_save),
		"write_save": write_save.bind(set_save),
		"snapshot": snapshot,
		"merge": merge,
		"saved_at": saved_at,
		"log_files": log_files,
		"last_seq": last_seq,
		"keep_log_after": keep_log_after,
	}


static func active_profile() -> String:
	return SaveStore.profile


## The player's save comes from memory (it is the newest), anyone else's from their file.
static func read_save(profile: String, get_save: Callable) -> Dictionary:
	if profile == SaveStore.profile:
		return (get_save.call() as Dictionary).duplicate(true)
	return SaveStore.read_profile(profile)


static func write_save(profile: String, merged: Dictionary, set_save: Callable) -> void:
	keep_copy(profile)
	merged["profile"] = profile
	if profile == SaveStore.profile:
		set_save.call(merged)
	else:
		SaveStore.write(merged)


static func snapshot(save: Dictionary, dev: String, rev: int, now: int, child: Variant) -> Dictionary:
	return SaveData.snapshot(save, dev, rev, now, child)


static func merge(snaps: Array, profile: String, local: Dictionary) -> Dictionary:
	return SaveData.merge(snaps, profile, local.get("run"))


static func log_files() -> Array:
	return PlayLog.log_files(PlayLog.path)


static func last_seq() -> int:
	return PlayLog.seq


static func keep_log_after(n: int) -> void:
	PlayLog.keep_after = n


static func roster() -> Array:
	var out := []
	var r: Dictionary = ProfileStore.roster
	for p in r.get("profiles", []):
		out.append({"id": str(p["id"]), "nickname": str(p["nickname"]), "picture": str(p["picture"]),
				"guest": bool(p.get("guest", false))})
	return out


## When the local save was written, for the merge's "newest wins" picks
## (hero, dice, Level). A save with nothing earned yet counts as oldest, so
## a new tablet takes the child's picks from their other tablets.
static func saved_at(profile: String) -> int:
	var save := SaveStore.read_profile(profile)
	if is_blank(save):
		return 0
	var p := SaveStore.path_for(profile)
	return int(FileAccess.get_modified_time(p)) if FileAccess.file_exists(p) else 0


static func is_blank(save: Dictionary) -> bool:
	return (save.get("marks", {}) as Dictionary).is_empty() and (save.get("stickers", []) as Array).is_empty() \
			and (save.get("owned", []) as Array).is_empty() and int(save.get("gems", 0)) == 0


## Before a restore writes a save: the old file is kept beside it
## (profile_<id>.before_restore.json), so nothing local is ever lost.
static func keep_copy(profile: String) -> void:
	var p := SaveStore.path_for(profile)
	if FileAccess.file_exists(p):
		var copy := p.get_basename() + ".before_restore.json"
		if FileAccess.file_exists(copy):
			DirAccess.remove_absolute(copy)
		DirAccess.copy_absolute(p, copy)
