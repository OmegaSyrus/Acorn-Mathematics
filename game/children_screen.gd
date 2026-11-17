## Children on this tablet (Grown-ups panel, behind the parent PIN): one row
## per child with their picture (tap for the next one), their name (tap to
## type a new one) and Remove (hold for 3 seconds; their save on this tablet
## goes too). Add makes a new child, up to six. The last child can't be
## removed. Only nicknames: no real names, birthdays or photos are asked for.
extends Node2D

signal back
## A child was removed (main.gd reloads the save if it was the player).
signal removed(profile_id: String)

const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const RoundBox := preload("res://game/ui/round_box.gd")
const Profiles := preload("res://logic/core/profiles.gd")
const ProfileStore := preload("res://game/profile_store.gd")
const WhoScreen := preload("res://game/who_screen.gd")
const Pointer := preload("res://game/ui/pointer.gd")

const INK := Color(0.96, 0.94, 0.9)
const DIM := Color(0.8, 0.76, 0.72)
const GOLD := Color(1.0, 0.82, 0.35)
const GREY := Color(0.3, 0.27, 0.26)
const BACK_RECT := Rect2(120, 20, 140, 60)
const ADD_RECT := Rect2(640, 20, 200, 60)
const ROW_Y0 := 100.0
const ROW_H := 68.0
const PIC_X := 140.0
const NAME_RECT_X := 240.0
const NAME_SIZE := Vector2(360, 56)
const REMOVE_X := 640.0
const REMOVE_SIZE := Vector2(180, 56)
const HOLD_S := 3.0

var roster: Dictionary
var choice: ChoiceWidget
var editing: LineEdit
var hold_row := -1
var hold_t := 0.0


func setup(r: Dictionary) -> void:
	roster = r


func _rows() -> Array:
	return Profiles.children(roster)


static func pic_rect(i: int) -> Rect2:
	return Rect2(Vector2(PIC_X, ROW_Y0 + i * ROW_H), Vector2(80, 56))


static func name_rect(i: int) -> Rect2:
	return Rect2(Vector2(NAME_RECT_X, ROW_Y0 + i * ROW_H), NAME_SIZE)


static func remove_rect(i: int) -> Rect2:
	return Rect2(Vector2(REMOVE_X, ROW_Y0 + i * ROW_H), REMOVE_SIZE)


func _ready() -> void:
	for pic in Profiles.PICTURES:
		WhoScreen.picture(pic)  # loaded before _draw
	choice = ChoiceWidget.new()
	choice.show_highlight = false
	add_child(choice)
	while true:
		var rows := _rows()
		var rects := [BACK_RECT, ADD_RECT]
		for i in rows.size():
			rects.append(pic_rect(i))
			rects.append(name_rect(i))
		queue_redraw()
		choice.present(rects, 0)
		var k: int = await choice.picked
		_finish_edit()
		if k < 0:
			continue  # a child was removed: lay the rows out again
		if k == 0:
			back.emit()
			return
		if k == 1:
			if Profiles.add_child(roster, int(Time.get_unix_time_from_system())).is_empty():
				Beeper.bad()
			else:
				Beeper.good()
				ProfileStore.write()
			continue
		var row := (k - 2) / 2
		var id := str(rows[row]["id"])
		if (k - 2) % 2 == 0:
			Profiles.next_picture(roster, id)
			ProfileStore.write()
			Beeper.tone(660.0, 0.06)
		else:
			_start_edit(row, id)


## A text box over the name; the tablet's keyboard comes up with it.
func _start_edit(row: int, id: String) -> void:
	editing = LineEdit.new()
	editing.max_length = Profiles.NAME_MAX
	editing.text = str(Profiles.find(roster, id)["nickname"])
	editing.position = name_rect(row).position
	editing.size = NAME_SIZE
	editing.add_theme_font_size_override("font_size", 28)
	editing.set_meta("profile", id)
	editing.text_submitted.connect(func(_t): _finish_edit())
	editing.focus_exited.connect(_finish_edit)
	add_child(editing)
	editing.grab_focus()
	editing.select_all()


func _finish_edit() -> void:
	if editing == null:
		return
	var e := editing
	editing = null
	Profiles.rename(roster, str(e.get_meta("profile")), e.text)
	ProfileStore.write()
	e.queue_free()
	queue_redraw()


## Remove is held, not tapped (like Reset).
func _unhandled_input(event: InputEvent) -> void:
	if not (Pointer.is_press(event) or Pointer.is_release(event) or Pointer.is_drag(event)):
		return
	var p := Pointer.local_pos(self, event)
	if Pointer.is_press(event):
		for i in _rows().size():
			if remove_rect(i).has_point(p):
				get_viewport().set_input_as_handled()
				hold_row = i
				hold_t = 0.0
				return
	elif hold_row >= 0 and (Pointer.is_release(event) or not remove_rect(hold_row).grow(30).has_point(p)):
		hold_row = -1
		hold_t = 0.0
		queue_redraw()


func _process(delta: float) -> void:
	if hold_row < 0:
		return
	hold_t += delta
	if hold_t >= HOLD_S:
		var rows := _rows()
		var id := str(rows[hold_row]["id"]) if hold_row < rows.size() else ""
		hold_row = -1
		hold_t = 0.0
		if id != "" and ProfileStore.remove(id):
			Beeper.good()
			removed.emit(id)
			choice.close()
			choice.picked.emit(-1)
		else:
			Beeper.bad()
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.1, 0.1, 0.13))
	RoundBox.fill(self, BACK_RECT, GREY, 14.0)
	draw_string(font, BACK_RECT.position + Vector2(0, 41), "Back", HORIZONTAL_ALIGNMENT_CENTER, BACK_RECT.size.x, 30, INK)
	draw_string(font, Vector2(270, 62), "Children", HORIZONTAL_ALIGNMENT_CENTER, 360, 38, GOLD)
	var rows := _rows()
	var full := rows.size() >= Profiles.MAX_PROFILES
	RoundBox.fill(self, ADD_RECT, GREY if full else Color(0.2, 0.55, 0.3), 14.0)
	draw_string(font, ADD_RECT.position + Vector2(0, 41), "Add child", HORIZONTAL_ALIGNMENT_CENTER, ADD_RECT.size.x, 28, INK)
	for i in rows.size():
		var p: Dictionary = rows[i]
		var pr := pic_rect(i)
		RoundBox.fill(self, pr, Color(0.22, 0.36, 0.26), 12.0)
		var tex := WhoScreen.picture(str(p["picture"]))
		if tex != null:
			# the head only, at 1:1 (never scaled)
			var src := Rect2(roundf(tex.get_width() / 2.0 - 36), 2, 72, 52)
			draw_texture_rect_region(tex, Rect2(pr.position + Vector2(4, 2), src.size), src)
		var nr := name_rect(i)
		if editing == null or str(editing.get_meta("profile")) != str(p["id"]):
			RoundBox.fill(self, nr, Color(0.2, 0.2, 0.26), 12.0)
			draw_string(font, nr.position + Vector2(16, 38), str(p["nickname"]), HORIZONTAL_ALIGNMENT_LEFT, nr.size.x - 32, 28, INK)
		var rr := remove_rect(i)
		var last := rows.size() <= 1
		RoundBox.fill(self, rr, GREY if last else Color(0.5, 0.2, 0.18), 12.0)
		draw_string(font, rr.position + Vector2(0, 37), "Remove", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 24, DIM if last else INK)
		if hold_row == i:
			draw_rect(Rect2(rr.position + Vector2(10, rr.size.y - 9), Vector2(roundf((rr.size.x - 20) * clampf(hold_t / HOLD_S, 0, 1)), 4)), GOLD)
	draw_string(font, Vector2(120, 528), "Tap a picture to change it, a name to type a new one. Hold Remove for 3 seconds.",
			HORIZONTAL_ALIGNMENT_LEFT, 720, 16, DIM)
