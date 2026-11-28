## The create and edit profile screen (profile plan P3): the create steps,
## edit, the Remove hold, first run, Guest, a name longer than 12 cut, and
## every tap target 56 units or more, in the safe band, apart from the
## others, on every step. The screen only emits signals, so the roster must
## come out unchanged. Real taps at 960x540 and 720x540 are checked by
## tools/stills/profile_edit_stills.gd.
extends "res://tests/support/test_case.gd"

const Screen := preload("res://game/profile_edit_screen.gd")
const Profiles := preload("res://logic/core/profiles.gd")
const M3 := preload("res://game/ui/m3.gd")


func _roster(kids := 1) -> Dictionary:
	var r := Profiles.new_roster(100)
	for i in range(1, kids):
		Profiles.add_child(r, 100 + i)
	return r


func _names(s) -> Array:
	var out := []
	for t in s.targets():
		out.append(t["name"])
	return out


func _check_targets(s, where: String) -> void:
	var list: Array = s.targets()
	check(not list.is_empty(), where + " has targets")
	for i in list.size():
		var t: Dictionary = list[i]
		var r: Rect2 = t["rect"]
		check(r.size.x >= M3.TARGET and r.size.y >= M3.TARGET,
				"%s %s is %dx%d, under %d" % [where, t["name"], r.size.x, r.size.y, M3.TARGET])
		check(M3.SAFE.encloses(r), "%s %s %s is outside the safe band" % [where, t["name"], r])
		for j in range(i + 1, list.size()):
			var o: Rect2 = list[j]["rect"]
			check(not r.grow(M3.MIN_GAP / 2.0 - 0.5).intersects(o.grow(M3.MIN_GAP / 2.0 - 0.5)),
					"%s %s and %s are closer than %d" % [where, t["name"], list[j]["name"], M3.MIN_GAP])


func test_create_walks_three_steps() -> bool:
	var r := _roster(2)
	var before := Profiles.to_text(r)
	var s := Screen.new()
	s.setup(r, Screen.Mode.CREATE)
	eq(s.name_text, "Player 3", "name box starts with Player N")
	eq(s.picture, Profiles.next_free_picture(r), "first pick is the next free picture")
	var got := []
	s.created.connect(func(n, p): got.append([n, p]))
	eq(s.step, Screen.Step.PICK, "opens on Pick")
	_check_targets(s, "pick")
	eq(_names(s).filter(func(n): return n.begins_with("tile_")).size(), 14, "14 tiles")
	s.tap("tile_9")
	eq(s.picture, Profiles.PICTURES[9], "a tile picks its picture")
	s.tap("next")
	eq(s.step, Screen.Step.NAME, "Next goes to Name")
	_check_targets(s, "name")
	check(s.field_rect().end.y <= 270 and s.next_button_rect().end.y <= 300,
			"name box and Next sit in the top half, above the keyboard")
	s.set_name_text("Wren")
	s.tap("nav_back")
	eq(s.step, Screen.Step.PICK, "Back goes back a step")
	eq([s.name_text, s.picture], ["Wren", Profiles.PICTURES[9]], "Back keeps what was picked")
	s.tap("next")
	s.tap("next")
	eq(s.step, Screen.Step.CONFIRM, "then Yes")
	_check_targets(s, "confirm")
	check(got.is_empty(), "nothing made before Yes")
	s.tap("next")
	eq(got, [["Wren", Profiles.PICTURES[9]]], "Yes emits created(nickname, picture)")
	eq(Profiles.to_text(r), before, "the screen never changes the roster")
	s.free()
	return true


func test_back_from_pick_and_first_run() -> bool:
	var s := Screen.new()
	var backs := [0]
	s.back.connect(func(): backs[0] += 1)
	s.setup(_roster(2), Screen.Mode.CREATE)
	s.tap("back")
	eq(backs[0], 1, "Back on Pick emits back")
	var r := Profiles.new_roster(100, true)
	s.setup(r, Screen.Mode.CREATE, "", true)
	eq([s.name_text, s.picture], ["Player 1", Profiles.DEFAULT_PICTURE], "first run starts from Player 1")
	var names := _names(s)
	check(not names.has("back") and not names.has("nav_back"), "no way back from step 1 on first run")
	_check_targets(s, "first-run pick")
	s.tap("back")
	eq(backs[0], 1, "a stray back does nothing on first run")
	s.tap("next")
	check(_names(s).has("nav_back"), "step 2 on first run can go back to step 1")
	s.tap("nav_back")
	eq(s.step, Screen.Step.PICK, "back to Pick")
	s.free()
	return true


func test_long_name_is_cut() -> bool:
	var s := Screen.new()
	var got := []
	s.created.connect(func(n, p): got.append(n))
	s.setup(_roster(), Screen.Mode.CREATE)
	s.tap("next")
	s.set_name_text("Bartholomew The Great")
	eq(s.name_text.length(), 12, "a name longer than 12 is cut")
	s.tap("next")
	s.tap("next")
	eq(got, ["Bartholomew"], "and cleaned (the cut's trailing space goes)")
	s.free()
	return true


func test_edit_save_and_remove_hold() -> bool:
	var r := _roster(2)
	var before := Profiles.to_text(r)
	var kid: Dictionary = Profiles.children(r)[1]
	var s := Screen.new()
	var saves := []
	var removes := []
	s.saved.connect(func(id, n, p): saves.append([id, n, p]))
	s.removed.connect(func(id): removes.append(id))
	s.setup(r, Screen.Mode.EDIT, kid["id"])
	eq([s.name_text, s.picture], [kid["nickname"], kid["picture"]], "edit starts from the profile")
	_check_targets(s, "edit")
	check(_names(s).has("remove"), "Remove shows with two children")
	s.tap("tile_13")
	s.set_name_text("  Moss ")
	s.tap("save")
	eq(saves, [[kid["id"], "Moss", Profiles.PICTURES[13]]], "Save emits saved(id, nickname, picture)")
	s.tap("remove")
	check(s.dialog_open, "Remove opens the dialog")
	eq(_names(s), ["dialog_back", "dialog_remove"], "only the dialog's buttons with it open")
	_check_targets(s, "dialog")
	check(not s.hold_remove(1.0) and not s.hold_remove(1.0), "two seconds is not enough")
	s.release_hold()
	check(not s.hold_remove(2.9), "letting go starts the hold again")
	check(removes.is_empty(), "nothing removed yet")
	check(s.hold_remove(0.2), "three seconds held removes")
	eq(removes, [kid["id"]], "removed(id)")
	check(not s.dialog_open, "dialog closes")
	s.tap("remove")
	s.tap("dialog_back")
	check(not s.dialog_open, "dialog Back closes it")
	eq(Profiles.to_text(r), before, "the screen never changes the roster")
	s.free()
	return true


func test_last_child_and_guest() -> bool:
	var r := _roster(1)
	var only: Dictionary = Profiles.children(r)[0]
	var s := Screen.new()
	s.setup(r, Screen.Mode.EDIT, only["id"])
	check(not s.can_remove(), "the last child can't be removed")
	check(not _names(s).has("remove"), "so Remove is not a target")
	s.tap("remove")
	check(not s.dialog_open and not s.hold_remove(5.0), "and a stray tap does nothing")
	var g := Profiles.ensure_guest(r, 200)
	s.setup(r, Screen.Mode.EDIT, g["id"])
	check(s.refused, "Guest can't be edited")
	check(s.targets().is_empty(), "nothing to tap for Guest")
	s.setup(r, Screen.Mode.EDIT, "p_000000000000")
	check(s.refused, "an unknown id is refused")
	s.free()
	return true
