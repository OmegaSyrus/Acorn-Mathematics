## The Grown-ups panel, from the main menu's Grown-ups button (after the
## parent PIN). It shows where the child is: their Level, and each world
## done or not at it. The Level buttons 1 to 6 pick the Level the child
## plays (Terrence 2026-11-17: a parent changes the Level); picking one
## opens it (AreaFlow.pick_level). Worlds inside a Level still open by play;
## Debug stays for testing.
## Children opens the tablet's child profiles; PIN sets or changes the parent
## PIN that guards this panel (parent app plan v2). Back returns to the main
## menu.
extends Node2D

signal back
signal children
signal pin

const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const AreaFlow := preload("res://logic/path/area_flow.gd")
const Content := preload("res://logic/core/content.gd")

const INK := Color(0.96, 0.94, 0.9)
const DIM := Color(0.8, 0.76, 0.72)
const GOLD := Color(1.0, 0.82, 0.35)
const GREY := Color(0.3, 0.27, 0.26)
const GREEN := Color(0.2, 0.55, 0.3)
const BACK_RECT := Rect2(120, 20, 140, 60)
const CHILDREN_RECT := Rect2(530, 20, 150, 60)
const PIN_RECT := Rect2(690, 20, 150, 60)
const ROW_Y := [160.0, 225.0, 290.0, 355.0, 420.0]
## The Level buttons, 1 to 6, on the row under the title.
const LEVEL_X := 240.0
const LEVEL_Y := 92.0
const LEVEL_SIZE := Vector2(64, 52)
const LEVEL_GAP := 12.0
const STATE_RECT := Rect2(560, 0, 200, 56)

var save: Dictionary
var worlds: Array = []
var level := 1
var choice: ChoiceWidget
## A parent PIN is set (main.gd passes it; the PIN button says Set or Change).
var has_pin := false


func setup(profile: Dictionary, world_list: Array) -> void:
	save = profile
	worlds = world_list.slice(0, ROW_Y.size())
	level = clampi(int(save.get("difficulty", 1)), 1, AreaFlow.level_reached(save, world_list))


static func level_rect(n: int) -> Rect2:
	return Rect2(Vector2(LEVEL_X + (n - 1) * (LEVEL_SIZE.x + LEVEL_GAP), LEVEL_Y), LEVEL_SIZE)


## What a world row says at the child's Level: "Done", "Next" or "Locked".
func state_of(i: int) -> String:
	if AreaFlow.world_beaten(save, String(worlds[i]["id"]), level):
		return "Done"
	if AreaFlow.world_open(save, worlds, i, level):
		return "Next"
	return "Locked"


func _ready() -> void:
	choice = ChoiceWidget.new()
	add_child(choice)
	var rects := [BACK_RECT, CHILDREN_RECT, PIN_RECT]
	for n in range(1, Content.LEVEL_COUNT + 1):
		rects.append(level_rect(n))
	var first := 0
	while true:
		choice.present(rects, first)
		var k: int = await choice.picked
		if k >= 3:
			level = k - 2
			AreaFlow.pick_level(save, level)
			Beeper.tone(660.0, 0.08)
			first = k
			queue_redraw()
			continue
		if k == 1:
			children.emit()
		elif k == 2:
			pin.emit()
		else:
			back.emit()
		return


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.1, 0.1, 0.13))
	draw_string(font, Vector2(270, 62), "Grown-ups", HORIZONTAL_ALIGNMENT_CENTER, 250, 36, GOLD)
	_button(font, BACK_RECT, "Back", GREY, 30)
	_button(font, CHILDREN_RECT, "Children", Color(0.24, 0.3, 0.38), 26)
	_button(font, PIN_RECT, "Change PIN" if has_pin else "Set PIN", Color(0.24, 0.3, 0.38), 24)
	draw_string(font, Vector2(120, LEVEL_Y + 37), "Level", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK)
	for n in range(1, Content.LEVEL_COUNT + 1):
		var lr := level_rect(n)
		RoundBox.fill(self, lr, GOLD.darkened(0.15) if n == level else GREY, 12.0)
		draw_string(font, lr.position + Vector2(0, 37), str(n), HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, 30,
				Color(0.1, 0.07, 0.05) if n == level else INK)
	for i in worlds.size():
		var w: Dictionary = worlds[i]
		var c: Array = w.get("color", [1, 1, 1])
		draw_string(font, Vector2(150, ROW_Y[i] + 38), str(w["name"]), HORIZONTAL_ALIGNMENT_LEFT, 380, 28,
				Color(c[0], c[1], c[2]))
		var r := Rect2(STATE_RECT.position + Vector2(0, ROW_Y[i]), STATE_RECT.size)
		var st := state_of(i)
		RoundBox.fill(self, r, GREEN if st == "Done" else (GREEN.darkened(0.35) if st == "Next" else GREY), 14.0)
		draw_string(font, r.position + Vector2(0, 37), st, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, INK)
	draw_string(font, Vector2(120, 520), "Tap a Level to play it. Worlds open by beating the one before.",
			HORIZONTAL_ALIGNMENT_LEFT, 720, 18, DIM)


func _button(font: Font, r: Rect2, text: String, col: Color, size: int) -> void:
	RoundBox.fill(self, r, col, 14.0)
	draw_string(font, r.position + Vector2(0, r.size.y / 2 + size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, size, INK)
