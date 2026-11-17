## This install's identity (family.device v1, docs/contract). Pure: the
## game layer (game/device_id.gd) reads and writes user://device.json.
##
## fp is a hash of the hardware id (OS.get_unique_id()). On Android that id
## differs per device (and per signing key), and Auto Backup or a copied
## folder carries device.json but not the hardware: when the fingerprint
## does not match, a new device id is made, so two tablets never upload as one.
extends RefCounted

const Ids := preload("res://logic/core/ids.gd")
const JsonUtil := preload("res://logic/core/json_util.gd")

const SCHEMA := "family.device"
const VERSION := 1
const FP_SALT := "acorn-family-device-v1:"


static func fingerprint(hardware_id: String) -> String:
	return Ids.sha256_hex(FP_SALT + hardware_id).left(16)


static func fresh(hardware_id: String, now: int) -> Dictionary:
	return {"schema": SCHEMA, "v": VERSION, "dev": Ids.device_id(), "fp": fingerprint(hardware_id),
			"created": now, "boot": 0}


## The device document for this hardware, from the file's text (may be empty
## or broken). Keeps a matching file; replaces a missing, broken or copied one.
static func from_text(text: String, hardware_id: String, now: int) -> Dictionary:
	var json := JSON.new()
	if text.is_empty() or json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return fresh(hardware_id, now)
	var d: Dictionary = JsonUtil.normalize(json.data)
	if not Ids.is_device_id(str(d.get("dev", ""))):
		return fresh(hardware_id, now)
	if str(d.get("fp", "")) != fingerprint(hardware_id):
		var copy := fresh(hardware_id, now)
		copy["copied_from"] = str(d["dev"])
		return copy
	d["schema"] = SCHEMA
	d["v"] = VERSION
	if typeof(d.get("boot")) != TYPE_INT:
		d["boot"] = 0
	if typeof(d.get("created")) != TYPE_INT:
		d["created"] = now
	return d


static func to_text(d: Dictionary) -> String:
	return JSON.stringify(d, "\t", false)
