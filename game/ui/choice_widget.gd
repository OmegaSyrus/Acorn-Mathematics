## The shared choice widget (plan section 12): big targets, one highlighted.
## Touch or mouse picks on a fresh press inside a target; the d-pad or stick
## moves the highlight and A picks. Nothing picks for 300 ms after present().
## The owner draws the targets; this draws only the highlight.
## With confirm on, picking takes two taps: a tap selects a target (the
## highlight shows on it) and a Go button appears above it; tapping Go picks.
## Tapping another target moves the selection.
extends Node2D

signal picked(index: int)
signal selected(index: int)

const InputGate := preload("res://logic/core/input_gate.gd")
const Pointer := preload("res://game/ui/pointer.gd")
const RoundBox := preload("res://game/ui/round_box.gd")

const PAD := 6.0
const GO_SIZE := Vector2(150, 84)
const GO_FONT := 48
const GO_GREEN := Color(0.2, 0.62, 0.3)
const INK := Color(0.96, 0.94, 0.9)
const DARK := Color(0.07, 0.04, 0.08)

## false hides the yellow highlight frame (touch screens where the targets
## carry their own numbers; Terrence 2026-11-04). The d-pad still moves it.
var show_highlight := true
## true: select first, then tap Go (stones on the crossing; Terrence
## 2026-11-05). The highlight shows only on the selected target.
var confirm := false
## Where the Go button's middle sits, from the selected target's middle.
var go_offset := Vector2(0, -175)
## The Go button is kept inside this (local coordinates); empty for no limit.
var go_area := Rect2()
var rects: Array = []
var highlight := 0
var chosen := -1  # the selected target in confirm mode, -1 before a tap
var active := false
var gate := InputGate.new()
var _pulse := 0.0


func present(target_rects: Array, start := 0) -> void:
	rects = target_rects
	highlight = clampi(start, 0, rects.size() - 1)
	chosen = -1
	active = true
	gate.present(Time.get_ticks_msec())
	queue_redraw()


func close() -> void:
	active = false
	rects = []
	chosen = -1
	gate.close()
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	_pulse += delta
	for dir in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_just_pressed(dir):
			_move(_dir_vec(dir))
			if confirm:
				_select(highlight)
	if Input.is_action_just_pressed("pick") and gate.accepts(Time.get_ticks_msec()):
		if confirm and chosen != highlight:
			_select(highlight)
		else:
			_pick(highlight)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if not Pointer.is_press(event):
		return
	var pos := Pointer.local_pos(self, event)
	if confirm and chosen >= 0 and go_rect().grow(PAD).has_point(pos):
		get_viewport().set_input_as_handled()
		if gate.accepts(Time.get_ticks_msec()):
			_pick(chosen)
		return
	for i in rects.size():
		if _rect(i).grow(PAD).has_point(pos):
			get_viewport().set_input_as_handled()
			if gate.accepts(Time.get_ticks_msec()):
				highlight = i
				if confirm:
					_select(i)
				else:
					_pick(i)
			return


## The Go button, above the selected target (confirm mode only).
func go_rect() -> Rect2:
	if chosen < 0:
		return Rect2()
	var r := Rect2(_rect(chosen).get_center() + go_offset - GO_SIZE / 2.0, GO_SIZE)
	if go_area.has_area():
		r.position.x = clampf(r.position.x, go_area.position.x, go_area.end.x - r.size.x)
	return r


func _select(i: int) -> void:
	var changed := i != chosen
	chosen = i
	highlight = i
	queue_redraw()
	if changed:
		selected.emit(i)


func _pick(i: int) -> void:
	active = false
	gate.close()
	queue_redraw()
	picked.emit(i)


## Spatial navigation: the nearest target roughly in the pressed direction.
func _move(d: Vector2) -> void:
	if rects.is_empty():
		return
	var here: Vector2 = _rect(highlight).get_center()
	var best := -1
	var best_score := INF
	for i in rects.size():
		if i == highlight:
			continue
		var delta: Vector2 = _rect(i).get_center() - here
		var along := delta.normalized().dot(d)
		if along < 0.3:
			continue
		var score := delta.length() / along
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		highlight = best


func _dir_vec(action: String) -> Vector2:
	match action:
		"move_left":
			return Vector2.LEFT
		"move_right":
			return Vector2.RIGHT
		"move_up":
			return Vector2.UP
	return Vector2.DOWN


func _draw() -> void:
	if not active or rects.is_empty():
		return
	if confirm:
		if chosen >= 0:
			_draw_frame(chosen)
			_draw_go()
		return
	if show_highlight:
		_draw_frame(highlight)


func _draw_frame(i: int) -> void:
	var r: Rect2 = _rect(i).grow(8.0 + 2.0 * sin(_pulse * 5.0))
	var open := gate.is_open(Time.get_ticks_msec())
	RoundBox.frame(self, r, Color(1.0, 0.92, 0.3, 1.0 if open else 0.35), 5.0, 16.0)


## A big green Go button with a little point down toward the selection,
## breathing gently so it gets noticed.
func _draw_go() -> void:
	var r := go_rect()
	var s := 1.0 + 0.04 * sin(_pulse * 4.0)
	r = Rect2(r.get_center() - r.size * s / 2.0, r.size * s)
	var tip := _rect(chosen).get_center() + Vector2(0, -_rect(chosen).size.y / 2.0 - 10.0)
	var b := clampf(tip.x, r.position.x + 30.0, r.end.x - 30.0)
	var tail := PackedVector2Array([Vector2(b - 22, r.end.y - 2), Vector2(b + 22, r.end.y - 2), Vector2(b, minf(tip.y, r.end.y + 26))])
	draw_colored_polygon(tail, Color(1.0, 0.92, 0.3))
	RoundBox.fill(self, r.grow(5), Color(1.0, 0.92, 0.3), 22.0)
	RoundBox.fill(self, r, GO_GREEN, 18.0)
	var font := ThemeDB.fallback_font
	var at := Vector2(r.position.x, r.get_center().y + GO_FONT * 0.36)
	draw_string_outline(font, at, "Go", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, GO_FONT, 8, DARK)
	draw_string(font, at, "Go", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, GO_FONT, INK)


func _rect(i: int) -> Rect2:
	return rects[i]
