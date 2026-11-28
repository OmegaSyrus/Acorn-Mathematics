## The main menu (Terrence 2026-11-07): "Level: 1" (Phase 1, 2026-11-16:
## the child's Level, tap it to step back through the Levels they have
## reached to replay one; it was "Difficulty"), a big Play that goes
## to the map of the worlds, the Shop and the grown-up Reset. A crossing in
## progress picks up again from its world on the map.
extends Node2D

signal start(grade_id: int, resume: bool)
signal shop
## The grown-up reset, confirmed: main.gd wipes the save and opens the map again.
signal reset_save
## The grown-up Debug button, beside Reset: main.gd opens the debug screen.
signal debug
## The Grown-ups button tapped: main.gd asks for the parent PIN (or has a
## grown-up make one) and opens the Grown-ups panel.
signal grown_ups
## The player button (top left): main.gd opens the profile page (S3).
signal who
## The Book button (Phase 6): main.gd opens the monster book.
signal book
## The modes (Phase 6): Arena (fights only) and Bounce (beaten bosses again),
## each tapped while open; main.gd opens them (game/modes_flow.gd).
signal arena
signal bounce
signal _answered(yes: bool)

const SaveData := preload("res://logic/core/save_data.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const Look := preload("res://game/ui/look.gd")

## The store button, bottom right (inside the 4:3 band, x 120..840), with
## the gem count on it.
const SHOP_RECT := Rect2(624, 392, 200, 120)
## Right of Ellwynn (bottom left, x 150..310): buttons stay right of x 380.
## (Phase 6: 30 higher, to make room for the row of small buttons below.)
const DIFF_RECT := Rect2(604, 166, 200, 96)
## The row of small buttons between the Level marks and Play (Phase 6):
## Book first; two more modes fit after it at x 544 and 692, same size.
const ROW_Y := 312.0
const BOOK_RECT := Rect2(396, ROW_Y, 136, 60)
const PLAY_RECT := Rect2(396, 392, 200, 120)
const GEM_TEX := preload("res://art/lava/gem.png")
const Pointer := preload("res://game/ui/pointer.gd")
## The oak on the hill, birds and wandering animals (drawn behind the buttons).
const MenuScene := preload("res://game/ui/menu_scene.gd")
const Marks := preload("res://game/ui/marks.gd")
const Content := preload("res://logic/core/content.gd")
const Modes := preload("res://logic/modes/modes.gd")
## The modes (Phase 6), in the row of small buttons between the Level marks
## and Play, after the Book's place at x 396. Locked ones show a lock and
## beep "no"; a mode just opened wears "New!" until first tapped.
const ARENA_RECT := Rect2(544, 312, 136, 60)
const BOUNCE_RECT := Rect2(692, 312, 136, 60)
const EllwynnRef := preload("res://game/ellwynn.gd")

## Reset (Terrence 2026-11-07): a small grey button top right; it opens a
## question, and "Yes" only works if held down for HOLD_S seconds, so a child
## tapping around can't wipe the save by accident.
const RESET_RECT := Rect2(712, 20, 112, 52)
## Debug (Terrence 2026-11-08): the same small grey button, left of Reset.
const DEBUG_RECT := Rect2(588, 20, 112, 52)
## Grown-ups (Terrence 2026-11-17: the held grey padlock button looked
## blocked): a blue button, left of Debug, opened by a plain tap. The
## parent PIN keeps children out (main.gd: the PIN, or making one first).
const GATE_RECT := Rect2(416, 20, 152, 52)
## Who is playing (parent app plan v2): the player's picture and name, top
## left; a tap opens the profile page (S3: Play, Swap, Edit). 72 tall
## (2026-11-17) so the picture shows 40% more and the fox's ears fit.
const PLAYER_RECT := Rect2(120, 10, 270, 72)
## The part of the profile picture shown on the player button, at 1:1.
const FACE := Vector2(73, 62)
const WhoScreen := preload("res://game/who_screen.gd")
const PANEL := Rect2(310, 120, 520, 320)  # right of Ellwynn (x 130..290)
const NO_RECT := Rect2(345, 300, 200, 100)
const YES_RECT := Rect2(595, 300, 200, 100)
const HOLD_S := 3.0
const TITLE_EDGE := Color(0.2, 0.1, 0.05)

var save: Dictionary
var area_id := "lava_1"
var grades: Dictionary
var available: Array = []  # the grade ids that can be picked, in order
var grade_id := 1          # the difficulty picked (kept in the save as "difficulty")
var buttons: Array = []  # [{rect, label, grade, resume}]
var choice: ChoiceWidget
var asking := false      # the reset question is up
var holding := false     # a finger is down on "Yes"
var hold_t := 0.0
var _mark_worlds: Array = []  # [{id, color, ids}] the built worlds, for the marks under the difficulty
## The player shown on the player button: {nickname, picture} (main.gd sets it).
var player := {}


func setup(profile: Dictionary, grade_table: Dictionary, area: String) -> void:
	save = profile
	grades = grade_table
	area_id = area
	Look.apply(save)  # the store's hero and dice, for the screens to come
	for w in Content.worlds():
		if w.has("area"):
			_mark_worlds.append({"id": String(w["id"]), "color": w.get("color", [0.8, 0.6, 0.4]),
					"ids": Content.level_ids(String(w["id"]))})


func _ready() -> void:
	add_child(MenuScene.new())
	for gid in grades:
		if grades[gid]["available"]:
			available.append(gid)
	available.sort()
	grade_id = int(save.get("difficulty", available[0] if not available.is_empty() else 1))
	if not available.has(grade_id) and not available.is_empty():
		grade_id = available[0]
	buttons.append({"rect": PLAY_RECT, "label": "Play", "play": true, "grade": grade_id, "resume": false})
	buttons.append({"rect": DIFF_RECT, "label": "", "difficulty": true, "resume": false})
	var first := 0
	buttons.append({"rect": SHOP_RECT, "label": "Shop", "shop": true, "resume": false})
	buttons.append({"rect": RESET_RECT, "label": "Reset", "reset": true, "resume": false})
	buttons.append({"rect": DEBUG_RECT, "label": "Debug", "debug": true, "resume": false})
	buttons.append({"rect": GATE_RECT, "label": "Grown-ups", "gate": true, "resume": false})
	buttons.append({"rect": BOOK_RECT, "label": "Book", "book": true, "resume": false})
	buttons.append({"rect": ARENA_RECT, "label": "Arena", "mode": Modes.ARENA, "resume": false})
	buttons.append({"rect": BOUNCE_RECT, "label": "Bounce", "mode": Modes.BOUNCE, "resume": false})
	if not player.is_empty():
		WhoScreen.picture(str(player.get("picture", "")))  # loaded before _draw
		buttons.append({"rect": PLAYER_RECT, "label": "", "who": true, "resume": false})
	choice = ChoiceWidget.new()
	add_child(choice)
	var rects := []
	for b in buttons:
		rects.append(b["rect"])
	while true:
		choice.present(rects, first)
		var i: int = await choice.picked
		# any button cuts her off; Play and Shop then say their own (main.gd)
		var ell := EllwynnRef.here(self)
		if ell != null:
			ell.stop_voice()
		if buttons[i].get("reset", false):
			if await _ask_reset():
				reset_save.emit()
				return
			continue
		if buttons[i].get("debug", false):
			debug.emit()
			return
		if buttons[i].get("gate", false):
			grown_ups.emit()
			return
		if buttons[i].get("who", false):
			who.emit()
			return
		if buttons[i].get("shop", false):
			shop.emit()
			return
		if buttons[i].get("book", false):
			book.emit()
			return
		if buttons[i].has("mode"):
			if _tap_mode(String(buttons[i]["mode"])):
				return
			first = i
			continue
		if buttons[i].get("difficulty", false):
			_next_difficulty()
			if ell != null:
				ell.cue_play("M7")
			first = i
			continue
		save["difficulty"] = grade_id
		start.emit(grade_id, false)
		return


## A mode button tapped: an open one loses its "New!" and opens (true);
## a locked one gives a soft "no" beep and the menu stays (false).
func _tap_mode(mode: String) -> bool:
	if not Modes.is_open(save, mode):
		Beeper.tone(220.0, 0.18, -14.0)
		return false
	Modes.mark_seen(save, mode)
	if mode == Modes.ARENA:
		arena.emit()
	else:
		bounce.emit()
	return true


## Tapping the difficulty steps to the next open one (round again after the last).
func _next_difficulty() -> void:
	if available.size() < 2:
		Beeper.tone(330.0, 0.08)
		return
	grade_id = available[(available.find(grade_id) + 1) % available.size()]
	save["difficulty"] = grade_id
	Beeper.tone(660.0, 0.08)
	queue_redraw()


## The reset question. True once "Yes" has been held down long enough;
## false on "No" or a tap outside the box.
func _ask_reset() -> bool:
	asking = true
	holding = false
	hold_t = 0.0
	queue_redraw()
	var yes: bool = await _answered
	asking = false
	holding = false
	queue_redraw()
	return yes


func _unhandled_input(event: InputEvent) -> void:
	if not asking:
		return
	var p := Pointer.local_pos(self, event) if (Pointer.is_press(event) or Pointer.is_release(event) or Pointer.is_drag(event)) else Vector2(-1, -1)
	if Pointer.is_press(event):
		get_viewport().set_input_as_handled()
		if YES_RECT.has_point(p):
			holding = true
			hold_t = 0.0
		elif NO_RECT.has_point(p) or not PANEL.has_point(p):
			_answered.emit(false)
	elif Pointer.is_drag(event) and holding and not YES_RECT.grow(30).has_point(p):
		holding = false  # slid off: start over
		hold_t = 0.0
	elif Pointer.is_release(event) and holding:
		holding = false
		hold_t = 0.0


func _process(delta: float) -> void:
	if not asking:
		return
	if holding:
		hold_t += delta
		if hold_t >= HOLD_S:
			holding = false
			Beeper.good()
			_answered.emit(true)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# the backdrop is the MenuScene child; the title gets a dark edge to read on the sky
	draw_string_outline(font, Vector2(120, 140), "Acorn Math", HORIZONTAL_ALIGNMENT_CENTER, 720, 52, 12, TITLE_EDGE)
	draw_string(font, Vector2(120, 140), "Acorn Math", HORIZONTAL_ALIGNMENT_CENTER, 720, 52, Color(1.0, 0.6, 0.25))
	for b in buttons:
		var r: Rect2 = b["rect"]
		if b.get("difficulty", false):
			_draw_difficulty(font, r)
			continue
		if b.get("play", false):
			RoundBox.fill(self, r, Color(0.2, 0.62, 0.3), 18.0)
			RoundBox.frame(self, r, Color(1.0, 0.82, 0.35), 3.0, 18.0)
			draw_string(font, r.position + Vector2(0, r.size.y / 2 + 16), "Play", HORIZONTAL_ALIGNMENT_CENTER,
					r.size.x, 48, Color(0.96, 0.94, 0.9))
			continue
		if b.get("shop", false):
			_draw_shop(font, r)
			continue
		if b.get("book", false):
			_draw_book(font, r)
			continue
		if b.get("debug", false):
			RoundBox.fill(self, r, Color(0.3, 0.27, 0.26), 14.0)
			draw_string(font, r.position + Vector2(0, 35), "Debug", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24,
					Color(0.8, 0.76, 0.72))
			continue
		if b.has("mode"):
			_draw_mode(font, r, String(b["mode"]), String(b["label"]))
			continue
		if b.get("reset", false):
			RoundBox.fill(self, r, Color(0.3, 0.27, 0.26), 14.0)
			draw_string(font, r.position + Vector2(0, 35), "Reset", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24,
					Color(0.8, 0.76, 0.72))
			continue
	_draw_gate(font)
	_draw_player(font)
	var stickers := "stickers: %d" % save["stickers"].size()
	draw_string_outline(font, Vector2(330, 520), stickers, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, TITLE_EDGE)
	draw_string(font, Vector2(330, 520), stickers, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.82, 0.76))
	if asking:
		_draw_reset_question(font)


## Dims the menu; asks "Reset all?" with No (green) and Yes (red, hold it:
## a ring fills while it is held).
func _draw_reset_question(font: Font) -> void:
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0, 0, 0, 0.6))
	RoundBox.fill(self, PANEL, Color(0.16, 0.11, 0.1), 24.0)
	RoundBox.frame(self, PANEL, Color(1.0, 0.82, 0.35), 3.0, 24.0)
	var ink := Color(0.96, 0.94, 0.9)
	draw_string(font, PANEL.position + Vector2(0, 70), "Reset all?", HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x, 44, ink)
	draw_string(font, PANEL.position + Vector2(0, 116), "Gems, shop and saved play go away.", HORIZONTAL_ALIGNMENT_CENTER,
			PANEL.size.x, 22, Color(0.8, 0.76, 0.72))
	draw_string(font, PANEL.position + Vector2(0, 148), "Hold Yes to reset.", HORIZONTAL_ALIGNMENT_CENTER,
			PANEL.size.x, 22, Color(0.8, 0.76, 0.72))
	RoundBox.fill(self, NO_RECT, Color(0.3, 0.6, 0.35), 18.0)
	draw_string(font, NO_RECT.position + Vector2(0, 64), "No", HORIZONTAL_ALIGNMENT_CENTER, NO_RECT.size.x, 44, ink)
	RoundBox.fill(self, YES_RECT, Color(0.62, 0.2, 0.18), 18.0)
	draw_string(font, YES_RECT.position + Vector2(0, 64), "Yes", HORIZONTAL_ALIGNMENT_CENTER, YES_RECT.size.x, 44, ink)
	if holding:
		var c := YES_RECT.get_center()
		draw_arc(c, 62.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(hold_t / HOLD_S, 0.0, 1.0), 48, Color(1.0, 0.82, 0.35), 8.0)


## "Level:" and the Level's number in a box after it; a gold dot
## when an area has been beaten at it.
func _draw_difficulty(font: Font, r: Rect2) -> void:
	var ink := Color(0.96, 0.94, 0.9)
	var at := Vector2(r.position.x - 224, r.position.y + r.size.y / 2 + 12)
	draw_string_outline(font, at, "Level:", HORIZONTAL_ALIGNMENT_RIGHT, 210, 34, 9, TITLE_EDGE)
	draw_string(font, at, "Level:", HORIZONTAL_ALIGNMENT_RIGHT, 210, 34, ink)
	RoundBox.fill(self, r, Color(0.42, 0.36, 0.33), 18.0)
	var gname: String = grades[grade_id]["name"] if grades.has(grade_id) else "?"
	draw_string(font, r.position + Vector2(0, r.size.y / 2 + 12), gname, HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, 34, ink)
	_draw_level_marks(r)


## Under the difficulty: one mark per built world at this level, in the
## world's color until it is beaten (then gold), with the no-heart-lost star
## beside it (game/ui/marks.gd).
func _draw_level_marks(r: Rect2) -> void:
	var step := Marks.pair_width() + 10
	var n := _mark_worlds.size()
	if n == 0:
		return
	var x0 := roundf(r.get_center().x - (step * (n - 1) + Marks.pair_width()) / 2.0)
	var y := r.end.y + 12.0
	RoundBox.fill(self, Rect2(x0 - 8, y - 6, step * (n - 1) + Marks.pair_width() + 16, Marks.SIZE + 12),
			Color(0.07, 0.04, 0.08, 0.55), 6.0)
	for k in n:
		var w: Dictionary = _mark_worlds[k]
		var ids: Array = w["ids"]
		var id: int = ids[grade_id - 1] if grade_id >= 1 and grade_id <= ids.size() else 0
		var rgb: Array = w["color"]
		var tint := Color(rgb[0], rgb[1], rgb[2]).darkened(0.25)
		Marks.draw_pair(self, Vector2(x0 + k * step, y), id > 0 and SaveData.has_mark(save, w["id"], id),
				id > 0 and SaveData.has_star(save, w["id"], id), tint)


## A mode button: orange when open (with a red "New!" tag until first
## tapped), grey with a padlock when locked.
func _draw_mode(font: Font, r: Rect2, mode: String, label: String) -> void:
	var ink := Color(0.96, 0.94, 0.9)
	if not Modes.is_open(save, mode):
		RoundBox.fill(self, r, Color(0.3, 0.27, 0.26, 0.92), 14.0)
		draw_string(font, r.position + Vector2(40, 39), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 42, 24,
				Color(0.7, 0.66, 0.62))
		var c := r.position + Vector2(22, 32)
		draw_arc(c + Vector2(0, -4), 9.0, PI, TAU, 12, TITLE_EDGE, 5.0)
		RoundBox.fill(self, Rect2(c + Vector2(-13, -4), Vector2(26, 20)), TITLE_EDGE, 4.0)
		draw_circle(c + Vector2(0, 5), 3.0, Color(0.7, 0.66, 0.62))
		return
	RoundBox.fill(self, r, Color(0.8, 0.42, 0.14), 14.0)
	RoundBox.frame(self, r, Color(1.0, 0.82, 0.35), 3.0, 14.0)
	draw_string(font, r.position + Vector2(0, 41), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, ink)
	if Modes.is_new(save, mode):
		var tag := Rect2(r.end.x - 58, r.position.y - 14, 64, 28)
		RoundBox.fill(self, tag, Color(0.85, 0.15, 0.2), 10.0)
		RoundBox.frame(self, tag, ink, 2.0, 10.0)
		draw_string(font, tag.position + Vector2(0, 21), "New!", HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 18, ink)


## The Grown-ups button: blue like the Grown-ups panel's own buttons, with
## a light frame, so it reads as a button to tap.
func _draw_gate(font: Font) -> void:
	var r := GATE_RECT
	RoundBox.fill(self, r, Color(0.24, 0.34, 0.5), 14.0)
	RoundBox.frame(self, r, Color(0.75, 0.85, 1.0), 2.0, 14.0)
	draw_string(font, r.position + Vector2(0, 34), "Grown-ups", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22,
			Color(0.96, 0.94, 0.9))


## The player button: the top of their picture at 1:1 (head and ears) and
## their name.
func _draw_player(font: Font) -> void:
	if player.is_empty():
		return
	var r := PLAYER_RECT
	RoundBox.fill(self, r, Color(0.22, 0.36, 0.26, 0.9), 14.0)
	var tex := WhoScreen.picture(str(player.get("picture", "")))
	if tex != null:
		var w := minf(FACE.x, tex.get_width())
		var src := Rect2(roundf(tex.get_width() / 2.0 - w / 2.0), 0, w, FACE.y)
		draw_texture_rect_region(tex, Rect2(r.position + Vector2(6 + roundf((FACE.x - w) / 2.0), 5), src.size), src)
	draw_string(font, r.position + Vector2(FACE.x + 16, 45), str(player.get("nickname", "")), HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - FACE.x - 24, 24, Color(0.96, 0.94, 0.9))


## The Book button: a red-brown box with a little closed book and "Book".
func _draw_book(font: Font, r: Rect2) -> void:
	RoundBox.fill(self, r, Color(0.56, 0.26, 0.2), 14.0)
	RoundBox.frame(self, r, Color(1.0, 0.82, 0.35), 3.0, 14.0)
	var b := Rect2(r.position + Vector2(14, 13), Vector2(28, 34))
	draw_rect(b.grow(2), TITLE_EDGE)
	draw_rect(b, Color(0.3, 0.62, 0.38))
	draw_rect(Rect2(b.position + Vector2(4, 0), Vector2(2, b.size.y)), Color(0.18, 0.4, 0.24))
	draw_rect(Rect2(b.position + Vector2(10, 9), Vector2(13, 9)), Color(1.0, 0.82, 0.35))
	draw_string(font, r.position + Vector2(50, 40), "Book", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.96, 0.94, 0.9))


## The Shop button: a gem-purple box, "Shop", and the gems to spend.
func _draw_shop(font: Font, r: Rect2) -> void:
	RoundBox.fill(self, r, Color(0.46, 0.28, 0.6), 18.0)
	RoundBox.frame(self, r, Color(1.0, 0.82, 0.35), 3.0, 18.0)
	draw_string(font, r.position + Vector2(0, 50), "Shop", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 40, Color(0.96, 0.94, 0.9))
	var gem_at := r.position + Vector2(r.size.x / 2.0 - 58, 62)
	draw_texture_rect(GEM_TEX, Rect2(gem_at, Vector2(48, 48)), false)
	draw_string(font, gem_at + Vector2(54, 38), str(int(save.get("gems", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 36,
			Color(1.0, 0.86, 0.5))
