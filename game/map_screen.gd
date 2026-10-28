## Graybox map: pick a grade for the area, or resume its saved run.
## Marks show which grades this area has been beaten at.
extends Node2D

signal start(grade_id: int, resume: bool)

const SaveData := preload("res://logic/core/save_data.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")

var save: Dictionary
var area_id := "lava_1"
var grades: Dictionary
var buttons: Array = []  # [{rect, label, grade, resume}]
var choice: ChoiceWidget


func setup(profile: Dictionary, grade_table: Dictionary, area: String) -> void:
	save = profile
	grades = grade_table
	area_id = area


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
	choice = ChoiceWidget.new()
	add_child(choice)
	var rects := []
	for b in buttons:
		rects.append(b["rect"])
	choice.present(rects, buttons.size() - 1)
	var i: int = await choice.picked
	start.emit(buttons[i]["grade"], buttons[i]["resume"])


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.13, 0.09, 0.08))
	draw_string(font, Vector2(120, 140), "Lava Caves", HORIZONTAL_ALIGNMENT_CENTER, 720, 52, Color(1.0, 0.6, 0.25))
	draw_string(font, Vector2(120, 520), "gems: %d" % int(save.get("gems", 0)), HORIZONTAL_ALIGNMENT_RIGHT, 720, 16,
			Color(0.6, 0.55, 0.5))
	for b in buttons:
		var r: Rect2 = b["rect"]
		RoundBox.fill(self, r, Color(0.3, 0.5, 0.32) if b["resume"] else Color(0.42, 0.36, 0.33), 18.0)
		draw_string(font, r.position + Vector2(0, r.size.y / 2 + 12), b["label"], HORIZONTAL_ALIGNMENT_CENTER,
				r.size.x, 32, Color(0.96, 0.94, 0.9))
		if not b["resume"] and SaveData.has_mark(save, area_id, b["grade"]):
			draw_circle(r.position + Vector2(r.size.x - 14, 14), 10.0, Color(1.0, 0.8, 0.2))
	draw_string(font, Vector2(120, 520), "stickers: %d" % save["stickers"].size(), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 16, Color(0.6, 0.55, 0.5))
