## Writes the profile save to user:// after every task. Writes go to a temp
## file first, then replace the save, so closing mid-write can't corrupt it.
extends RefCounted

const SaveData := preload("res://logic/core/save_data.gd")

const PROFILE := "1"


static func path() -> String:
	return "user://profile_%s.json" % PROFILE


static func read() -> Dictionary:
	var text := ""
	if FileAccess.file_exists(path()):
		text = FileAccess.get_file_as_string(path())
	return SaveData.from_text(text, PROFILE)


static func write(save: Dictionary) -> void:
	var tmp := path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("save failed: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(SaveData.to_text(save))
	f.close()
	var dir := DirAccess.open("user://")
	if dir.file_exists(path().get_file()):
		dir.remove(path().get_file())
	dir.rename(tmp.get_file(), path().get_file())
