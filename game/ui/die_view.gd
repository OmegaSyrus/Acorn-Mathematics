## A die that tumbles, lands, turns its top face to the camera and holds it
## face on (plan section 04). Drawn as a real 3D cube projected to 2D, so the
## tumble looks like a die; pre-rendered frames can replace _draw later.
## While face on, the child can tap each dot to count it.
extends Node2D

signal landed
signal pip_tapped(count: int)

const DiceDraw := preload("res://game/ui/dice_draw.gd")
const Pointer := preload("res://game/ui/pointer.gd")

const HALF := 36.0  # a face on die is about 96 px at this size
const FOCAL := 4.0
const TUMBLE_S := 0.95
const SETTLE_S := 0.15
const TURN_S := 0.35
const TILT := -0.9  # radians the landed die leans back before turning to camera
const NORMALS := {
	1: Vector3(0, 0, 1), 6: Vector3(0, 0, -1),
	2: Vector3(1, 0, 0), 5: Vector3(-1, 0, 0),
	3: Vector3(0, 1, 0), 4: Vector3(0, -1, 0),
}

var value := 1
var slip := false
var face_on := false
var countable := false
var numeral_alpha := 0.0:
	set(v):
		numeral_alpha = v
		queue_redraw()
var q := Quaternion.IDENTITY
var offset := Vector2.ZERO
var lit := []
## Optional art: face value -> Texture2D (96 x 96, pips at 27/48/69 px). When
## set, the die shows the art once it is face on; the tumble stays 3D.
var face_art := {}
var _frames := {}  # face value -> [normal, tangent, bitangent] in die space
var _cosmetic := RandomNumberGenerator.new()  # look only, never game logic


func _ready() -> void:
	for v in NORMALS:
		var fq := face_quat(v)
		var inv := fq.inverse()
		_frames[v] = [NORMALS[v], inv * Vector3.RIGHT, inv * Vector3.UP]
	show_still(1)


## The rotation that shows face v to the camera, upright.
static func face_quat(v: int) -> Quaternion:
	var n: Vector3 = NORMALS[v]
	if n.z < -0.5:
		return Quaternion(Vector3.UP, PI)
	if n.z > 0.5:
		return Quaternion.IDENTITY
	return Quaternion(n, Vector3(0, 0, 1))


func show_still(v: int) -> void:
	value = v
	q = face_quat(v)
	face_on = true
	offset = Vector2.ZERO
	_reset_lit()
	queue_redraw()


func roll_to(v: int, delay := 0.0) -> void:
	value = v
	face_on = false
	countable = false
	numeral_alpha = 0.0
	_reset_lit()
	var q_final := face_quat(v)
	var q_land := Quaternion(Vector3.RIGHT, TILT) * q_final
	var axis := Vector3(_cosmetic.randf_range(-1, 1), _cosmetic.randf_range(-1, 1), _cosmetic.randf_range(-1, 1))
	if axis.length() < 0.1:
		axis = Vector3(1, 1, 0)
	axis = axis.normalized()
	var spin := TAU * _cosmetic.randi_range(2, 3) + _cosmetic.randf_range(0, PI)
	var from := Vector2(-170, -60)
	q = q_land * Quaternion(axis, spin)
	offset = from
	visible = true
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	var tumble := func(t: float) -> void:
		var e := 1.0 - pow(1.0 - t, 3.0)
		q = q_land * Quaternion(axis, spin * (1.0 - e))
		offset = from.lerp(Vector2.ZERO, e) + Vector2(0, -absf(sin(t * PI * 3.0)) * 46.0 * (1.0 - t))
		queue_redraw()
	var turn := func(t: float) -> void:
		q = q_land.slerp(q_final, t * t * (3.0 - 2.0 * t))
		queue_redraw()
	var tw := create_tween()
	tw.tween_method(tumble, 0.0, 1.0, TUMBLE_S)
	tw.tween_interval(SETTLE_S)
	tw.tween_method(turn, 0.0, 1.0, TURN_S)
	await tw.finished
	q = q_final
	offset = Vector2.ZERO
	face_on = true
	queue_redraw()
	landed.emit()


func show_numeral() -> void:
	countable = false
	create_tween().tween_property(self, "numeral_alpha", 1.0, 0.4)


func _reset_lit() -> void:
	lit = []
	for i in DiceDraw.PIPS[value].size():
		lit.append(false)


func _project(p: Vector3) -> Vector2:
	var w := q * p
	var k := FOCAL / (FOCAL - w.z)
	return offset + Vector2(w.x, -w.y) * k * HALF


## Pip centers of the face art, in its 96 px frame, centered on 0.
const ART_PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(21, -21), Vector2(-21, 21)],
	3: [Vector2(21, -21), Vector2(0, 0), Vector2(-21, 21)],
	4: [Vector2(-21, -21), Vector2(21, -21), Vector2(-21, 21), Vector2(21, 21)],
	5: [Vector2(-21, -21), Vector2(21, -21), Vector2(0, 0), Vector2(-21, 21), Vector2(21, 21)],
	6: [Vector2(-21, -21), Vector2(-21, 0), Vector2(-21, 21), Vector2(21, -21), Vector2(21, 0), Vector2(21, 21)],
}


func _art_on() -> bool:
	return face_on and offset == Vector2.ZERO and face_art.has(value)


func _draw() -> void:
	if _art_on():
		draw_circle(Vector2(0, HALF * 1.45), HALF * 0.9, Color(0, 0, 0, 0.25))
		var tex: Texture2D = face_art[value]
		draw_texture(tex, -tex.get_size() / 2.0)
		var pts: Array = ART_PIPS[value]
		for i in pts.size():
			if lit[i]:
				draw_circle(pts[i], 9.0, Color(1.0, 0.8, 0.1))
		if numeral_alpha > 0.0:
			draw_string(ThemeDB.fallback_font, Vector2(HALF * 1.5, HALF * 0.45), str(value),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1, 1, 1, numeral_alpha))
		return
	var dot_col: Color = DiceDraw.SLIP_DOT if slip else DiceDraw.DOT
	var face_col: Color = DiceDraw.SLIP_FACE if slip else DiceDraw.FACE
	draw_circle(Vector2(0, HALF * 1.45), HALF * 0.9, Color(0, 0, 0, 0.25))
	for v in _frames:
		var fr: Array = _frames[v]
		var n: Vector3 = fr[0]
		var shade := (q * n).z
		if shade <= 0.02:
			continue
		var t: Vector3 = fr[1]
		var b: Vector3 = fr[2]
		var poly := PackedVector2Array([
			_project(n - t + b), _project(n + t + b), _project(n + t - b), _project(n - t - b)])
		draw_colored_polygon(poly, face_col * Color(0.55 + 0.45 * shade, 0.55 + 0.45 * shade, 0.55 + 0.45 * shade))
		poly.append(poly[0])
		draw_polyline(poly, DiceDraw.EDGE, 2.0)
		var pips: Array = DiceDraw.PIPS[v]
		for i in pips.size():
			var pc: Vector2 = pips[i]
			var ring := PackedVector2Array()
			for s in 12:
				var a := TAU * s / 12.0
				var u := pc + Vector2(cos(a), sin(a)) * DiceDraw.PIP_R
				ring.append(_project(n * 1.001 + t * u.x + b * u.y))
			var col := dot_col
			if face_on and v == value and lit[i]:
				col = Color(1.0, 0.8, 0.1)
			draw_colored_polygon(ring, col)
	if numeral_alpha > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(HALF * 1.5, HALF * 0.45), str(value),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1, 1, 1, numeral_alpha))


## Face-on pip centers in local coordinates, for tap-to-count.
func pip_points() -> Array:
	if _art_on():
		return ART_PIPS[value]
	var out := []
	var fr: Array = _frames[value]
	for pc in DiceDraw.PIPS[value]:
		out.append(_project(fr[0] + fr[1] * pc.x + fr[2] * pc.y))
	return out


func _unhandled_input(event: InputEvent) -> void:
	if not (countable and face_on and visible):
		return
	if not Pointer.is_press(event):
		return
	var local := Pointer.local_pos(self, event)
	var pts := pip_points()
	for i in pts.size():
		if local.distance_to(pts[i]) <= 20.0:
			get_viewport().set_input_as_handled()
			if not lit[i]:
				lit[i] = true
			var count := 0
			for l in lit:
				if l:
					count += 1
			queue_redraw()
			pip_tapped.emit(count)
			return
