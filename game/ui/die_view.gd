## A die that tumbles, lands, turns its top face to the camera and holds it
## face on (plan section 04). A real 3D cube projected to 2D, with the pixel
## art faces mapped onto every side, so the art is on the cube the whole way
## through the roll and the face that lands is the same 96 px art.
## While face on, the child can tap each dot to count it.
##
## The cube is solid: a face is drawn only when it really faces the camera
## (under perspective that is normal.z > 1 / FOCAL, not > 0), and the faces
## that are drawn go back to front, so none shows through another or pops.
extends Node2D

signal landed
signal pip_tapped(count: int)

const DiceDraw := preload("res://game/ui/dice_draw.gd")
const Pointer := preload("res://game/ui/pointer.gd")

const ART := "res://art/lava/"
const HALF := 36.0  # a face on die is 96 px at this size (HALF * FOCAL / (FOCAL - 1) = 48)
const FOCAL := 4.0
const GRID := 4  # each face is cut into GRID x GRID quads so the art follows the perspective
const TUMBLE_S := 0.95
const SETTLE_S := 0.15
const TURN_S := 0.35
const TILT := -0.9  # radians the landed die leans back before turning to camera
const FROM := Vector2(-170, -60)
const NORMALS := {
	1: Vector3(0, 0, 1), 6: Vector3(0, 0, -1),
	2: Vector3(1, 0, 0), 5: Vector3(-1, 0, 0),
	3: Vector3(0, 1, 0), 4: Vector3(0, -1, 0),
}
## Pip centers of the face art, in its 96 px frame, centered on 0, y down.
const ART_PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(21, -21), Vector2(-21, 21)],
	3: [Vector2(21, -21), Vector2(0, 0), Vector2(-21, 21)],
	4: [Vector2(-21, -21), Vector2(21, -21), Vector2(-21, 21), Vector2(21, 21)],
	5: [Vector2(-21, -21), Vector2(21, -21), Vector2(0, 0), Vector2(-21, 21), Vector2(21, 21)],
	6: [Vector2(-21, -21), Vector2(-21, 0), Vector2(-21, 21), Vector2(21, -21), Vector2(21, 0), Vector2(21, 21)],
}
const ART_EDGE := Color(0.1, 0.06, 0.12)  # the art's outline, filled under its rounded corners
const LIT := Color(1.0, 0.8, 0.1)

## The red die (the one taken away). Setting it swaps the face art.
var slip := false:
	set(v):
		slip = v
		_load_art()
var value := 1
var face_on := false
var countable := false
var numeral_alpha := 0.0:
	set(v):
		numeral_alpha = v
		queue_redraw()
var q := Quaternion.IDENTITY
var offset := Vector2.ZERO
var lit := []
## face value -> Texture2D (96 x 96, pips at 27/48/69 px).
var face_art := {}
var _frames := {}  # face value -> [normal, tangent, bitangent] in die space
var _cosmetic := RandomNumberGenerator.new()  # look only, never game logic


func _ready() -> void:
	for v in NORMALS:
		var fq := face_quat(v)
		var inv := fq.inverse()
		_frames[v] = [NORMALS[v], inv * Vector3.RIGHT, inv * Vector3.UP]
	if face_art.is_empty():
		_load_art()
	show_still(1)


func _load_art() -> void:
	var kind := "red" if slip else "wood"
	face_art = {}
	for v in range(1, 7):
		face_art[v] = load(ART + "die-%s-%d.png" % [kind, v])
	queue_redraw()


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


## Tumbles in from `from` (local to where the die sits) and lands on v.
func roll_to(v: int, delay := 0.0, from := FROM) -> void:
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
	q = q_land * Quaternion(axis, spin)
	offset = from
	visible = true
	queue_redraw()
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


## A point on face v, from art pixels (96 px frame centered on 0, y down).
func _on_face(v: int, px: Vector2, lift := 1.001) -> Vector2:
	var fr: Array = _frames[v]
	return _project(fr[0] * lift + fr[1] * (px.x / 48.0) - fr[2] * (px.y / 48.0))


func _draw() -> void:
	draw_circle(Vector2(0, HALF * 1.45), HALF * 0.9, Color(0, 0, 0, 0.25))
	var front := []
	for v in _frames:
		var nz := (q * (_frames[v][0] as Vector3)).z
		if nz > 1.0 / FOCAL + 0.001:
			front.append([nz, v])
	front.sort_custom(func(a, b): return a[0] < b[0])
	for f in front:
		var light: float = 0.55 + 0.45 * f[0]
		_draw_art_face(f[1], Color(light, light, light))
	if face_on:
		var pts: Array = ART_PIPS[value]
		for i in pts.size():
			if lit[i]:
				var ring := PackedVector2Array()
				for s in 12:
					var a := TAU * s / 12.0
					ring.append(_on_face(value, pts[i] + Vector2(cos(a), sin(a)) * 9.0, 1.002))
				draw_colored_polygon(ring, LIT)
	if numeral_alpha > 0.0 and face_on:
		# under the die, so it never runs into a sign between two dice
		draw_string(ThemeDB.fallback_font, Vector2(-40, 78), str(value), HORIZONTAL_ALIGNMENT_CENTER, 80, 36,
				Color(1, 1, 1, numeral_alpha))


## The face art mapped onto one side of the cube, cut into a grid so it
## bends with the perspective instead of shearing.
func _draw_art_face(v: int, light: Color) -> void:
	var fr: Array = _frames[v]
	var n: Vector3 = fr[0]
	var t: Vector3 = fr[1]
	var b: Vector3 = fr[2]
	var corners := PackedVector2Array([
		_project(n - t + b), _project(n + t + b), _project(n + t - b), _project(n - t - b)])
	draw_colored_polygon(corners, ART_EDGE * light)
	var tex: Texture2D = face_art[v]
	var cols := PackedColorArray([light])
	for i in GRID:
		for j in GRID:
			var u0 := float(i) / GRID
			var u1 := float(i + 1) / GRID
			var v0 := float(j) / GRID
			var v1 := float(j + 1) / GRID
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for c in [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]:
				pts.append(_project(n + t * (c.x * 2.0 - 1.0) + b * (1.0 - c.y * 2.0)))
				uvs.append(c)
			draw_polygon(pts, cols, uvs, tex)


## Face-on pip centers in local coordinates, for tap-to-count.
func pip_points() -> Array:
	var out := []
	for p in ART_PIPS[value]:
		out.append(_on_face(value, p))
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
