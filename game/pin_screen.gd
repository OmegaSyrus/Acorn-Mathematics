## The parent PIN (parent app plan v2: a PIN on anything that pairs devices
## or changes settings). Four digits on a number pad, hashed on the tablet
## (logic/core/profiles.gd); it never leaves it.
##
## Modes: ENTER asks for the PIN before the Grown-ups panel; SET asks for a
## new one twice (with Remove when one is set). "Forgot PIN?" on ENTER asks a
## grown-up sum (two 2-digit numbers to add); the right answer clears the PIN.
extends Node2D

## ok: ENTER passed (or the PIN was cleared by Forgot), or SET saved/removed.
signal done(ok: bool)

const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const Profiles := preload("res://logic/core/profiles.gd")

enum Mode { ENTER, SET }

const INK := Color(0.96, 0.94, 0.9)
const DIM := Color(0.8, 0.76, 0.72)
const GOLD := Color(1.0, 0.82, 0.35)
const RED := Color(0.85, 0.35, 0.3)
const GREY := Color(0.3, 0.27, 0.26)
const BACK_RECT := Rect2(120, 20, 140, 60)
const SIDE_RECT := Rect2(640, 20, 200, 60)  # Forgot PIN? or Remove PIN
const KEY := Vector2(100, 70)
const KEY_GAP := 12.0
const PAD_X := 480.0 - (3 * 100.0 + 2 * 12.0) / 2.0
const PAD_Y := 196.0
## Keys in pad order: 1-9, then Clear, 0, OK.
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]

var roster: Dictionary
var mode := Mode.ENTER
var stage := "enter"  # enter | new | again | forgot
var typed := ""
var first := ""
var message := ""
var question := Vector2i()
var choice: ChoiceWidget


func setup(r: Dictionary, m: Mode) -> void:
	roster = r
	mode = m
	stage = "enter" if m == Mode.ENTER else "new"


static func key_rect(i: int) -> Rect2:
	return Rect2(Vector2(PAD_X + (i % 3) * (KEY.x + KEY_GAP), PAD_Y + (i / 3) * (KEY.y + KEY_GAP)), KEY)


func _title() -> String:
	match stage:
		"enter":
			return "Grown-ups PIN"
		"new":
			return "Pick a new PIN"
		"again":
			return "Type it again"
	return "What is %d + %d?" % [question.x, question.y]


func _has_side() -> bool:
	return stage == "enter" or (mode == Mode.SET and Profiles.has_pin(roster) and stage == "new")


func _ready() -> void:
	choice = ChoiceWidget.new()
	choice.show_highlight = false
	add_child(choice)
	while true:
		var rects := [BACK_RECT]
		for i in KEYS.size():
			rects.append(key_rect(i))
		if _has_side():
			rects.append(SIDE_RECT)
		queue_redraw()
		choice.present(rects, 0)
		var k: int = await choice.picked
		if k == 0:
			done.emit(false)
			return
		if k == KEYS.size() + 1:
			if stage == "enter":
				_start_forgot()
			else:
				Profiles.clear_pin(roster)
				Beeper.good()
				done.emit(true)
				return
			continue
		if _key(KEYS[k - 1]):
			return


func _start_forgot() -> void:
	stage = "forgot"
	typed = ""
	message = "Grown-ups only"
	question = Vector2i(randi_range(23, 79), randi_range(23, 79))


## One key. True when the screen is finished (done was emitted).
func _key(key: String) -> bool:
	if key == "C":
		typed = ""
		message = ""
		Beeper.tone(330.0, 0.06)
		return false
	if key == "OK":
		return _submit()
	var limit := 3 if stage == "forgot" else Profiles.PIN_LEN
	if typed.length() < limit:
		typed += key
		Beeper.tone(520.0, 0.05)
	if stage != "forgot" and typed.length() == Profiles.PIN_LEN:
		return _submit()
	return false


func _submit() -> bool:
	match stage:
		"forgot":
			if typed.is_valid_int() and int(typed) == question.x + question.y:
				Profiles.clear_pin(roster)
				Beeper.good()
				done.emit(true)
				return true
			_wrong("Not quite")
			_start_forgot()
		"enter":
			if Profiles.check_pin(roster, typed):
				Beeper.good()
				done.emit(true)
				return true
			_wrong("Wrong PIN")
		"new":
			if Profiles.valid_pin(typed):
				first = typed
				typed = ""
				stage = "again"
				message = ""
		"again":
			if typed == first and Profiles.set_pin(roster, typed):
				Beeper.good()
				done.emit(true)
				return true
			first = ""
			stage = "new"
			_wrong("They did not match")
	return false


func _wrong(text: String) -> void:
	typed = ""
	message = text
	Beeper.bad()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.1, 0.1, 0.13))
	RoundBox.fill(self, BACK_RECT, GREY, 14.0)
	draw_string(font, BACK_RECT.position + Vector2(0, 41), "Back", HORIZONTAL_ALIGNMENT_CENTER, BACK_RECT.size.x, 30, INK)
	if _has_side():
		RoundBox.fill(self, SIDE_RECT, GREY, 14.0)
		draw_string(font, SIDE_RECT.position + Vector2(0, 38), "Forgot PIN?" if stage == "enter" else "Remove PIN",
				HORIZONTAL_ALIGNMENT_CENTER, SIDE_RECT.size.x, 24, DIM)
	draw_string(font, Vector2(120, 120), _title(), HORIZONTAL_ALIGNMENT_CENTER, 720, 38, GOLD)
	if stage == "forgot":
		draw_string(font, Vector2(120, 176), typed if typed != "" else "_", HORIZONTAL_ALIGNMENT_CENTER, 720, 36, INK)
	else:
		for i in Profiles.PIN_LEN:
			var c := Vector2(480 - 60 + i * 40, 162)
			if i < typed.length():
				draw_circle(c, 11, INK)
			else:
				draw_arc(c, 11, 0, TAU, 24, DIM, 2.0)
	if message != "":
		draw_string(font, Vector2(120, 528), message, HORIZONTAL_ALIGNMENT_CENTER, 720, 22, RED if message != "Grown-ups only" else DIM)
	for i in KEYS.size():
		var r := key_rect(i)
		var k: String = KEYS[i]
		var col := Color(0.24, 0.3, 0.38)
		if k == "OK":
			col = Color(0.2, 0.55, 0.3)
		elif k == "C":
			col = GREY
		RoundBox.fill(self, r, col, 14.0)
		draw_string(font, r.position + Vector2(0, 48), k, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, INK)
