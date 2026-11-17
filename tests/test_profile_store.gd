## The move from one save to one per profile (game/profile_store.gd), in a
## temp folder: a version 1 tablet keeps everything.
extends "res://tests/support/test_case.gd"

const ProfileStore := preload("res://game/profile_store.gd")
const SaveStore := preload("res://game/save_store.gd")
const Profiles := preload("res://logic/core/profiles.gd")
const SaveData := preload("res://logic/core/save_data.gd")


func _temp_dir() -> String:
	var d := OS.get_temp_dir().path_join("acorn_profiles_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _cleanup(d: String) -> void:
	for f in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	DirAccess.remove_absolute(d)


func _with_dir(f: Callable) -> void:
	var was_dir := SaveStore.dir
	var was_profile := SaveStore.profile
	var was_roster := ProfileStore.roster
	var d := _temp_dir()
	SaveStore.dir = d
	f.call(d)
	SaveStore.dir = was_dir
	SaveStore.profile = was_profile
	ProfileStore.roster = was_roster
	_cleanup(d)


func test_version_1_tablet_moves_in() -> bool:
	_with_dir(func(d: String):
		var f := FileAccess.open(d.path_join("profile_1.json"), FileAccess.WRITE)
		f.store_string('{"version": 1, "profile": "1", "stickers": [], "gems": 40, "marks": {"lava_caves": [1, 12]}, "run": null}')
		f.close()
		var r := ProfileStore.load_roster()
		var id: String = Profiles.active(r)["id"]
		check(id.begins_with("p_"), "a random profile id")
		eq(SaveStore.profile, id, "saves go to the new profile")
		check(FileAccess.file_exists(d.path_join("profile_%s.json" % id)), "the save moved")
		check(not FileAccess.file_exists(d.path_join("profile_1.json")), "the old name is gone")
		check(FileAccess.file_exists(d.path_join("profile_1.v1.json")), "the old file is kept aside")
		var s := SaveStore.read()
		eq(s["gems"], 40, "gems kept")
		eq(s["marks"], {"lava_caves": [1, 12]}, "marks kept")
		eq(s["version"], 2, "now version 2")
		# a second launch finds the roster and the same profile
		ProfileStore.roster = {}
		eq(Profiles.active(ProfileStore.load_roster())["id"], id, "same profile next launch"))
	return true


func test_new_tablet_and_switching() -> bool:
	_with_dir(func(d: String):
		var r := ProfileStore.load_roster()
		var first: String = Profiles.active(r)["id"]
		var s := SaveStore.read()
		SaveData.add_gems(s, 5)
		SaveStore.write(s)
		var b := Profiles.add_child(r, 1)
		ProfileStore.write()
		check(ProfileStore.use(b["id"]), "switch")
		eq(SaveStore.read()["gems"], 0, "the second child starts fresh")
		check(ProfileStore.use(first), "switch back")
		eq(SaveStore.read()["gems"], 5, "the first child's gems are still there")
		check(ProfileStore.remove(b["id"]), "remove the second")
		check(not FileAccess.file_exists(SaveStore.path_for(b["id"])), "its save went too")
		check(not ProfileStore.remove(first), "the last child stays"))
	return true
