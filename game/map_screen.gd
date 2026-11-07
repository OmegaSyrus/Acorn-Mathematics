## Graybox map: pick a grade for the area, or resume its saved run.
## Marks show which grades this area has been beaten at.
extends Node2D

signal start(grade_id: int, resume: bool)
signal shop
## The grown-up reset, confirmed: main.gd wipes the save and opens the map again.
signal reset_save
signal _answered(yes: bool)

const SaveData := preload("res://logic/core/save_data.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const Look := preload("res://game/ui/look.gd")

## The store button, bottom right (inside the 4:3 band, x 120..840), with
## the gem count on it.
const SHOP_RECT := Rect2(624, 392, 200, 120)
const GEM_TEX := preload("res://art/lava/gem.png")
const Pointer := preload("res://game/ui/pointer.gd")

## Reset (Terrence 2026-11-07): a small grey button top right; it opens a
## question, and "Yes" only works if held down for HOLD_S seconds, so a child
## tapping around can't wipe the save by accident.
const RESET_RECT := Rect2(712, 20, 112, 52)
const PANEL := Rect2(310, 120, 520, 320)  # right of Ellwynn (x 130..290)
const NO_RECT := Rect2(345, 300, 200, 100)
const YES_RECT := Rect2(595, 300, 200, 100)
const HOLD_S := 3.0

var save: Dictionary
var area_id := "lava_1"
var grades: Dictionary
var buttons: Array = []  # [{rect, label, grade, resume}]
var choice: ChoiceWidget
var asking := false      # the reset question is up
var holding := false     # a finger is down on "Yes"
var hold_t := 0.0


func setup(profile: Dictionary, grade_table: Dictionary, area: String) -> void:
	save = profile
	grades = grade_table
	area_id = area
	Look.apply(save)  # the store's hero and dice, for the screens to come


func _ready() -> void:
	var available := []
	for gid in grades:
		if grades[gid]["available"]:
			available.append(gid)
	available.sort()
	var x0 := 480.0 - available.size() * 100.0
	for i in available.size():
		var gid: int = available[i]
		buttons.append({"rect": Rect2(x0 + i * 200 + 20, 230, 160, 96), "label": grades[gid]["name"],
				"grade": gid, "resume": false})
	var saved_run = save.get("run")
	if saved_run is Dictionary and saved_run.get("area") == area_id:
		buttons.append({"rect": Rect2(400, 370, 160, 84), "label": "Go", "grade": saved_run["grade"],
				"resume": true})
	var first := buttons.size() - 1
	buttons.append({"rect": SHOP_RECT, "label": "Shop", "shop": true, "resume": false})
	buttons.append({"rect": RESET_RECT, "label": "Reset", "reset": true, "resume": false})
	choice = ChoiceWidget.new()
	add_child(choice)
	var rects := []
	for b in buttons:
		rects.append(b["rect"])
	while true:
		choice.present(rects, first)
		var i: int = await choice.picked
		if buttons[i].get("reset", false):
			if await _ask_reset():
				reset_save.emit()
				return
			continue
		if buttons[i].get("shop", false):
			shop.emit()
			return
		start.emit(buttons[i]["grade"], buttons[i]["resume"])
		return


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
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.13, 0.09, 0.08))
	draw_string(font, Vector2(120, 140), "Lava Caves", HORIZONTAL_ALIGNMENT_CENTER, 720, 52, Color(1.0, 0.6, 0.25))
	for b in buttons:
		var r: Rect2 = b["rect"]
		if b.get("shop", false):
			_draw_shop(font, r)
			continue
		if b.get("reset", false):
			RoundBox.fill(self, r, Color(0.3, 0.27, 0.26), 14.0)
			draw_string(font, r.position + Vector2(0, 35), "Reset", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24,
					Color(0.8, 0.76, 0.72))
			continue
		RoundBox.fill(self, r, Color(0.3, 0.5, 0.32) if b["resume"] else Color(0.42, 0.36, 0.33), 18.0)
		draw_string(font, r.position + Vector2(0, r.size.y / 2 + 12), b["label"], HORIZONTAL_ALIGNMENT_CENTER,
				r.size.x, 32, Color(0.96, 0.94, 0.9))
		if not b["resume"] and SaveData.has_mark(save, area_id, b["grade"]):
			draw_circle(r.position + Vector2(r.size.x - 14, 14), 10.0, Color(1.0, 0.8, 0.2))
	draw_string(font, Vector2(330, 520), "stickers: %d" % save["stickers"].size(), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 16, Color(0.6, 0.55, 0.5))
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


## The Shop button: a gem-purple box, "Shop", and the gems to spend.
func _draw_shop(font: Font, r: Rect2) -> void:
	RoundBox.fill(self, r, Color(0.46, 0.28, 0.6), 18.0)
	RoundBox.frame(self, r, Color(1.0, 0.82, 0.35), 3.0, 18.0)
	draw_string(font, r.position + Vector2(0, 50), "Shop", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 40, Color(0.96, 0.94, 0.9))
	var gem_at := r.position + Vector2(r.size.x / 2.0 - 58, 62)
	draw_texture_rect(GEM_TEX, Rect2(gem_at, Vector2(48, 48)), false)
	draw_string(font, gem_at + Vector2(54, 38), str(int(save.get("gems", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 36,
			Color(1.0, 0.86, 0.5))
