## Pip layouts and flat dice faces, shared by the 3D die and the key faces.
## Dots always use this layout and stay black on white, whatever the style.
extends RefCounted

## Pip centers in face units (-1..1), y up. Same layout on every die.
const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-0.5, 0.5), Vector2(0.5, -0.5)],
	3: [Vector2(-0.5, 0.5), Vector2(0, 0), Vector2(0.5, -0.5)],
	4: [Vector2(-0.5, 0.5), Vector2(0.5, 0.5), Vector2(-0.5, -0.5), Vector2(0.5, -0.5)],
	5: [Vector2(-0.5, 0.5), Vector2(0.5, 0.5), Vector2(0, 0), Vector2(-0.5, -0.5), Vector2(0.5, -0.5)],
	6: [Vector2(-0.5, 0.55), Vector2(-0.5, 0), Vector2(-0.5, -0.55),
		Vector2(0.5, 0.55), Vector2(0.5, 0), Vector2(0.5, -0.55)],
}
const PIP_R := 0.17
const FACE := Color(0.97, 0.96, 0.92)
const SLIP_FACE := Color(0.8, 0.12, 0.1)
const DOT := Color(0.05, 0.05, 0.05)
const SLIP_DOT := Color(1, 1, 1)
const EDGE := Color(0.25, 0.22, 0.2)


## A flat die face of side `size` centered at `c`.
static func draw_face(ci: CanvasItem, c: Vector2, size: float, value: int, slip := false) -> void:
	var h := size / 2.0
	var r := Rect2(c - Vector2(h, h), Vector2(size, size))
	ci.draw_rect(r, SLIP_FACE if slip else FACE)
	ci.draw_rect(r, EDGE, false, 2.0)
	for p in PIPS.get(value, []):
		ci.draw_circle(c + Vector2(p.x, -p.y) * h, PIP_R * h * 1.15, SLIP_DOT if slip else DOT)


## A value as the child sees it: one die up to 6, two dice side by side up to
## 12 (7 = 4 and 3), a numeral above 12.
static func draw_value(ci: CanvasItem, c: Vector2, size: float, value: int) -> void:
	if value >= 1 and value <= 6:
		draw_face(ci, c, size, value)
	elif value >= 7 and value <= 12:
		var a := ceili(value / 2.0)
		var gap := size * 0.56
		draw_face(ci, c - Vector2(gap, 0), size, a)
		draw_face(ci, c + Vector2(gap, 0), size, value - a)
	else:
		var font := ThemeDB.fallback_font
		var fs := int(size)
		ci.draw_string(font, c + Vector2(-size, fs * 0.35), str(value), HORIZONTAL_ALIGNMENT_CENTER, size * 2, fs, DOT)
