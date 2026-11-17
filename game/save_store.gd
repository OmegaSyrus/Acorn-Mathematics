## Writes the active profile's save to user:// after every task. Writes go to
## a temp file first, then replace the save, so closing mid-write can't
## corrupt it. One file per profile: user://profile_<profile id>.json
## (game/profile_store.gd keeps the roster and picks the profile).
extends RefCounted

const SaveData := preload("res://logic/core/save_data.gd")

## The version 1 profile id (one save, user://profile_1.json).
const LEGACY_PROFILE := "1"

## The profile whose save read() and write() use (ProfileStore sets it).
static var profile := LEGACY_PROFILE
## Where saves live; tests point it at a temp folder.
static var dir := "user://"


static func path_for(profile_id: String) -> String:
	return dir.path_join("profile_%s.json" % profile_id)


static func path() -> String:
	return path_for(profile)


static func read() -> Dictionary:
	return read_profile(profile)


static func read_profile(profile_id: String) -> Dictionary:
	var p := path_for(profile_id)
	var text := ""
	if FileAccess.file_exists(p):
		text = FileAccess.get_file_as_string(p)
	return SaveData.from_text(text, profile_id)


static func write(save: Dictionary) -> void:
	write_to(path_for(str(save.get("profile", profile))), SaveData.to_text(save))


## Text to a file through a temp file, so a crash never leaves half a file.
static func write_to(p: String, text: String) -> void:
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("save failed: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	DirAccess.rename_absolute(tmp, p)


static func remove_profile(profile_id: String) -> void:
	var p := path_for(profile_id)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
