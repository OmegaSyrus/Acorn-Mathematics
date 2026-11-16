## Who plays on the tablet: the roster, Guest, and the parent PIN
## (logic/core/profiles.gd, docs/contract family.profiles).
extends "res://tests/support/test_case.gd"

const Profiles := preload("res://logic/core/profiles.gd")
const Ids := preload("res://logic/core/ids.gd")


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
	eq(odd["profiles"][0]["picture"], Profiles.PICTURES[0], "an unknown picture falls back")
	eq(odd["future"], 1, "unknown fields are kept")
	return true
