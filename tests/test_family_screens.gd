## The family screens: the Family screen (pairing, who is who, the consent
## switch) and the rest screen.
## Big targets inside the 4:3 band, and every tap doing what it says.
extends "res://tests/support/test_case.gd"

const FamilyScreen := preload("res://game/family_screen.gd")
const RestScreen := preload("res://game/rest_screen.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const M3 := preload("res://game/ui/m3.gd")
const Family := preload("res://addons/acorn_family/family.gd")
const Fake := preload("res://tests/support/family_fake.gd")

const DEV := "d_7f3a9c1e04b25d68"
const CHILD := "c_9b2f00e1a7c4"


func _roster(n: int) -> Array:
	var out := []
	for i in n:
		out.append({"id": "p_%012x" % (0xabc000 + i), "nickname": "Kid%d" % i, "picture": "fox", "guest": false})
	out.append({"id": "p_5e5e00a1b2c3", "nickname": "Guest", "picture": "slime_knight", "guest": true})
	return out


func _family(dir: String, roster: Array) -> Node:
	var f := Family.new()
	f.base_url = "https://fake.invalid/v1"
	var server := Fake.new()
	server.dev = DEV
	f.transport = server
	f.configure({"game": "acorn-math", "dev": DEV, "app": "0.29.0", "code": 48, "roster": func(): return roster}, dir)
	return f


func _screen(f: Node, roster: Array) -> FamilyScreen:
	var s := FamilyScreen.new()
	s.setup(f, roster)
	s.choice = ChoiceWidget.new()
	return s


func _rects(s: FamilyScreen) -> Array:
	var out := []
	for t in s._targets():
		out.append(t["rect"])
	return out


func _check_targets(rects: Array, what: String) -> void:
	for i in rects.size():
		var a: Rect2 = rects[i]
		check(a.size.x >= M3.TARGET and a.size.y >= M3.TARGET, "%s %d is %s" % [what, i, a.size])
		check(a.position.x >= M3.SAFE.position.x and a.end.x <= M3.SAFE.end.x, "%s %d leaves the band: %s" % [what, i, a])
		check(a.position.y >= 0 and a.end.y <= 540, "%s %d off the frame: %s" % [what, i, a])
		for j in range(i + 1, rects.size()):
			check(not a.grow(M3.MIN_GAP / 2.0 - 0.01).intersects(rects[j].grow(M3.MIN_GAP / 2.0 - 0.01)),
					"%s %d and %d too close" % [what, i, j])


func _act(s: FamilyScreen, act: String, arg = null) -> void:
	s._refresh()
	var ts: Array = s.targets
	for i in ts.size():
		if ts[i]["act"] == act and (arg == null or ts[i].get("arg") == arg):
			s._on_pick(i)
			return
	failures.append("no target %s %s in view %s" % [act, arg, s.view])


func _tmp() -> String:
	var d := OS.get_temp_dir().path_join("acorn_famscreen_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _clean(d: String) -> void:
	for f in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	DirAccess.remove_absolute(d)


func test_family_screen_flow_and_targets() -> bool:
	var d := _tmp()
	var roster := _roster(6)
	var f := _family(d, roster)
	var s := _screen(f, roster)
	eq(s.mode(), "idle", "not linked")
	_check_targets(_rects(s), "idle")
	_act(s, "start")
	eq(s.mode(), "waiting", "a code shows")
	_check_targets(_rects(s), "waiting")
	f.call("_poll_pairing")
	eq(s.mode(), "linked", "linked once approved")
	check(not f.consent(), "sending off until switched on")
	eq(s.profiles.size(), 6, "six players, no Guest")
	_check_targets(_rects(s), "linked")
	for t in s._targets():
		check(t.get("arg") != "p_5e5e00a1b2c3", "Guest never listed")
	_act(s, "consent")
	check(f.consent(), "the switch turns sending on")
	_act(s, "consent")
	check(not f.consent(), "and off")
	# pick who the first player is
	var first := str(roster[0]["id"])
	eq(s.pick_label(first), "Not linked", "not linked yet")
	_act(s, "pick", first)
	eq(s.view, "pick", "the pick view")
	_check_targets(_rects(s), "pick")
	_act(s, "set", CHILD)
	eq(f.child_of(first), CHILD, "linked to Bear")
	eq(s.pick_label(first), "Bear", "the card says so")
	_act(s, "pick", str(roster[1]["id"]))
	_act(s, "set", "new")
	eq(s.pick_label(str(roster[1]["id"])), "New child", "a new child")
	# twelve children and the two extra choices still fit
	for i in 11:
		f.state["children"].append({"child": "c_%012x" % (0xd000 + i), "nickname": "C%d" % i, "picture": "fox"})
	_act(s, "pick", first)
	eq(s.pick_options().size(), 14, "12 children + New child + Not linked")
	_check_targets(_rects(s), "pick 14")
	_act(s, "back")
	eq(s.view, "main", "back from the pick view")
	_act(s, "unlink")
	eq(s.view, "unlink", "asks first")
	_check_targets(_rects(s), "unlink dialog")
	_act(s, "unlink_no")
	check(f.is_paired(), "Cancel keeps the link")
	_act(s, "unlink")
	_act(s, "unlink_yes")
	check(not f.is_paired(), "unlinked")
	eq(s.mode(), "idle", "back to not linked")
	s.choice.free()
	s.free()
	f.free()
	_clean(d)
	return true


func test_rest_screen() -> bool:
	eq(RestScreen.title_for("daily"), "Time to rest!", "daily limit")
	eq(RestScreen.title_for("bedtime"), "It's bedtime!", "bedtime")
	_check_targets([RestScreen.GROWN_UP_RECT], "rest")
	return true
