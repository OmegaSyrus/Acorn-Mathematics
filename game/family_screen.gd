## The Family screen (Grown-ups panel, Family; behind the parent PIN):
## links this tablet to the parent app (addons/acorn_family).
##
## Not linked: "Show a pairing code" asks the server for a code, shown large
## for a grown-up to type in the parent app on their phone (or open the
## link); the screen waits, polling, until they approve it or it runs out.
## Linked: the tablet's name, the switch "Send play records and save backups
## to the parent app" (off until a grown-up turns it on), and a card per
## child profile on this tablet: tap it to pick which of the family's
## children it is, "New child" (the parent app makes one) or "Not linked".
## Guest is never listed: it never syncs. "Restore from parent app" merges
## in the saves from the family's other tablets; "Unlink this tablet"
## forgets the pairing here.
extends Node2D

signal back

const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const M3 := preload("res://game/ui/m3.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const FamilyPairing := preload("res://addons/acorn_family/family_pairing.gd")

const LEFT := 136.0
const WIDE := 688.0
const CONSENT_RECT := Rect2(LEFT, 116, WIDE, 68)
const CARD := Vector2(340, 56)
const CARDS_Y := 232.0
const CARD_GAP := 8.0
const BOTTOM_Y := 464.0
const RESTORE_RECT := Rect2(LEFT, BOTTOM_Y, 336, 60)
const UNLINK_RECT := Rect2(LEFT + 352, BOTTOM_Y, 336, 60)
const MAIN_BUTTON := Rect2(280, 400, 400, 64)
## The pick view: three columns of buttons.
const PICK := Vector2(216, 56)
const PICK_X := [136.0, 372.0, 608.0]
const PICK_Y := 104.0
const PICK_STEP := 66.0

## The Family node (the autoload in the game; tests pass their own).
var family: Node
## The tablet's child profiles [{id, nickname, picture}] (no Guest).
var profiles: Array = []
var view := "main"  # main | pick | unlink
var picking := ""   # the profile being picked for
var targets: Array = []  # [{rect, act, arg}]
var choice: ChoiceWidget
var _sig := ""
var _tick := 0.0


func setup(family_node: Node, roster: Array) -> void:
	family = family_node
	profiles = []
	for p in roster:
		if not bool(p.get("guest", false)):
			profiles.append(p)


func _ready() -> void:
	choice = ChoiceWidget.new()
	choice.show_highlight = false
	add_child(choice)
	choice.picked.connect(_on_pick)
	if family != null:
		family.changed.connect(_refresh)
		family.counting = false
	_refresh()


func _exit_tree() -> void:
	if family != null:
		family.counting = true
		if family.changed.is_connected(_refresh):
			family.changed.disconnect(_refresh)


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.5:
		_tick = 0.0
		queue_redraw()


## Which part of the screen shows: "idle", "starting", "waiting", "expired",
## "offline" (not linked) or "linked".
func mode() -> String:
	if family == null:
		return "idle"
	if family.is_paired():
		return "linked"
	match family.pairing.state:
		FamilyPairing.State.STARTING:
			return "starting"
		FamilyPairing.State.WAITING:
			return "waiting"
		FamilyPairing.State.EXPIRED:
			return "expired"
		FamilyPairing.State.OFFLINE:
			return "offline"
	return "idle"


static func card_rect(i: int) -> Rect2:
	return Rect2(Vector2(LEFT + (i % 2) * (CARD.x + 8.0), CARDS_Y + (i / 2) * (CARD.y + CARD_GAP)), CARD)


static func pick_rect(i: int) -> Rect2:
	return Rect2(Vector2(PICK_X[i % 3], PICK_Y + (i / 3) * PICK_STEP), PICK)


## What a profile's card says it is: a child's name, "New child" or "Not linked".
func pick_label(profile_id: String) -> String:
	var c = family.child_of(profile_id)
	if c == "new":
		return "New child"
	if c is String:
		for k in family.children():
			if k["child"] == c:
				return str(k["nickname"])
	return "Not linked"


## The options when picking for a profile: [{label, child}], the family's
## children, then New child and Not linked.
func pick_options() -> Array:
	var out := []
	for k in family.children():
		out.append({"label": str(k["nickname"]), "child": str(k["child"])})
	out.append({"label": "New child", "child": "new"})
	out.append({"label": "Not linked", "child": null})
	return out


func _targets() -> Array:
	var out := [{"rect": M3.top_bar_back_rect(), "act": "back"}]
	if view == "unlink":
		var rects := M3.dialog_button_rects(M3.dialog_rect(3), ["Cancel", "Unlink"])
		out = [{"rect": rects[0], "act": "unlink_no"}, {"rect": rects[1], "act": "unlink_yes"}]
		return out
	if view == "pick":
		var opts := pick_options()
		for i in opts.size():
			out.append({"rect": pick_rect(i), "act": "set", "arg": opts[i]["child"]})
		return out
	match mode():
		"idle":
			out.append({"rect": MAIN_BUTTON, "act": "start"})
		"waiting", "starting":
			out.append({"rect": MAIN_BUTTON, "act": "cancel"})
		"expired", "offline":
			out.append({"rect": MAIN_BUTTON, "act": "start"})
		"linked":
			out.append({"rect": CONSENT_RECT, "act": "consent"})
			for i in profiles.size():
				out.append({"rect": card_rect(i), "act": "pick", "arg": str(profiles[i]["id"])})
			out.append({"rect": RESTORE_RECT, "act": "restore"})
			out.append({"rect": UNLINK_RECT, "act": "unlink"})
	return out


func _refresh() -> void:
	targets = _targets()
	var sig := view + mode() + str(targets.size())
	if sig != _sig or not choice.active:
		_sig = sig
		var rects := []
		for t in targets:
			rects.append(t["rect"])
		choice.present(rects, 0)
	queue_redraw()


func _on_pick(k: int) -> void:
	if k < 0 or k >= targets.size():
		_refresh()
		return
	var t: Dictionary = targets[k]
	_beep()
	match t["act"]:
		"back":
			if view == "pick":
				view = "main"
			else:
				back.emit()
				return
		"start":
			family.start_pairing()
		"cancel":
			family.cancel_pairing()
		"consent":
			family.set_consent(not family.consent())
		"pick":
			picking = str(t["arg"])
			view = "pick"
		"set":
			family.set_child(picking, t["arg"])
			view = "main"
		"restore":
			family.restore_all()
		"unlink":
			view = "unlink"
		"unlink_yes":
			family.unlink()
			view = "main"
		"unlink_no":
			view = "main"
	_sig = ""
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(-480, -100, 1920, 740), M3.SURFACE)
	if view == "pick":
		_draw_pick()
		return
	M3.top_bar(self, "Family", true)
	match mode():
		"linked":
			_draw_linked()
		"waiting", "starting":
			_draw_waiting()
		_:
			_draw_idle()
	if view == "unlink":
		M3.dialog(self, "Unlink this tablet?", ["It stops sending play records here.",
				"The parent app lists it until a", "grown-up removes it there."], ["Cancel", "Unlink"], true)


func _lines(at_y: float, lines: Array, size := M3.BODY, col := M3.ON_SURFACE_VARIANT) -> float:
	var y := at_y
	for l in lines:
		M3.text_center(self, Rect2(LEFT, y, WIDE, size + 8), str(l), size, col)
		y += size + 12
	return y


func _draw_idle() -> void:
	var y := _lines(112, ["Link this tablet to the parent app, so a grown-up", "can see play records on their phone and keep",
			"saves safe. Nothing is sent until you say so."])
	if family != null and (mode() == "expired" or mode() == "offline"):
		_lines(y + 24, [family.pairing.describe(family.clock)], M3.BODY, M3.PRIMARY)
	elif family != null and family.message != "":
		_lines(y + 24, [family.message], M3.SMALL, M3.SECONDARY)
	var label := "Show a pairing code" if mode() == "idle" else ("Show a new code" if mode() == "expired" else "Try again")
	M3.button(self, MAIN_BUTTON, label, M3.Style.FILLED)
	_lines(486, ["Playing needs no account: the game works the same without this."], M3.SMALL)


func _draw_waiting() -> void:
	_lines(100, ["On a grown-up's phone, open the parent app,", "choose Add a tablet and type this code:"])
	var code: String = family.pairing.code if family.pairing.code != "" else "..."
	M3.text_center(self, Rect2(LEFT, 184, WIDE, 110), code, 96, M3.PRIMARY)
	if family.pairing.qr_url != "":
		_lines(300, ["or open " + family.pairing.qr_url], M3.SMALL)
	_lines(338, [family.pairing.describe(family.clock)], M3.BODY, M3.ON_SURFACE)
	M3.button(self, MAIN_BUTTON, "Cancel", M3.Style.TONAL)


func _draw_linked() -> void:
	M3.text_left(self, Rect2(LEFT, 84, WIDE, 32), "This tablet: %s" % family.device_name(), M3.BODY, M3.ON_SURFACE)
	# the consent switch
	var on: bool = family.consent()
	RoundBox.fill(self, CONSENT_RECT, M3.SURFACE_CONTAINER_HIGHEST, M3.SHAPE_M)
	M3.text_left(self, Rect2(CONSENT_RECT.position + Vector2(16, 4), Vector2(WIDE - 120, 30)),
			"Send play records and save backups", M3.BODY, M3.ON_SURFACE)
	M3.text_left(self, Rect2(CONSENT_RECT.position + Vector2(16, 34), Vector2(WIDE - 120, 30)),
			"to the parent app", M3.BODY, M3.ON_SURFACE)
	var sw := Rect2(CONSENT_RECT.end.x - 96, CONSENT_RECT.get_center().y - 18, 80, 36)
	RoundBox.fill(self, sw, M3.PRIMARY if on else M3.SURFACE_CONTAINER_LOW, 18.0)
	RoundBox.frame(self, sw, M3.PRIMARY if on else M3.OUTLINE, 2.0, 18.0)
	var knob := Vector2(sw.end.x - 18 if on else sw.position.x + 18, sw.get_center().y)
	draw_circle(knob, 13.0 if on else 10.0, M3.ON_PRIMARY if on else M3.OUTLINE, true, -1.0, true)
	M3.text_left(self, Rect2(LEFT + 4, 186, WIDE, 24),
			("On. " if on else "Off until a grown-up turns it on. ") + "Guest play is never sent.", M3.SMALL,
			M3.ON_SURFACE_VARIANT)
	M3.text_left(self, Rect2(LEFT + 4, 207, WIDE, 24), "Who is who? Tap a player to pick the child.", M3.SMALL,
			M3.ON_SURFACE_VARIANT)
	for i in profiles.size():
		var r := card_rect(i)
		var p: Dictionary = profiles[i]
		var label := pick_label(str(p["id"]))
		M3.card(self, r)
		M3.text_left(self, Rect2(r.position + Vector2(16, 0), Vector2(150, r.size.y)), str(p["nickname"]), M3.BODY,
				M3.ON_SURFACE)
		M3.text_left(self, Rect2(r.position + Vector2(170, 0), Vector2(160, r.size.y)), label, M3.BODY,
				M3.PRIMARY if label != "Not linked" else M3.ON_SURFACE_VARIANT)
	var note: String = family.message if family.message != "" else family.status_line()
	M3.text_center(self, Rect2(LEFT, 426, WIDE, 28), note, M3.SMALL, M3.SECONDARY)
	RoundBox.fill(self, RESTORE_RECT, M3.SECONDARY_CONTAINER, RESTORE_RECT.size.y / 2.0)
	M3.text_center(self, RESTORE_RECT, "Restore from parent app", M3.BODY, M3.ON_SECONDARY_CONTAINER)
	RoundBox.frame(self, UNLINK_RECT.grow(-1), M3.ERROR, 2.0, UNLINK_RECT.size.y / 2.0 - 1)
	M3.text_center(self, UNLINK_RECT, "Unlink this tablet", M3.BODY, M3.ERROR)


func _draw_pick() -> void:
	var who := ""
	for p in profiles:
		if str(p["id"]) == picking:
			who = str(p["nickname"])
	M3.top_bar(self, "Who is %s?" % who, true)
	var current = family.child_of(picking)
	var opts := pick_options()
	for i in opts.size():
		var r := pick_rect(i)
		var mine: bool = opts[i]["child"] == current
		M3.button(self, r, "", M3.Style.FILLED if mine else M3.Style.TONAL)
		M3.text_center(self, r, str(opts[i]["label"]), M3.BODY, M3.ON_PRIMARY if mine else M3.ON_SECONDARY_CONTAINER)
	var y := pick_rect(opts.size() - 1).end.y + 16
	if y < 500:
		M3.text_center(self, Rect2(LEFT, y, WIDE, 28),
				"New child adds them to the parent app with this player's name and picture.", M3.SMALL,
				M3.ON_SURFACE_VARIANT)


func _beep() -> void:
	if not is_inside_tree():
		return
	var b := get_node_or_null("/root/Beeper")
	if b != null:
		b.call("good")
