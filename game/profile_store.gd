## The roster of who plays on this device (user://profiles.json,
## logic/core/profiles.gd) and the move from one save to one per profile.
##
## First launch of this build on a tablet that has a version 1 save
## (user://profile_1.json): the roster is made with one profile, a new random
## id, and the old save moves to that profile's file. profile_1.json is
## renamed profile_1.v1.json and kept.
extends RefCounted

const Profiles := preload("res://logic/core/profiles.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const SaveStore := preload("res://game/save_store.gd")

static var roster := {}


static func path() -> String:
	return SaveStore.dir.path_join("profiles.json")


## Reads the roster (making it, and moving an old save in, the first time)
## and points SaveStore at the active profile.
static func load_roster() -> Dictionary:
	var text := FileAccess.get_file_as_string(path()) if FileAccess.file_exists(path()) else ""
	var r := Profiles.from_text(text)
	if r.is_empty():
		r = Profiles.new_roster(_now())
		_move_legacy_save(str(Profiles.active(r)["id"]))
		roster = r
		write()
	roster = r
	SaveStore.profile = str(Profiles.active(roster)["id"])
	return roster


static func write() -> void:
	SaveStore.write_to(path(), Profiles.to_text(roster))


static func use(profile_id: String) -> bool:
	if not Profiles.set_active(roster, profile_id):
		return false
	SaveStore.profile = profile_id
	write()
	return true


static func active() -> Dictionary:
	return Profiles.active(roster)


## Removes a profile and its save file.
static func remove(profile_id: String) -> bool:
	if not Profiles.remove(roster, profile_id):
		return false
	SaveStore.remove_profile(profile_id)
	SaveStore.profile = str(Profiles.active(roster)["id"])
	write()
	return true


static func _move_legacy_save(new_id: String) -> void:
	var old := SaveStore.path_for(SaveStore.LEGACY_PROFILE)
	if not FileAccess.file_exists(old) or FileAccess.file_exists(SaveStore.path_for(new_id)):
		return
	var save := SaveData.from_text(FileAccess.get_file_as_string(old), new_id)
	SaveStore.write_to(SaveStore.path_for(new_id), SaveData.to_text(save))
	var kept := SaveStore.dir.path_join("profile_1.v1.json")
	if FileAccess.file_exists(kept):
		DirAccess.remove_absolute(kept)
	DirAccess.rename_absolute(old, kept)


static func _now() -> int:
	return int(Time.get_unix_time_from_system())
