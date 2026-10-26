## The shared choice widget (plan section 12): big targets, one highlighted.
## Touch or mouse picks on a fresh press inside a target; the d-pad or stick
## moves the highlight and A picks. Nothing picks for 300 ms after present().
## The owner draws the targets; this draws only the highlight.
extends Node2D

signal picked(index: int)

const InputGate := preload("res://logic/core/input_gate.gd")
const Pointer := preload("res://game/ui/pointer.gd")

const PAD := 6.0

var rects: Array = []
var highlight := 0
var active := false
var gate := InputGate.new()
var _pulse := 0.0


func present(target_rects: Array, start := 0) -> void:
	rects = target_rects
	highlight = clampi(start, 0, rects.size() - 1)
	active = true
	gate.present(Time.get_ticks_msec())
	queue_redraw()


func close() -> void:
	active = false
	rects = []
	gate.close()
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	_pulse += delta
	for dir in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_just_pressed(dir):
			_move(_dir_vec(dir))
	if Input.is_action_just_pressed("pick") and gate.accepts(Time.get_ticks_msec()):
		_pick(highlight)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if not Pointer.is_press(event):
		return
	var pos := Pointer.local_pos(self, event)
	for i in rects.size():
		if _rect(i).grow(PAD).has_point(pos):
			get_viewport().set_input_as_handled()
			if gate.accepts(Time.get_ticks_msec()):
				highlight = i
				_pick(i)
			return


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
	var r: Rect2 = _rect(highlight).grow(8.0 + 2.0 * sin(_pulse * 5.0))
	var open := gate.is_open(Time.get_ticks_msec())
	draw_rect(r, Color(1.0, 0.92, 0.3, 1.0 if open else 0.35), false, 5.0)


func _rect(i: int) -> Rect2:
	return rects[i]
