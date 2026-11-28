## The Material kit (profile plan P1): every tap target is 56 units or more
## both ways, sits in the 720-wide safe band (so a 4:3 screen shows it) and
## inside the frame, and any two are at least MIN_GAP apart. The kit's own sizes hold the rule
## too. The pixels at 960x540 and 720x540 are checked by
## tools/stills/m3_stills.gd (headless draws nothing).
extends "res://tests/support/test_case.gd"

const M3 := preload("res://game/ui/m3.gd")
const Sample := preload("res://game/ui/m3_sample.gd")


func _check_targets(list: Array, where: String) -> void:
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


func test_sample_targets_are_big_enough() -> bool:
	var s := Sample.new()
	var list := s.targets()
	check(list.size() >= 20, "sample shows every part (%d targets)" % list.size())
	_check_targets(list, "sample")
	s.dialog_open = true
	var dl := s.targets()
	eq(dl.size(), 2, "only the dialog's two buttons with it open")
	_check_targets(dl, "dialog")
	s.free()
	return true


func test_kit_sizes_meet_the_target() -> bool:
	for v in [M3.BUTTON_H, M3.ICON_BUTTON, M3.BUTTON_MIN_W, M3.FIELD_H]:
		check(v >= M3.TARGET, "kit size %d is under %d" % [v, M3.TARGET])
	check(M3.TARGET >= M3.MATERIAL_TARGET, "kit target is at least Material's 48 dp")
	check(M3.TOP_BAR_H >= M3.ICON_BUTTON, "top bar holds an icon button")
	for word in ["New", "Pick", "Name", "Next", "Yes", "Back", "Play", "Swap", "Edit", "Save", "Guest", "Remove"]:
		var r := M3.button_rect(Vector2.ZERO, word)
		check(r.size.x >= M3.TARGET and r.size.y >= M3.TARGET, "button %s is %s" % [word, r.size])
		check(r.size.x >= M3.text_width(word, M3.LABEL) + M3.BUTTON_PAD, "label %s fits its button" % word)
		var ri := M3.button_rect(Vector2.ZERO, word, M3.Icon.PLUS)
		check(ri.size.x > r.size.x or ri.size.x == M3.BUTTON_MIN_W, "an icon widens %s" % word)
	var t := M3.target(Rect2(10, 10, 20, 30))
	eq([t.size.x, t.size.y, t.get_center().x, t.get_center().y], [56, 56, 20, 25], "target() grows around the middle")
	var big := M3.target(Rect2(0, 0, 96, 96))
	eq([big.size.x, big.size.y], [96, 96], "target() keeps a big rect")
	return true


func test_top_bar_and_dialog_layout() -> bool:
	check(M3.SAFE.encloses(M3.top_bar_back_rect()), "back arrow in the safe band")
	check(M3.top_bar_action_rect(0).end.x <= M3.SAFE.end.x, "actions end in the safe band")
	check(M3.top_bar_action_rect(1).end.x < M3.top_bar_action_rect(0).position.x, "actions run right to left")
	check(M3.top_bar_rect().position.x <= -(960 - 720) / 2.0 and M3.top_bar_rect().end.x >= 960,
			"top bar spans every screen shape")
	for lines in [0, 1, 2, 4]:
		var box := M3.dialog_rect(lines)
		check(M3.SAFE.encloses(box), "dialog with %d lines fits the safe band" % lines)
		var rs := M3.dialog_button_rects(box, ["Back", "Remove"])
		eq(rs.size(), 2, "two dialog buttons")
		check(rs[1].position.x > rs[0].end.x, "confirm button on the right")
		for r in rs:
			check(box.encloses(r), "dialog button inside the box")
	return true


func test_line_edit_cuts_long_names() -> bool:
	var e := M3.line_edit(Sample.FIELD, 12)
	e.text = "Bartholomew The Great"
	check(e.text.length() <= 12, "a name longer than 12 is cut (%s)" % e.text)
	e.free()
	return true

