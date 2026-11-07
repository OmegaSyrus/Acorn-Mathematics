## Graybox map: pick a grade for the area, or resume its saved run.
## Marks show which grades this area has been beaten at.
extends Node2D

signal start(grade_id: int, resume: bool)
signal shop

const SaveData := preload("res://logic/core/save_data.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const Look := preload("res://game/ui/look.gd")

## The store button, bottom right (inside the 4:3 band, x 120..840), with
## the gem count on it.
const SHOP_RECT := Rect2(624, 392, 200, 120)
const GEM_TEX := preload("res://art/lava/gem.png")

var save: Dictionary
var area_id := "lava_1"
var grades: Dictionary
var buttons: Array = []  # [{rect, label, grade, resume}]
var choice: ChoiceWidget


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
	choice = ChoiceWidget.new()
	add_child(choice)
	var rects := []
	for b in buttons:
		rects.append(b["rect"])
	choice.present(rects, first)
	var i: int = await choice.picked
	if buttons[i].get("shop", false):
		shop.emit()
		return
	start.emit(buttons[i]["grade"], buttons[i]["resume"])


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.13, 0.09, 0.08))
	draw_string(font, Vector2(120, 140), "Lava Caves", HORIZONTAL_ALIGNMENT_CENTER, 720, 52, Color(1.0, 0.6, 0.25))
	for b in buttons:
		var r: Rect2 = b["rect"]
		if b.get("shop", false):
			_draw_shop(font, r)
			continue
		RoundBox.fill(self, r, Color(0.3, 0.5, 0.32) if b["resume"] else Color(0.42, 0.36, 0.33), 18.0)
		draw_string(font, r.position + Vector2(0, r.size.y / 2 + 12), b["label"], HORIZONTAL_ALIGNMENT_CENTER,
				r.size.x, 32, Color(0.96, 0.94, 0.9))
		if not b["resume"] and SaveData.has_mark(save, area_id, b["grade"]):
			draw_circle(r.position + Vector2(r.size.x - 14, 14), 10.0, Color(1.0, 0.8, 0.2))
	draw_string(font, Vector2(330, 520), "stickers: %d" % save["stickers"].size(), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 16, Color(0.6, 0.55, 0.5))


## The Shop button: a gem-purple box, "Shop", and the gems to spend.
func _draw_shop(font: Font, r: Rect2) -> void:
	RoundBox.fill(self, r, Color(0.46, 0.28, 0.6), 18.0)
	RoundBox.frame(self, r, Color(1.0, 0.82, 0.35), 3.0, 18.0)
	draw_string(font, r.position + Vector2(0, 50), "Shop", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 40, Color(0.96, 0.94, 0.9))
	var gem_at := r.position + Vector2(r.size.x / 2.0 - 58, 62)
	draw_texture_rect(GEM_TEX, Rect2(gem_at, Vector2(48, 48)), false)
	draw_string(font, gem_at + Vector2(54, 38), str(int(save.get("gems", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 36,
			Color(1.0, 0.86, 0.5))
