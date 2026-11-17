## This install's id (logic/core/device_info.gd): random, kept on the same
## tablet, replaced when the file arrives on another (Android backup).
extends "res://tests/support/test_case.gd"

const DeviceInfo := preload("res://logic/core/device_info.gd")
const Ids := preload("res://logic/core/ids.gd")


func test_fresh_and_kept() -> bool:
	var d := DeviceInfo.from_text("", "hw-A", 100)
	check(Ids.is_device_id(d["dev"]), "d_ + 16 hex: " + str(d["dev"]))
	eq(d["boot"], 0, "no launches yet")
	var again := DeviceInfo.from_text(DeviceInfo.to_text(d), "hw-A", 200)
	eq(again["dev"], d["dev"], "same tablet keeps its id")
	eq(again["created"], 100, "and its first launch time")
	check(DeviceInfo.from_text("", "hw-A", 100)["dev"] != d["dev"], "two installs never share an id")
	return true


func test_copied_file_gets_new_id() -> bool:
	var d := DeviceInfo.from_text("", "hw-A", 100)
	d["boot"] = 12
	var copied := DeviceInfo.from_text(DeviceInfo.to_text(d), "hw-B", 300)
	check(copied["dev"] != d["dev"], "another tablet makes its own id")
	eq(copied["copied_from"], d["dev"], "and notes where the file came from")
	eq(copied["boot"], 0, "launches count from zero there")
	return true


func test_broken_file() -> bool:
	for text in ["{", "[]", '{"dev": "nope", "fp": "x"}']:
		check(Ids.is_device_id(DeviceInfo.from_text(text, "hw", 1)["dev"]), "broken file: new id for " + text)
	return true
