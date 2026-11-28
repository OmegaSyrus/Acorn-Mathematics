## Save format version 2 (acorn.save): the upgrade from version 1, gem counts
## per device, and the merge a restore uses (docs/contract/games/acorn-math).
extends "res://tests/support/test_case.gd"

const SaveData := preload("res://logic/core/save_data.gd")
const Store := preload("res://logic/core/store.gd")

const P := "p_0123456789ab"


func _with_device(dev: String, f: Callable) -> void:
	var was := SaveData.device
	SaveData.device = dev
	f.call()
	SaveData.device = was


func test_version_1_upgrades() -> bool:
	var v1 := '{"version": 1, "profile": "1", "stickers": ["lava_1"], "gems": 23, "marks": {"lava_scroll": [1]}, "run": null, "hero": "fox"}'
	var box := []
	_with_device("d_aaaaaaaaaaaaaaaa", func(): box.append(SaveData.from_text(v1, P)))
	var s: Dictionary = box[0]
	eq(s["schema"], "acorn.save", "schema")
	eq(s["version"], 2, "version 2")
	eq(s["game"], "acorn-math", "game")
	eq(s["profile"], P, "the new profile id")
	eq(s["gems"], 23, "gems kept")
	eq(s["gem_counts"], {"d_aaaaaaaaaaaaaaaa": {"earned": 23, "spent": 0}}, "balance becomes this tablet's earned gems")
	eq(s["marks"], {"lava_scroll": [1]}, "marks kept")
	eq(s["hero"], "fox", "hero kept")
	# reading it again changes nothing
	var again := SaveData.from_text(SaveData.to_text(s), P)
	eq(again["gem_counts"], s["gem_counts"], "no second upgrade")
	return true


func test_gems_are_counted() -> bool:
	var s := SaveData.new_profile(P)
	_with_device("d_aaaaaaaaaaaaaaaa", func():
		SaveData.add_gems(s, 30)
		Store.add(s, "gems", 5)
		Store.add(s, "gems", -12))
	eq(s["gems"], 23, "balance")
	eq(s["gem_counts"]["d_aaaaaaaaaaaaaaaa"], {"earned": 35, "spent": 12}, "earned and spent")
	eq(SaveData.gems_from_counts(s["gem_counts"]), s["gems"], "counts agree with the balance")
	# a real purchase goes through the same count
	var cat := Store.catalog()
	for it in cat["items"]:
		if it.has("price") and it["price"]["currency"] == "gems" and Store.is_open(cat, "gems"):
			s["gems"] = 0
			s["gem_counts"] = {}
			_with_device("d_bbbbbbbbbbbbbbbb", func():
				SaveData.add_gems(s, int(it["price"]["amount"]))
				check(Store.buy(cat, s, it["id"]), "buys " + str(it["id"])))
			eq(s["gem_counts"]["d_bbbbbbbbbbbbbbbb"]["spent"], int(it["price"]["amount"]), "a purchase counts as spent")
			break
	return true


func _snap(dev: String, at: int, edit: Callable) -> Dictionary:
	var s := SaveData.new_profile(P)
	_with_device(dev, func(): edit.call(s))
	return SaveData.snapshot(s, dev, 1, at)


func test_merge_two_tablets() -> bool:
	var kitchen := _snap("d_aaaaaaaaaaaaaaaa", 100, func(s):
		SaveData.add_gems(s, 20)
		SaveData.add_gems(s, -15)
		SaveData.add_mark(s, "lava_caves", 1)
		SaveData.add_sticker(s, "lava_1")
		s["owned"].append("slime_helmet")
		s["hero"] = "fox"
		s["run"] = {"area": "lava_scroll"})
	var bedroom := _snap("d_bbbbbbbbbbbbbbbb", 200, func(s):
		SaveData.add_gems(s, 7)
		SaveData.add_mark(s, "lava_caves", 12)
		SaveData.add_star(s, "lava_caves", 1)
		SaveData.add_sticker(s, "lava_1")
		SaveData.add_sticker(s, "lava_1")
		s["hero"] = "bunny"
		s["future_field"] = "kept")
	var m := SaveData.merge([kitchen, bedroom], P, null)
	eq(m["gems"], 12, "20 - 15 + 7: spending on one tablet shows on the other")
	eq(m["marks"], {"lava_caves": [1, 12]}, "marks by union")
	eq(m["stars"], {"lava_caves": [1]}, "stars by union")
	eq(m["owned"], ["slime_helmet"], "owned by union")
	eq(m["stickers"], ["lava_1", "lava_1"], "stickers: the most copies any one tablet has")
	eq(m["hero"], "bunny", "hero from the newest")
	eq(m["run"], null, "another tablet's level in progress is not taken")
	eq(m["future_field"], "kept", "unknown fields kept")
	eq(m["profile"], P, "profile")
	# merging a merge with an older copy of itself changes nothing
	var m2 := SaveData.merge([SaveData.snapshot(m, "d_aaaaaaaaaaaaaaaa", 2, 300), kitchen, bedroom], P, {"area": "x"})
	eq(m2["gems"], 12, "same gems")
	eq(m2["marks"], m["marks"], "same marks")
	eq(m2["run"], {"area": "x"}, "this tablet's own run stays")
	return true


func test_snapshot_wrapper() -> bool:
	var s := SaveData.new_profile(P)
	var w := SaveData.snapshot(s, "d_aaaaaaaaaaaaaaaa", 4, 1000, "c_0123456789ab")
	eq(w["schema"], "family.snapshot", "schema")
	eq(w["save_schema"], "acorn.save", "save schema")
	eq(w["save_v"], 2, "save version")
	eq(w["rev"], 4, "rev")
	s["gems"] = 99
	eq(w["save"]["gems"], 0, "a copy, not the live save")
	return true
