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


## The dice faces that show a value: [v] up to 6, two faces up to 12 (the
## bigger first, 7 = 4 and 3), none above 12 (shown as a numeral).
static func split_value(value: int) -> Array:
	if value >= 1 and value <= 6:
		return [value]
	if value >= 7 and value <= 12:
		var a := ceili(value / 2.0)
		return [a, value - a]
	return []


## A value as the child sees it: one die up to 6, two dice side by side up to
## 12 (7 = 4 and 3), a numeral above 12.
static func draw_value(ci: CanvasItem, c: Vector2, size: float, value: int) -> void:
	var faces := split_value(value)
	if faces.size() == 1:
		draw_face(ci, c, size, value)
	elif faces.size() == 2:
		var gap := size * 0.56
		draw_face(ci, c - Vector2(gap, 0), size, faces[0])
		draw_face(ci, c + Vector2(gap, 0), size, faces[1])
	else:
		var font := ThemeDB.fallback_font
		var fs := int(size)
		ci.draw_string(font, c + Vector2(-size, fs * 0.35), str(value), HORIZONTAL_ALIGNMENT_CENTER, size * 2, fs, DOT)


const PLUS_COL := Color(0.3, 0.88, 0.35)
const MINUS_COL := Color(1.0, 0.32, 0.22)
const SIGN_RIM := Color(0.06, 0.03, 0.06)


## The plus or minus between two dice: big, coloured (green add, red take
## away, like the red die), drawn as bars so every font shows it. It swells
## a little and glows on a slow beat (t in seconds) to pull the eye up.
static func draw_op(ci: CanvasItem, c: Vector2, op: String, size: float, t: float, alpha := 1.0) -> void:
	var beat := 0.5 + 0.5 * sin(t * 4.0)
	var s := size * (1.0 + 0.08 * beat)
	var col: Color = PLUS_COL if op == "+" else MINUS_COL
	var glow := Color(col, (0.18 + 0.17 * beat) * alpha)
	ci.draw_circle(c, s * 0.78, glow)
	var long := s
	var thick := s * 0.3
	var rim := 3.0
	var bars := [Rect2(c - Vector2(long, thick) / 2.0, Vector2(long, thick))]
	if op == "+":
		bars.append(Rect2(c - Vector2(thick, long) / 2.0, Vector2(thick, long)))
	for r in bars:
		ci.draw_rect(r.grow(rim), Color(SIGN_RIM, alpha))
	for r in bars:
		ci.draw_rect(r, Color(col.lightened(0.15 * beat), alpha))
