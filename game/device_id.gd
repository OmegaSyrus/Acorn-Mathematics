## This install's device id (docs/contract, family.device): made at first
## launch in user://device.json, raised launch count each start. A file
## copied from another tablet (Android backup, a copied folder) fails the
## hardware fingerprint and gets a new id here (logic/core/device_info.gd).
extends RefCounted

const DeviceInfo := preload("res://logic/core/device_info.gd")

const PATH := "user://device.json"

static var current := {}


## Reads (or makes) the device file, counts this launch and writes it back.
static func load_and_count(at := PATH) -> Dictionary:
	var text := FileAccess.get_file_as_string(at) if FileAccess.file_exists(at) else ""
	var d := DeviceInfo.from_text(text, OS.get_unique_id(), int(Time.get_unix_time_from_system()))
	d["boot"] = int(d["boot"]) + 1
	var f := FileAccess.open(at, FileAccess.WRITE)
	if f != null:
		f.store_string(DeviceInfo.to_text(d))
		f.close()
	current = d
	return d


static func dev() -> String:
	return str(current.get("dev", ""))
