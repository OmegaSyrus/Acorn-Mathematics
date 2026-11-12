## The grown-up Debug screen (Terrence 2026-11-08), from the Debug button
## beside Reset on the main menu: test every world, level, miniboss and boss
## without playing up to them.
## - "Level" 1 to 6 picks the level the jump uses (kept as the menu's Difficulty).
## - Each built world has Walk (its crossing), Mini (the miniboss duel) and
##   Boss (the boss fight). Each starts fresh at the picked level; what comes
##   after it runs as usual (a won duel goes on to the boss, then the map).
## - "Map: all open" unlocks every world on the map (save["debug_unlock"]);
##   Reset clears it with the rest of the save.
extends Node2D

signal back
## A jump: the world's area id, the level number (1 to 6) and "" (the
## crossing), "duel" or "boss".
signal jump(area_id: String, level: int, stage: String)

const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")

const INK := Color(0.96, 0.94, 0.9)
const DIM := Color(0.8, 0.76, 0.72)
const GOLD := Color(1.0, 0.82, 0.35)
const BACK_RECT := Rect2(120, 20, 140, 60)
const UNLOCK_RECT := Rect2(560, 20, 280, 60)
const LEVEL_X := 300.0
const LEVEL_Y := 100.0
const LEVEL_SIZE := Vector2(80, 64)
## one row per built world, up to all five (2026-11-12: Space is built)
const ROW_Y := [176.0, 246.0, 316.0, 386.0, 456.0]
const STAGES := [["Walk", ""], ["Mini", "duel"], ["Boss", "boss"]]
const STAGE_X := [310.0, 490.0, 670.0]
const STAGE_SIZE := Vector2(160, 60)

var save: Dictionary
var worlds: Array = []   # the built worlds (with an area), one row each
var level := 1
var buttons: Array = []  # [{rect, kind, ...}]
var choice: ChoiceWidget


func setup(profile: Dictionary, world_list: Array) -> void:
	save = profile
	for w in world_list:
		if w.has("area") and worlds.size() < ROW_Y.size():
			worlds.append(w)
	level = clampi(int(save.get("difficulty", 1)), 1, 6)


func _ready() -> void:
	buttons.append({"rect": BACK_RECT, "kind": "back"})
	buttons.append({"rect": UNLOCK_RECT, "kind": "unlock"})
	for n in range(1, 7):
		buttons.append({"rect": Rect2(Vector2(LEVEL_X + (n - 1) * (LEVEL_SIZE.x + 10), LEVEL_Y), LEVEL_SIZE),
				"kind": "level", "level": n})
	for r in worlds.size():
		for s in STAGES.size():
			buttons.append({"rect": Rect2(Vector2(STAGE_X[s], ROW_Y[r]), STAGE_SIZE), "kind": "stage",
					"area": str(worlds[r]["area"]), "stage": STAGES[s][1]})
	choice = ChoiceWidget.new()
	add_child(choice)
	var rects := []
	for b in buttons:
		rects.append(b["rect"])
	var first := 0
	while true:
		choice.present(rects, first)
		var i: int = await choice.picked
		first = i
		var b: Dictionary = buttons[i]
		match b["kind"]:
			"back":
				back.emit()
				return
			"unlock":
				save["debug_unlock"] = not bool(save.get("debug_unlock", false))
				Beeper.tone(660.0, 0.08)
			"level":
				level = int(b["level"])
				save["difficulty"] = level
				Beeper.tone(660.0, 0.08)
			"stage":
				Beeper.good()
				jump.emit(str(b["area"]), level, str(b["stage"]))
				return
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.1, 0.1, 0.13))
	draw_string(font, Vector2(260, 62), "Debug", HORIZONTAL_ALIGNMENT_CENTER, 300, 40, GOLD)
	draw_string(font, Vector2(120, LEVEL_Y + 44), "Level", HORIZONTAL_ALIGNMENT_LEFT, 170, 32, INK)
	for b in buttons:
		var r: Rect2 = b["rect"]
		match b["kind"]:
			"back":
				_button(font, r, "Back", Color(0.3, 0.27, 0.26), 30)
			"unlock":
				var on := bool(save.get("debug_unlock", false))
				_button(font, r, "Map: all open" if on else "Map: locked",
						Color(0.2, 0.55, 0.3) if on else Color(0.3, 0.27, 0.26), 28)
			"level":
				var picked := int(b["level"]) == level
				_button(font, r, str(b["level"]), Color(0.62, 0.45, 0.12) if picked else Color(0.3, 0.27, 0.26), 34)
				if picked:
					RoundBox.frame(self, r, GOLD, 4.0, 14.0)
			"stage":
				var col := Color(0.2, 0.62, 0.3)
				if b["stage"] == "duel":
					col = Color(0.55, 0.35, 0.15)
				elif b["stage"] == "boss":
					col = Color(0.62, 0.2, 0.18)
				_button(font, r, STAGES[["", "duel", "boss"].find(b["stage"])][0], col, 30)
	for r in worlds.size():
		var w: Dictionary = worlds[r]
		var c: Array = w.get("color", [1, 1, 1])
		draw_string(font, Vector2(120, ROW_Y[r] + 40), str(w["name"]), HORIZONTAL_ALIGNMENT_LEFT, 185, 26,
				Color(c[0], c[1], c[2]))
	draw_string(font, Vector2(120, 528), "Each jump starts fresh at the picked level.", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 18, DIM)


func _button(font: Font, r: Rect2, text: String, col: Color, size: int) -> void:
	RoundBox.fill(self, r, col, 14.0)
	draw_string(font, r.position + Vector2(0, r.size.y / 2 + size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, size, INK)
