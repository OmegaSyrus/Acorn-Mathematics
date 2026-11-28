## What main.gd does with the create and edit screen's signals (profile plan
## S2 and S4, game/profile_edit_screen.gd, which only emits): the roster
## changes and file writes, kept here so tests can drive them without the
## screens. Works on ProfileStore.roster.
extends RefCounted

const Profiles := preload("res://logic/core/profiles.gd")
const ProfileStore := preload("res://game/profile_store.gd")


## The create flow's "Yes". On a fresh install (first_run) the first child
## takes the name and picture (blanks keep "Player 1"); otherwise a new child
## is made. Returns the child's id, or "" when the tablet is full.
static func create(nickname: String, picture: String, first_run: bool) -> String:
	if first_run:
		ProfileStore.finish_setup(nickname, picture)
		return str(ProfileStore.active().get("id", ""))
	var p := Profiles.add_child(ProfileStore.roster, int(Time.get_unix_time_from_system()), nickname, picture)
	if p.is_empty():
		return ""
	ProfileStore.write()
	return str(p["id"])


## The edit screen's "Save": a new name (blank keeps the old one) and
## picture. Guest is never changed.
static func save_edit(profile_id: String, nickname: String, picture: String) -> bool:
	var p := Profiles.find(ProfileStore.roster, profile_id)
	if p.is_empty() or bool(p.get("guest", false)):
		return false
	if Profiles.clean_name(nickname) != "":
		Profiles.rename(ProfileStore.roster, profile_id, nickname)
	Profiles.set_picture(ProfileStore.roster, profile_id, picture)
	ProfileStore.write()
	return true


## The edit screen's Remove (after its dialog and hold): the child and their
## save on this tablet. The last child stays. Returns true when removed.
static func remove(profile_id: String) -> bool:
	return ProfileStore.remove(profile_id)
