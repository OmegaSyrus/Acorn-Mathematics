## The switcher (S1), the profile page (S3) and main.gd's profile steps
## (game/profile_flow.gd), profile plan P4.
extends "res://tests/support/test_case.gd"

const WhoScreen := preload("res://game/who_screen.gd")
const ProfileScreen := preload("res://game/profile_screen.gd")
const ProfileFlow := preload("res://game/profile_flow.gd")
const ProfileStore := preload("res://game/profile_store.gd")
const Profiles := preload("res://logic/core/profiles.gd")
const SaveStore := preload("res://game/save_store.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const M3 := preload("res://game/ui/m3.gd")
const Stub := preload("res://game/profile_edit_stub.gd")


func _full_roster() -> Dictionary:
	var r := Profiles.new_roster(0)
	for i in Profiles.MAX_PROFILES - 1:
		Profiles.add_child(r, 0)
	Profiles.ensure_guest(r, 0)
	return r


## Every target: at least TARGET both ways, inside the frame's safe band
## (the top bar's back arrow included), and MIN_GAP from every other.
func _check_targets(rects: Array, what: String) -> void:
	for i in rects.size():
		var a: Rect2 = rects[i]
		check(a.size.x >= M3.TARGET and a.size.y >= M3.TARGET, "%s %d is %s" % [what, i, a.size])
		check(a.position.x >= M3.SAFE.position.x and a.end.x <= M3.SAFE.end.x, "%s %d leaves the band: %s" % [what, i, a])
		check(a.position.y >= 0 and a.end.y <= 540, "%s %d off the frame: %s" % [what, i, a])
		for j in range(i + 1, rects.size()):
			var b: Rect2 = rects[j]
			check(not a.grow(M3.MIN_GAP / 2.0 - 0.01).intersects(b.grow(M3.MIN_GAP / 2.0 - 0.01)),
					"%s %d and %d too close" % [what, i, j])


func test_six_children_guest_and_new_fit() -> bool:
	var r := Profiles.new_roster(0)
	for i in Profiles.MAX_PROFILES - 2:
		Profiles.add_child(r, 0)
	# five children: five cards, Guest, New = 7
	var e := WhoScreen.entries(r, false)
	eq(e.size(), 7, "5 children + Guest + New")
	check(e[-1]["new"] and e[-2]["guest"], "Guest then New at the end")
	Profiles.add_child(r, 0)
	e = WhoScreen.entries(r, false)
	eq(e.size(), 7, "6 children + Guest; New goes when full")
	check(not e[-1]["new"], "no New at six children")
	# the largest grid: eight cards (6 + Guest + New, as a layout)
	var rects := WhoScreen.card_rects(8)
	rects.append(M3.top_bar_back_rect())
	_check_targets(rects, "S1 card")
	check(WhoScreen.card_rects(8)[7].end.y <= 540 - M3.GRID, "two rows fit above the bottom edge")
	return true


func test_every_card_count_fits() -> bool:
	for n in range(1, 9):
		var rects := WhoScreen.card_rects(n)
		rects.append(M3.top_bar_back_rect())
		_check_targets(rects, "S1 with %d" % n)
	return true


func test_manage_mode_leaves_out_guest() -> bool:
	var r := _full_roster()
	for e in WhoScreen.entries(r, true):
		check(not e["guest"], "no Guest card in manage mode")
	eq(WhoScreen.entries(r, true).size(), Profiles.MAX_PROFILES, "six children, no New when full")
	var small := Profiles.new_roster(0)
	var m := WhoScreen.entries(small, true)
	eq(m.size(), 2, "one child + New")
	check(m[1]["new"], "New in manage mode")
	return true


func test_current_player_has_the_ring() -> bool:
	var r := _full_roster()
	var second := str(Profiles.children(r)[1]["id"])
	Profiles.set_active(r, second)
	var rings := 0
	for e in WhoScreen.entries(r, false):
		if e["active"]:
			rings += 1
			eq(e["id"], second, "the ring is on the player")
	eq(rings, 1, "one ring")
	Profiles.set_active(r, str(Profiles.guest_profile(r)["id"]))
	var g: Dictionary = WhoScreen.entries(r, false)[Profiles.MAX_PROFILES]
	check(g["guest"] and g["active"], "Guest has the ring when Guest plays")
	return true


func test_every_picture_draws() -> bool:
	for id in Profiles.PICTURES:
		var t := WhoScreen.picture(id)
		check(t != null, "picture %s" % id)
		if t != null:
			check(t.get_height() <= WhoScreen.FEET_Y - 4, "%s fits the card at 1:1 (%d tall)" % [id, t.get_height()])
	check(WhoScreen.picture(Profiles.GUEST_PICTURE) != null, "Guest picture")
	return true


func test_profile_page_targets() -> bool:
	for guest in [false, true]:
		var acts := ProfileScreen.layout(guest)
		var rects := []
		var has_edit := false
		for a in acts:
			rects.append(a["rect"])
			has_edit = has_edit or a["act"] == ProfileScreen.Act.EDIT
		eq(has_edit, not guest, "Edit only for a child")
		eq(acts[-1]["act"], ProfileScreen.Act.PLAY, "Play last (the main action)")
		_check_targets(rects, "S3 guest=%s" % guest)
	for i in 4:
		var s := ProfileScreen.stat_rect(i)
		check(s.end.x <= M3.SAFE.end.x and s.end.y <= ProfileScreen.BUTTONS_Y - M3.GRID, "stat card %d fits" % i)
		check(not s.intersects(ProfileScreen.AVATAR_CARD), "stat card %d clear of the picture" % i)
	return true


func test_stub_matches_the_planned_signals() -> bool:
	var s = Stub.new()
	for sig in ["created", "saved", "removed", "back"]:
		check(s.has_signal(sig), "stub has %s" % sig)
	s.free()
	if ResourceLoader.exists("res://game/profile_edit_screen.gd"):
		var real = load("res://game/profile_edit_screen.gd").new()
		for sig in ["created", "saved", "removed", "back"]:
			check(real.has_signal(sig), "P3 screen has %s" % sig)
		check(real.has_method("setup"), "P3 screen has setup")
		real.free()
	return true


# --- the roster steps main.gd takes (ProfileFlow), in a temp save folder ---

var _old_dir := ""


func _use_temp() -> void:
	_old_dir = SaveStore.dir
	var d := "user://test_p4_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(d)
	SaveStore.dir = d
	ProfileStore.roster = {}
	ProfileStore.load_roster()


func _restore() -> void:
	SaveStore.dir = _old_dir
	ProfileStore.roster = {}


func test_flow_first_run_and_new() -> bool:
	_use_temp()
	check(Profiles.is_fresh(ProfileStore.roster), "a new install is fresh")
	var first := ProfileFlow.create("Bear", "phoenix", true)
	eq(str(ProfileStore.active()["nickname"]), "Bear", "first child named")
	eq(str(ProfileStore.active()["picture"]), "phoenix", "first child's picture")
	check(not Profiles.is_fresh(ProfileStore.roster), "setup done")
	eq(Profiles.children(ProfileStore.roster).size(), 1, "still one child")
	var second := ProfileFlow.create("Wren", "bolt_red", false)
	check(second != "" and second != first, "a second child")
	eq(Profiles.children(ProfileStore.roster).size(), 2, "two children")
	# the roster on disk has both
	ProfileStore.roster = {}
	ProfileStore.load_roster()
	eq(Profiles.children(ProfileStore.roster).size(), 2, "written")
	_restore()
	return true


func test_flow_first_run_back_keeps_player_1() -> bool:
	_use_temp()
	ProfileFlow.create("", "", true)
	eq(str(ProfileStore.active()["nickname"]), "Player 1", "Back keeps Player 1")
	check(not Profiles.is_fresh(ProfileStore.roster), "and finishes setup")
	_restore()
	return true


func test_flow_full_tablet() -> bool:
	_use_temp()
	ProfileFlow.create("", "", true)
	for i in Profiles.MAX_PROFILES - 1:
		check(ProfileFlow.create("", "", false) != "", "child %d" % (i + 2))
	eq(ProfileFlow.create("Extra", "fox", false), "", "no seventh child")
	_restore()
	return true


func test_flow_edit_and_remove_reload_the_right_save() -> bool:
	_use_temp()
	var a := ProfileFlow.create("Ann", "fox", true)
	var b := ProfileFlow.create("Ben", "lion", false)
	# Ben plays and earns gems; Ann has her own save
	ProfileStore.use(b)
	var save_b := SaveStore.read()
	save_b["gems"] = 21
	SaveStore.write(save_b)
	ProfileStore.use(a)
	var save_a := SaveStore.read()
	save_a["gems"] = 5
	SaveStore.write(save_a)
	check(ProfileFlow.save_edit(b, "Benny", "bolt_green"), "edit Ben")
	var pb := Profiles.find(ProfileStore.roster, b)
	eq(str(pb["nickname"]), "Benny", "renamed")
	eq(str(pb["picture"]), "bolt_green", "new picture")
	check(ProfileFlow.save_edit(b, "  ", "nope"), "blank name and unknown picture")
	pb = Profiles.find(ProfileStore.roster, b)
	eq(str(pb["nickname"]), "Benny", "blank keeps the name")
	eq(str(pb["picture"]), "bolt_green", "unknown picture keeps it")
	var g := Profiles.ensure_guest(ProfileStore.roster, 0)
	check(not ProfileFlow.save_edit(str(g["id"]), "Hacker", "fox"), "Guest can't be edited")
	# swap to Ben: his gems
	ProfileStore.use(b)
	eq(int(SaveStore.read()["gems"]), 21, "Ben's save")
	# remove Ben while he plays: Ann plays on, with her save
	check(ProfileFlow.remove(b), "Ben removed")
	eq(SaveStore.profile, a, "Ann plays on")
	eq(int(SaveStore.read()["gems"]), 5, "Ann's save loads")
	check(not FileAccess.file_exists(SaveStore.path_for(b)), "Ben's save is gone")
	check(not ProfileFlow.remove(a), "the last child stays")
	_restore()
	return true
