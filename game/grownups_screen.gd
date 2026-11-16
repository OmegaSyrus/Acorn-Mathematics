## The Grown-ups panel (Terrence 2026-11-12: "world open from the map menu at
## the moment, parent unlocks and child picks"), from the main menu's
## Grown-ups button held for 3 seconds. One row per world: a world already
## opened by play says "Open"; any other world toggles between "Locked" and
## "Open" (save["parent_open"], kept in the profile). The child then picks
## from the open worlds on the map. Back returns to the main menu.
extends Node2D

signal back

const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const AreaFlow := preload("res://logic/path/area_flow.gd")

const INK := Color(0.96, 0.94, 0.9)
const DIM := Color(0.8, 0.76, 0.72)
const GOLD := Color(1.0, 0.82, 0.35)
const GREY := Color(0.3, 0.27, 0.26)
const GREEN := Color(0.2, 0.55, 0.3)
const BACK_RECT := Rect2(120, 20, 140, 60)
const ROW_Y := [130.0, 204.0, 278.0, 352.0, 426.0]
const TOGGLE_X := 560.0
const TOGGLE_SIZE := Vector2(200, 60)

var save: Dictionary
var worlds: Array = []
var choice: ChoiceWidget


func setup(profile: Dictionary, world_list: Array) -> void:
	save = profile
	worlds = world_list.slice(0, ROW_Y.size())
	if typeof(save.get("parent_open")) != TYPE_ARRAY:
		save["parent_open"] = []


func toggle_rect(i: int) -> Rect2:
	return Rect2(Vector2(TOGGLE_X, ROW_Y[i]), TOGGLE_SIZE)


## Opened by play: nothing to toggle.
func _won(i: int) -> bool:
	return AreaFlow.world_unlocked_by_play(save, worlds, i)


func _ready() -> void:
	choice = ChoiceWidget.new()
	add_child(choice)
	var rects := [BACK_RECT]
	for i in worlds.size():
		rects.append(toggle_rect(i))
	var first := 0
	while true:
		choice.present(rects, first)
		var k: int = await choice.picked
		first = k
		if k == 0:
			back.emit()
			return
		var i := k - 1
		if _won(i):
			Beeper.tone(330.0, 0.08)
		else:
			var id := String(worlds[i]["id"])
			SaveData.set_parent_open(save, id, not SaveData.is_parent_open(save, id))
			Beeper.tone(660.0, 0.08)
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.1, 0.1, 0.13))
	draw_string(font, Vector2(280, 64), "Grown-ups", HORIZONTAL_ALIGNMENT_CENTER, 400, 40, GOLD)
	_button(font, BACK_RECT, "Back", GREY, 30)
	draw_string(font, Vector2(120, 112), "Tap a world to open it on the map. The child picks from the open ones.",
			HORIZONTAL_ALIGNMENT_LEFT, 720, 18, DIM)
	for i in worlds.size():
		var w: Dictionary = worlds[i]
		var c: Array = w.get("color", [1, 1, 1])
		draw_string(font, Vector2(150, ROW_Y[i] + 42), str(w["name"]), HORIZONTAL_ALIGNMENT_LEFT, 380, 30,
				Color(c[0], c[1], c[2]))
		var r := toggle_rect(i)
		if _won(i):
			_button(font, r, "Open", GREEN.darkened(0.35), 28)
			draw_string(font, Vector2(r.end.x + 12, r.position.y + 38), "by play", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, DIM)
		elif SaveData.is_parent_open(save, String(w["id"])):
			_button(font, r, "Open", GREEN, 28)
			RoundBox.frame(self, r, GOLD, 3.0, 14.0)
		else:
			_button(font, r, "Locked", GREY, 28)
	draw_string(font, Vector2(120, 528), "Beating a world's boss still opens the next one.", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 16, DIM)


func _button(font: Font, r: Rect2, text: String, col: Color, size: int) -> void:
	RoundBox.fill(self, r, col, 14.0)
	draw_string(font, r.position + Vector2(0, r.size.y / 2 + size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, size, INK)
