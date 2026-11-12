## Little moving details in each world (Terrence 2026-11-12: "add details to
## existing worlds like lava bubble animations"). All drawn in code, no new
## art: lava bubbles that swell and pop, embers, bright streaks drifting on the
## lava and the lavafall; crystal glints, drips off the stalactites, dust in
## the lantern light; mist, will-o'-wisps, fireflies and ripples in the Bog.
##
## Everything here is a pure function of the clock (no particles to keep), so
## it costs a few dozen small shapes a frame. It is always drawn straight
## after the backdrop, so the stones, numbers, characters, dice and buttons
## all draw over it and nothing is ever hidden. Squares sit on the backdrop's
## 3-unit pixel grid so the effects look like part of the pixel art.
##
## Where the glints, lanterns, lava and stalactite tips are on the art comes
## from content/ambient_spots.json (tools/ambient/find_spots.py).
extends RefCounted

const SPOTS_PATH := "res://content/ambient_spots.json"
const PX := 3.0  # one backdrop pixel (backdrops are drawn at 3x)

## Turn the details off (stills, tests). On by default.
static var enabled := true
## How much bigger the little shapes draw: 2 on the half-size crossing, so a
## spark or a glint is the same size on screen at every level.
static var _k := 1.0
static var _u := PX

static var _spots := {}
static var _soft_tex: Texture2D


# --- the crossing ----------------------------------------------------------

## Behind everything on the crossing, straight after the backdrop. World
## units; x0..x1 is the part of the crossing on screen. `bg` names the
## backdrop tile and where its copies start (for the glints).
static func crossing(ci: CanvasItem, world_id: String, t: float, x0: float, x1: float,
		bg := "", bg_x0 := 0.0, zoom := 1.0) -> void:
	if not enabled:
		return
	_scale(1.0 / zoom)
	var sp := sqrt(_k)  # a little further apart when everything is half size
	match world_id:
		"lava_caves":
			_lava_streaks(ci, t, x0, x1)
			_lava_bubbles(ci, t, x0, x1, 62.0 * sp, 404.0, 126.0)
			_embers(ci, t, x0, x1, 40.0 * sp, 396.0, 330.0)
		"crystal_mines":
			_backdrop_glints(ci, t, x0, x1, bg, bg_x0)
			_motes(ci, t, x0, x1, 110.0 * sp, 150.0, 300.0, Color(0.82, 0.76, 1.0))
		"bog":
			_mist(ci, t, x0, x1, 280.0 * sp, 300.0, 50.0, 0.14)
			_wisps(ci, t, x0, x1, 460.0 * sp, 220.0, 120.0)
			_fireflies(ci, t, x0, x1, 80.0 * sp, 250.0, 170.0)
			_ripples(ci, t, x0, x1, 120.0 * sp, 450.0, 75.0)
			_mist(ci, t, x0, x1, 240.0 * sp, 405.0, 80.0, 0.2)


## Drips forming on the stalactite tips and falling into the pit, drawn just
## after the ceiling. `pieces` is the ceiling sprites' paths, `first_x` where
## the first one hangs, `step` how far apart they are.
static func ceiling_drips(ci: CanvasItem, t: float, x0: float, x1: float, pieces: Array,
		first_x: float, step: float, zoom := 1.0) -> void:
	if not enabled or pieces.is_empty():
		return
	_scale(1.0 / zoom)
	var k := maxi(0, int(floorf((x0 - first_x) / step)) - 1)
	while first_x + k * step < x1:
		var px := first_x + k * step
		var tips: Array = _spot(str(pieces[k % pieces.size()]), "tips")
		for m in tips.size():
			var id := k * 7 + m
			var period := 2.4 + _h(id, 1) * 3.0
			var local := fposmod(t + _h(id, 2) * period, period)
			var tip := Vector2(px + float(tips[m][0]) + 0.5, float(tips[m][1]))
			_drop(ci, tip, local)
		k += 1


# --- rooms (fights, duels, the boss's treasure room) ------------------------

## Over a 320x180 room backdrop drawn at 3x over the 960x540 frame, before
## anything else is drawn on it.
## `hole` is left alone (the boss board, which the room shows faintly through).
static func room(ci: CanvasItem, bg_path: String, t: float, hole := Rect2()) -> void:
	if not enabled:
		return
	_scale(1.0)
	match bg_path:
		"res://art/lava/fight-bg.png":
			# the lava pool's light breathing, bubbles on the river, the lavafall
			_soft(ci, Vector2(495, 215), Vector2(420, 330), Color(1.0, 0.55, 0.3, 0.07 + 0.05 * sin(t * 1.7)))
			for i in _spot(bg_path, "lava").size():
				var p: Array = _spot(bg_path, "lava")[i]
				var period := 2.2 + _h(i, 3) * 2.6
				_bubble(ci, Vector2(p[0] * PX + 1.5, p[1] * PX + 3.0), fposmod(t + _h(i, 4) * period, period),
						4.0 + _h(i, 5) * 5.0)
			_lavafall(ci, t, _spot(bg_path, "fall"))
			_embers(ci, t, 120.0, 860.0, 64.0, 470.0, 380.0)
		"res://art/crystal/fight-bg.png", "res://art/crystal/treasure-room.png":
			_lamps(ci, t, _spot(bg_path, "lamps"))
			_glints(ci, t, _spot(bg_path, "glints"), Vector2.ZERO, 0, Color(0.92, 0.85, 1.0), INF, true, hole)
			_motes(ci, t, 0.0, 960.0, 90.0, 120.0, 330.0, Color(1.0, 0.86, 0.6))
		"res://art/bog/fight-bg.png":
			_mist(ci, t, -200.0, 1160.0, 300.0, 250.0, 60.0, 0.07)
			_wisps(ci, t, 0.0, 960.0, 380.0, 170.0, 90.0)
			_fireflies(ci, t, 0.0, 960.0, 70.0, 300.0, 170.0)
			_mist(ci, t, -200.0, 1160.0, 260.0, 420.0, 60.0, 0.09)
		"res://art/bog/treasure-room.png":
			_glints(ci, t, _spot(bg_path, "glints"), Vector2.ZERO, 0, Color(0.95, 1.0, 0.7), INF, false, hole)
			_fireflies(ci, t, 0.0, 960.0, 85.0, 200.0, 220.0)
			_mist(ci, t, -200.0, 1160.0, 260.0, 470.0, 50.0, 0.08)
		"res://art/boss/treasure-cave.png":
			_glints(ci, t, _spot(bg_path, "glints"), Vector2.ZERO, 0, Color(1.0, 0.97, 0.8), INF, false, hole)
			_motes(ci, t, 0.0, 960.0, 100.0, 140.0, 300.0, Color(1.0, 0.85, 0.5))


# --- Lava Caves ------------------------------------------------------------

## A bubble swells on the lava, then pops: a ring and three droplets.
## `local` is seconds into its cycle; nothing shows after 1.5 s.
static func _bubble(ci: CanvasItem, c: Vector2, local: float, r_max: float) -> void:
	const GROW := 1.2
	const POP := 0.45
	if local < GROW:
		var k := local / GROW
		var r := maxf(3.0, r_max * (1.0 - pow(1.0 - k, 2.0)))
		_dome(ci, c + Vector2(0, 1.5), r + _u, Color(0.5, 0.12, 0.1))       # dark crust rim
		_dome(ci, c, r, Color(1.0, 0.55, 0.15))
		_dome(ci, c + Vector2(-r * 0.15, 0), r * 0.62, Color(1.0, 0.82, 0.32))
		ci.draw_rect(Rect2(_snap(c + Vector2(-r * 0.45, -r * 0.7)), Vector2(_u, _u)), Color(1.0, 0.98, 0.8))
	elif local < GROW + POP:
		var k := (local - GROW) / POP
		_ellipse(ci, c, r_max * (1.0 + 1.5 * k), r_max * (0.35 + 0.45 * k), Color(0.5, 0.12, 0.1, 0.8 * (1.0 - k)), _u)
		_ellipse(ci, c, r_max * (0.8 + 1.5 * k), r_max * (0.25 + 0.45 * k), Color(1.0, 0.9, 0.5, 1.0 - k), 2.0 * _k)
		for d in 4:
			var dx := (d - 1.5) * r_max * 0.8 * (0.4 + k)
			var dy := -r_max * 3.4 * k + r_max * 3.0 * k * k
			var s := _u * (2.0 if d == 1 else 1.0)
			ci.draw_rect(Rect2(_snap(c + Vector2(dx, dy - r_max * 0.6)), Vector2(s, s)), Color(1.0, 0.85, 0.4, 1.0 - k * 0.5))


static func _lava_bubbles(ci: CanvasItem, t: float, x0: float, x1: float, spacing: float,
		top: float, depth: float) -> void:
	for j in range(int(floorf(x0 / spacing)) - 1, int(ceilf(x1 / spacing)) + 1):
		var period := 2.4 + _h(j, 11) * 3.2
		var local := fposmod(t + _h(j, 12) * period, period)
		if local > 1.5:
			continue
		var c := Vector2(j * spacing + _h(j, 13) * spacing * 0.8, top + _h(j, 14) * depth)
		_bubble(ci, _snap(c), local, (8.0 + _h(j, 15) * 9.0) * _k)


## Short bright streaks drifting slowly along the lava surface.
static func _lava_streaks(ci: CanvasItem, t: float, x0: float, x1: float) -> void:
	const SP := 70.0
	for j in range(int(floorf(x0 / SP)) - 1, int(ceilf(x1 / SP)) + 1):
		var speed := 6.0 + _h(j, 21) * 9.0
		var phase := fposmod(t * speed / SP + _h(j, 22), 1.0)
		var x := j * SP + phase * SP
		var y := 396.0 + _h(j, 23) * 138.0
		var len := (12.0 + floorf(_h(j, 24) * 7.0) * PX) * _k
		var a := sin(PI * phase)
		if _h(j, 25) > 0.45:
			# a bright vein of hotter lava
			ci.draw_rect(Rect2(_snap(Vector2(x, y)), Vector2(len, _u)), Color(1.0, 0.92, 0.55, 0.75 * a))
		else:
			# a dark skin of cooling crust
			ci.draw_rect(Rect2(_snap(Vector2(x, y)), Vector2(len, _u)), Color(0.62, 0.18, 0.08, 0.55 * a))
			ci.draw_rect(Rect2(_snap(Vector2(x + _u, y + _u)), Vector2(len - _u * 2.0, _u)), Color(0.62, 0.18, 0.08, 0.35 * a))


## Sparks floating up off the lava, swaying and cooling from yellow to red.
static func _embers(ci: CanvasItem, t: float, x0: float, x1: float, spacing: float,
		from_y: float, rise: float) -> void:
	for j in range(int(floorf(x0 / spacing)) - 1, int(ceilf(x1 / spacing)) + 1):
		var period := 4.5 + _h(j, 31) * 4.0
		var p := fposmod(t / period + _h(j, 32), 1.0)
		var x := j * spacing + _h(j, 33) * spacing + sin(p * 7.0 + _h(j, 34) * 6.0) * 14.0 + p * 24.0
		var y := from_y - p * rise * (0.7 + 0.3 * _h(j, 35))
		var col := Color(1.0, 0.95, 0.6).lerp(Color(1.0, 0.38, 0.12), p)
		col.a = minf(1.0, (1.0 - p) * 1.6) * minf(1.0, p * 10.0)
		var s := _u * (2.0 if _h(j, 36) > 0.65 else 1.0)
		ci.draw_rect(Rect2(_snap(Vector2(x, y)), Vector2(s, s)), col)


## Bright drops running down the lavafall, and a splash at its foot.
static func _lavafall(ci: CanvasItem, t: float, fall: Array) -> void:
	if fall.size() < 4:
		return
	var left := float(fall[0]) * PX
	var right := float(fall[1]) * PX
	var top := float(fall[2]) * PX
	var bottom := float(fall[3]) * PX
	for i in 7:
		var period := 0.9 + _h(i, 41) * 0.7
		var p := fposmod(t / period + _h(i, 42), 1.0)
		var x := left + _h(i, 43) * (right - left)
		var y := top + p * p * (bottom - top)
		ci.draw_rect(Rect2(_snap(Vector2(x, y)), Vector2(_u, _u * 3.0)), Color(1.0, 0.95, 0.65, 0.85))
	for i in 4:
		var period := 0.7 + _h(i, 44) * 0.4
		var p := fposmod(t / period + _h(i, 45), 1.0)
		var c := Vector2((left + right) / 2.0 + (i - 1.5) * 9.0 * (0.5 + p), bottom - 30.0 * p * (1.0 - p) * 4.0)
		ci.draw_rect(Rect2(_snap(c), Vector2(_u, _u)), Color(1.0, 0.85, 0.4, 1.0 - p))


# --- Crystal Mines -----------------------------------------------------------

## The crystals in the tiled crossing backdrop twinkle, each copy a little
## out of step with the others.
static func _backdrop_glints(ci: CanvasItem, t: float, x0: float, x1: float, bg: String, bg_x0: float) -> void:
	var spots: Array = _spot(bg, "glints")
	if spots.is_empty():
		return
	var w := 320.0 * PX
	for r in range(int(floorf((x0 - bg_x0) / w)), int(ceilf((x1 - bg_x0) / w)) + 1):
		# none down by the stones, where a twinkle could sit beside a number
		_glints(ci, t, spots, Vector2(bg_x0 + r * w, 0), r * 97, Color(0.92, 0.85, 1.0), 370.0, true)


## A four-point twinkle on each spot (backdrop pixels, drawn at 3x).
static func _glints(ci: CanvasItem, t: float, spots: Array, at: Vector2, salt: int,
		col := Color(0.92, 0.85, 1.0), max_y := INF, breathe := false, hole := Rect2()) -> void:
	for i in spots.size():
		if float(spots[i][1]) * PX > max_y:
			continue
		if hole.has_point(at + Vector2(float(spots[i][0]), float(spots[i][1])) * PX):
			continue
		var id := i + salt
		if breathe:
			# the crystal itself glows softly, in and out
			var g := 0.5 + 0.5 * sin(t * (0.8 + _h(id, 53) * 0.6) + _h(id, 54) * 6.0)
			_soft(ci, at + Vector2(float(spots[i][0]) * PX + 1.5, float(spots[i][1]) * PX + 1.5),
					Vector2(30, 30) * _k, Color(0.75, 0.5, 1.0, 0.1 + 0.18 * g))
		var period := 2.4 + _h(id, 51) * 3.8
		var local := fposmod(t + _h(id, 52) * period, period)
		if local > 0.7:
			continue
		var s := sin(PI * local / 0.7)
		var c := at + Vector2(float(spots[i][0]) * PX + 1.5, float(spots[i][1]) * PX + 1.5)
		_star(ci, c, (4.0 + 10.0 * s) * _k, s, col)


## A drop swells on a stalactite tip, then falls into the dark.
static func _drop(ci: CanvasItem, tip: Vector2, local: float) -> void:
	const FORM := 0.9
	var col := Color(0.72, 0.86, 1.0, 0.9)
	if local < FORM:
		var k := local / FORM
		ci.draw_rect(Rect2(tip + Vector2(-1.5, 0), Vector2(_u, (1.0 + 3.0 * k) * _k)), col)
		return
	var f := local - FORM
	var y := tip.y + 0.5 * 1500.0 * f * f
	if y > 560.0:
		return
	ci.draw_rect(Rect2(Vector2(tip.x - 1.5, y), Vector2(_u, 7.0 * _k)), col)
	ci.draw_rect(Rect2(Vector2(tip.x - 1.5, y + 4.0 * _k), Vector2(_u, _u)), Color(0.95, 1.0, 1.0, 0.9))


## Dust drifting slowly in the light, now and then catching it.
static func _motes(ci: CanvasItem, t: float, x0: float, x1: float, spacing: float,
		top: float, depth: float, col: Color) -> void:
	for j in range(int(floorf(x0 / spacing)) - 1, int(ceilf(x1 / spacing)) + 1):
		var x := j * spacing + _h(j, 61) * spacing + sin(t * 0.25 + _h(j, 62) * 6.0) * 28.0
		var y := top + _h(j, 63) * depth + sin(t * 0.4 + _h(j, 64) * 6.0) * 18.0
		var a := 0.18 + 0.22 * maxf(0.0, sin(t * (0.6 + _h(j, 65)) + _h(j, 66) * 6.0))
		ci.draw_rect(Rect2(_snap(Vector2(x, y)), Vector2(_u, _u)), Color(col, a))


## Lantern flames flicker: a warm glow that never quite holds still.
static func _lamps(ci: CanvasItem, t: float, lamps: Array) -> void:
	for i in lamps.size():
		var c := Vector2(float(lamps[i][0]) * PX + 1.5, float(lamps[i][1]) * PX + 1.5)
		var f := 0.5 + 0.25 * sin(t * 9.0 + i * 2.0) + 0.25 * sin(t * 23.0 + i * 5.0)
		_soft(ci, c, Vector2(150, 150) * _k * (0.95 + 0.1 * f), Color(1.0, 0.75, 0.35, 0.16 + 0.1 * f))
		_soft(ci, c, Vector2(40, 46) * _k, Color(1.0, 0.95, 0.7, 0.35 + 0.25 * f))


# --- the Bog -----------------------------------------------------------------

## Soft banks of mist drifting along at one height.
static func _mist(ci: CanvasItem, t: float, x0: float, x1: float, spacing: float,
		y: float, spread: float, alpha: float) -> void:
	var span := spacing * 4.0
	for j in range(int(floorf(x0 / spacing)) - 4, int(ceilf(x1 / spacing)) + 1):
		var speed := 6.0 + _h(j, 71) * 8.0
		var x := j * spacing + fposmod(_h(j, 72) * span + t * speed, span)
		var size := Vector2(300.0 + _h(j, 73) * 220.0, 60.0 + _h(j, 74) * 40.0) * _k
		var a := alpha * (0.7 + 0.3 * sin(t * 0.35 + _h(j, 75) * 6.0))
		_soft(ci, Vector2(x, y + (_h(j, 76) - 0.5) * spread), size, Color(0.86, 0.93, 0.9, a))


## Will-o'-wisps far off between the trees: a pale glow that bobs, drifts
## and fades in and out.
static func _wisps(ci: CanvasItem, t: float, x0: float, x1: float, spacing: float,
		top: float, depth: float) -> void:
	for j in range(int(floorf(x0 / spacing)) - 1, int(ceilf(x1 / spacing)) + 1):
		var period := 9.0 + _h(j, 81) * 6.0
		var local := fposmod(t + _h(j, 82) * period, period)
		var a := clampf(minf(local / 1.5, (6.5 - local) / 1.5), 0.0, 1.0)
		if a <= 0.0:
			continue
		var c := Vector2(j * spacing + _h(j, 83) * spacing + sin(t * 0.5 + j) * 30.0,
				top + _h(j, 84) * depth + sin(t * 1.3 + j * 2.0) * 8.0)
		_soft(ci, c, Vector2(72, 72) * _k, Color(0.5, 1.0, 0.85, 0.4 * a))
		_soft(ci, c, Vector2(24, 24) * _k, Color(0.85, 1.0, 0.95, 0.9 * a))
		ci.draw_rect(Rect2(_snap(c) - Vector2(1.5, 1.5), Vector2(_u, _u)), Color(1, 1, 1, a))


## Fireflies wandering over the water, blinking on and off.
static func _fireflies(ci: CanvasItem, t: float, x0: float, x1: float, spacing: float,
		top: float, depth: float) -> void:
	for j in range(int(floorf(x0 / spacing)) - 1, int(ceilf(x1 / spacing)) + 1):
		var blink := 2.2 + _h(j, 91) * 1.6
		var local := fposmod(t + _h(j, 92) * blink, blink)
		if local > 1.0:
			continue
		var a := sin(PI * local)
		var c := Vector2(j * spacing + _h(j, 93) * spacing + sin(t * (0.4 + _h(j, 94) * 0.5) + j) * 26.0,
				top + _h(j, 95) * depth + cos(t * (0.5 + _h(j, 96) * 0.5) + j * 1.7) * 14.0)
		_soft(ci, c, Vector2(28, 28) * _k, Color(0.85, 1.0, 0.4, 0.5 * a))
		ci.draw_rect(Rect2(_snap(c), Vector2(_u, _u)), Color(0.95, 1.0, 0.6, a))


## Rings spreading on the black water, now and then a bubble coming up first.
static func _ripples(ci: CanvasItem, t: float, x0: float, x1: float, spacing: float,
		top: float, depth: float) -> void:
	for j in range(int(floorf(x0 / spacing)) - 1, int(ceilf(x1 / spacing)) + 1):
		var period := 3.5 + _h(j, 101) * 4.0
		var local := fposmod(t + _h(j, 102) * period, period)
		if local > 1.8:
			continue
		var c := _snap(Vector2(j * spacing + _h(j, 103) * spacing, top + _h(j, 104) * depth))
		var p := local / 1.8
		var rx := (5.0 + 28.0 * p) * _k
		_ellipse(ci, c, rx, rx * 0.28, Color(0.82, 0.94, 0.9, 0.6 * (1.0 - p)), 2.0 * _k)
		if _h(j, 105) > 0.6 and p < 0.15:
			_dome(ci, c, (4.0 * (1.0 - p / 0.15) + 1.0) * _k, Color(0.65, 0.8, 0.5, 0.8))


# --- shapes ------------------------------------------------------------------

## A diamond-shaped twinkle (never a cross: next to a number a "+" or an
## "x" would read as a sign).
static func _star(ci: CanvasItem, c: Vector2, r: float, a: float, col: Color) -> void:
	_soft(ci, c, Vector2(r, r) * 3.0, Color(col, 0.3 * a))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.45, 0),
			c + Vector2(0, r), c + Vector2(-r * 0.45, 0)]), Color(col, a * 0.85))
	var q := r * 0.45
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -q), c + Vector2(q * 0.5, 0),
			c + Vector2(0, q), c + Vector2(-q * 0.5, 0)]), Color(1, 1, 1, a))


## The top half of a circle sitting on `c`.
static func _dome(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var ang := PI + PI * i / 8.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	ci.draw_colored_polygon(pts, col)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var ang := TAU * i / 16.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	ci.draw_polyline(pts, col, width)


## A soft round glow (or a wide bank of mist) centred on `c`.
static func _soft(ci: CanvasItem, c: Vector2, size: Vector2, col: Color) -> void:
	ci.draw_texture_rect(_soft_texture(), Rect2(c - size / 2.0, size), false, col)


static func _soft_texture() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_soft_tex = gt
	return _soft_tex


# --- helpers -------------------------------------------------------------------

static func _scale(k: float) -> void:
	_k = k
	_u = PX * k


static func _snap(p: Vector2) -> Vector2:
	return Vector2(floorf(p.x / PX) * PX, floorf(p.y / PX) * PX)


## A steady 0..1 number for slot `i` (the same every frame).
static func _h(i: int, salt: int) -> float:
	var v := sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return v - floorf(v)


static func _spot(path: String, kind: String) -> Array:
	if _spots.is_empty():
		var f := FileAccess.open(SPOTS_PATH, FileAccess.READ)
		if f != null:
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				_spots = data
		if _spots.is_empty():
			_spots = {"": {}}
	return _spots.get(path, {}).get(kind, [])
