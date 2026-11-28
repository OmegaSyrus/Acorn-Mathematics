## Who plays on the tablet: the roster, Guest, and the parent PIN
## (logic/core/profiles.gd, docs/contract family.profiles).
extends "res://tests/support/test_case.gd"

const Profiles := preload("res://logic/core/profiles.gd")
const Ids := preload("res://logic/core/ids.gd")
const Store := preload("res://logic/core/store.gd")
const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")


func test_new_roster_has_one_child() -> bool:
	var r := Profiles.new_roster(100)
	eq(Profiles.children(r).size(), 1, "one child")
	var p := Profiles.active(r)
	check(Ids.is_profile_id(p["id"]), "random profile id " + str(p["id"]))
	eq(p["nickname"], "Player 1", "default name")
	check(not Profiles.needs_picker(r), "one child skips the picker")
	check(not Profiles.has_pin(r), "no PIN at first")
	return true


func test_children_and_guest() -> bool:
	var r := Profiles.new_roster(100)
	var b := Profiles.add_child(r, 101)
	check(b["picture"] != Profiles.active(r)["picture"], "the next child gets a new picture")
	eq(b["nickname"], "Player 2", "numbered")
	check(Profiles.needs_picker(r), "two children: picker at launch")
	for i in 10:
		Profiles.add_child(r, 102)
	eq(Profiles.children(r).size(), Profiles.MAX_PROFILES, "six at most")
	var g := Profiles.ensure_guest(r, 103)
	check(g["guest"], "guest flag")
	eq(Profiles.ensure_guest(r, 104)["id"], g["id"], "one Guest only")
	eq(Profiles.children(r).size(), Profiles.MAX_PROFILES, "Guest is not a child")
	check(Profiles.set_active(r, g["id"]), "Guest can play")
	check(Profiles.remove(r, g["id"]), "Guest can be removed")
	eq(Profiles.active(r)["guest"], false, "a child plays on")
	return true


func test_last_child_stays() -> bool:
	var r := Profiles.new_roster(100)
	var a := Profiles.active(r)
	check(not Profiles.remove(r, a["id"]), "the last child can't be removed")
	var b := Profiles.add_child(r, 101)
	Profiles.set_active(r, a["id"])
	check(Profiles.remove(r, a["id"]), "removed with another child left")
	eq(r["active"], b["id"], "the other child is now active")
	return true


func test_names_are_cleaned() -> bool:
	var r := Profiles.new_roster(100)
	var id: String = Profiles.active(r)["id"]
	Profiles.rename(r, id, "  Bartholomew the Brave  ")
	eq(Profiles.active(r)["nickname"], "Bartholomew", "12 characters, trimmed first")
	Profiles.rename(r, id, "   ")
	eq(Profiles.active(r)["nickname"], "Bartholomew", "a blank name keeps the old one")
	Profiles.rename(r, id, "Wren\n")
	eq(Profiles.active(r)["nickname"], "Wren", "no control characters")
	return true


func test_pin() -> bool:
	var r := Profiles.new_roster(100)
	check(Profiles.check_pin(r, ""), "no PIN: open")
	for bad in ["123", "12345", "12a4", "-123", ""]:
		check(not Profiles.set_pin(r, bad), "refuses " + bad)
	check(Profiles.set_pin(r, "0427"), "four digits")
	check(Profiles.has_pin(r), "set")
	check(Profiles.check_pin(r, "0427"), "right PIN")
	check(not Profiles.check_pin(r, "0428"), "wrong PIN")
	check(not JSON.stringify(r).contains("0427"), "the PIN itself is never stored")
	var again := Profiles.from_text(Profiles.to_text(r))
	check(Profiles.check_pin(again, "0427"), "PIN survives a save")
	Profiles.clear_pin(r)
	check(not Profiles.has_pin(r), "cleared")
	return true


func test_from_text() -> bool:
	eq(Profiles.from_text(""), {}, "missing")
	eq(Profiles.from_text("{oops"), {}, "broken")
	eq(Profiles.from_text('{"profiles": []}'), {}, "no children")
	var r := Profiles.new_roster(100)
	Profiles.add_child(r, 101)
	r["active"] = "p_000000000000"
	var back := Profiles.from_text(Profiles.to_text(r))
	eq(back["profiles"].size(), 2, "both kept")
	eq(back["active"], back["profiles"][0]["id"], "an unknown active falls back to the first")
	var odd := Profiles.from_text('{"profiles": [{"id": "p_00000000000a", "picture": "dragon"}, {"id": "bad"}], "future": 1}')
	eq(odd["profiles"].size(), 1, "a bad id is dropped")
	eq(odd["profiles"][0]["picture"], Profiles.DEFAULT_PICTURE, "an unknown picture falls back")
	eq(odd["future"], 1, "unknown fields are kept")
	return true


# --- profile plan P2 (2026-11-21) -----------------------------------------------

func test_pictures_are_the_14_shop_looks() -> bool:
	eq(Profiles.PICTURES.size(), 14, "14 looks")
	var heroes := []
	for it in Store.items(Store.catalog(), "hero"):
		# the Level 4 to 6 Bolts (Phase 6) are paints of Bolt, not new looks
		if not (it.has("paint") and Store.reward_level(it) > 0):
			heroes.append(it["id"])
	for id in heroes:
		check(Profiles.PICTURES.has(id), "shop hero %s is a picture" % id)
	for id in Profiles.PICTURES:
		check(heroes.has(id), "picture %s is a shop hero" % id)
	eq(Profiles.PICTURES.slice(0, 3), ["robodragon", "bolt_red", "bolt_green"], "Bolt first")
	for old in ["fox", "bunny", "hedgehog", "turtle", "lion", "eagle", "phoenix", "gryphon", "elf_mage", "templar", "slime_knight"]:
		check(Profiles.PICTURES.has(old), "old picture %s still valid" % old)
	return true


func test_add_with_name_and_picture() -> bool:
	var r := Profiles.new_roster(100)
	eq(Profiles.default_name(r), "Player 2", "name box starts with the next Player N")
	var b := Profiles.add_child(r, 101, "  Wren  ", "bolt_red")
	eq(b["nickname"], "Wren", "chosen name, trimmed")
	eq(b["picture"], "bolt_red", "chosen picture")
	var c := Profiles.add_child(r, 102, "Bartholomewwww", "phoenix")
	eq(c["nickname"].length(), Profiles.NAME_MAX, "cut to 12")
	var d := Profiles.add_child(r, 103, "   ", "dragon")
	eq(d["nickname"], "Player 4", "a blank name is Player N")
	check(Profiles.PICTURES.has(d["picture"]), "an unknown picture becomes a real one")
	var used := []
	for p in r["profiles"]:
		check(not used.has(p["picture"]) or p == d, "no clash")
		used.append(p["picture"])
	check(Profiles.can_add(r), "room for two more")
	Profiles.add_child(r, 104)
	Profiles.add_child(r, 105)
	check(not Profiles.can_add(r), "six is full")
	eq(Profiles.add_child(r, 106, "Seven", "fox"), {}, "a seventh is refused")
	return true


func test_set_picture() -> bool:
	var r := Profiles.new_roster(100)
	var id: String = Profiles.active(r)["id"]
	check(Profiles.set_picture(r, id, "bolt_green"), "set directly")
	eq(Profiles.active(r)["picture"], "bolt_green", "now Green Bolt")
	check(not Profiles.set_picture(r, id, "dragon"), "an unknown id is refused")
	eq(Profiles.active(r)["picture"], "bolt_green", "unchanged")
	check(not Profiles.set_picture(r, "p_000000000000", "fox"), "an unknown profile")
	var g := Profiles.ensure_guest(r, 101)
	check(not Profiles.set_picture(r, g["id"], "fox"), "Guest can't be edited")
	eq(g["picture"], Profiles.GUEST_PICTURE, "Guest keeps its picture")
	return true


func test_pin_for_new_profiles() -> bool:
	var r := Profiles.new_roster(100)
	check(not Profiles.add_needs_pin(r), "no PIN set: no ask")
	Profiles.set_pin(r, "1234")
	check(Profiles.add_needs_pin(r), "PIN set: New asks for it (D2)")
	return true


func test_fresh_install_flag() -> bool:
	var r := Profiles.new_roster(100, true)
	check(Profiles.is_fresh(r), "a new install is fresh")
	var back := Profiles.from_text(Profiles.to_text(r))
	check(Profiles.is_fresh(back), "still fresh after a restart mid-flow")
	Profiles.finish_setup(back, "Wren", "lion")
	check(not Profiles.is_fresh(back), "done")
	eq(Profiles.active(back)["nickname"], "Wren", "named")
	eq(Profiles.active(back)["picture"], "lion", "picture set")
	check(not Profiles.is_fresh(Profiles.from_text(Profiles.to_text(back))), "stays done")
	var b := Profiles.new_roster(100, true)
	Profiles.finish_setup(b)
	eq(Profiles.active(b)["nickname"], "Player 1", "Back keeps Player 1")
	eq(Profiles.active(b)["picture"], Profiles.DEFAULT_PICTURE, "and its picture")
	check(not Profiles.is_fresh(Profiles.new_roster(100)), "not fresh unless asked")
	return true


## A roster written by 0.28.0 (before P2) loads exactly as it was.
func test_old_roster_loads_unchanged() -> bool:
	var text := FileAccess.get_file_as_string("res://docs/contract/samples/profiles.json")
	var want: Dictionary = JSON.parse_string(text)
	var r := Profiles.from_text(text)
	eq(r, want, "same roster")
	check(not Profiles.is_fresh(r), "an old roster is not fresh")
	check(not r.has("fresh"), "no new key added")
	return true


func _worlds() -> Array:
	var ws := []
	for id in ["lava_caves", "crystal_mines", "bog", "mushroom_forest", "space"]:
		ws.append({"id": id, "area": id})
	return ws


func _beat(save: Dictionary, world: String, level: int) -> void:
	SaveData.add_mark(save, world, int(Content.level_ids(world)[level - 1]))


func test_stats() -> bool:
	var save := SaveData.new_profile("p_000000000001")
	var s := Profiles.stats(save, _worlds())
	eq(s["level"], 1, "new: Level 1")
	eq(s["worlds_done"], 0, "nothing done")
	eq(s["worlds"], 5, "out of 5")
	eq(s["stars"], 0, "no stars")
	eq(s["currencies"][0], {"id": "gems", "amount": 0}, "gems first")
	for w in _worlds():
		_beat(save, w["id"], 1)
	_beat(save, "lava_caves", 2)
	_beat(save, "crystal_mines", 2)
	SaveData.add_star(save, "lava_caves", 1)
	SaveData.add_star(save, "lava_caves", 12)
	SaveData.add_star(save, "bog", 3)
	SaveData.add_gems(save, 7)
	Store.add(save, "crystals", 4)
	save["difficulty"] = 2
	s = Profiles.stats(save, _worlds())
	eq(s["level_top"], 2, "Level 2 opened by the full pass")
	eq(s["level"], 2, "plays Level 2")
	eq(s["worlds_done"], 2, "two worlds done at Level 2")
	eq(s["stars"], 3, "three stars")
	var money := {}
	for c in s["currencies"]:
		money[c["id"]] = c["amount"]
	eq(money.get("gems"), 7, "gems")
	eq(money.get("crystals"), 4, "crystals")
	check(not money.has("sprout_stars"), "locked currencies left out")
	save["difficulty"] = 1
	eq(Profiles.stats(save, _worlds())["worlds_done"], 5, "all five at Level 1")
	save["difficulty"] = 5
	eq(Profiles.stats(save, _worlds())["level"], 2, "never past the Level open")
	return true
