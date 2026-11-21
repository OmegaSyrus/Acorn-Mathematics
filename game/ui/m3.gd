## The Material Design 3 kit for the profile screens (profile plan P1,
## 2026-11-21): colour, shape, type and spacing tokens, and code-drawn parts
## (buttons, card, outlined text field, top bar, dialog, icons). Every part
## is a static draw call on any CanvasItem, like RoundBox, so a screen stays
## a Node2D that draws in _draw() and hands the same rects to ChoiceWidget.
##
## Units are the 960x540 design space. On the Galaxy Tab A7 Lite 1 unit is
## about 1.3 dp, so Material's 48 dp touch target is 37 units; anything a
## child taps here is TARGET (56) units or more. Sizes are Material's, scaled
## up for a 5-year-old's finger and eyes. Spacing is on the 8-unit GRID.
## Keep tappable parts inside SAFE (x 120 to 840), the band a 4:3 screen
## shows.
extends RefCounted

const RoundBox := preload("res://game/ui/round_box.gd")

# --- Layout tokens -----------------------------------------------------------

const DESIGN := Vector2(960, 540)
## The band every screen shape shows (720 wide on 4:3, centred).
const SAFE := Rect2(120, 0, 720, 540)
const GRID := 8.0
## The smallest tap target, both ways.
const TARGET := 56.0
## Material's own 48 dp minimum, in units on the A7 Lite (for reference).
const MATERIAL_TARGET := 37.0
## The least space between two tap targets (one grid step). ChoiceWidget
## counts a tap up to its PAD (6) outside a target and takes the first hit,
## so an 8 gap never picks the wrong one by more than 2 units.
const MIN_GAP := 8.0

# --- Colour tokens: a dark scheme seeded from acorn amber --------------------
# Roles follow Material 3 (primary, on_primary, ...); tones picked by hand
# from an amber seed (#C68A2E), a bark secondary and a leaf-green tertiary.

const PRIMARY := Color("#ffb95c")
const ON_PRIMARY := Color("#462a00")
const PRIMARY_CONTAINER := Color("#653e00")
const ON_PRIMARY_CONTAINER := Color("#ffddb5")
const SECONDARY := Color("#ddc2a1")
const ON_SECONDARY := Color("#3e2d16")
const SECONDARY_CONTAINER := Color("#56442a")
const ON_SECONDARY_CONTAINER := Color("#fadebc")
const TERTIARY := Color("#a6d39a")
const ON_TERTIARY := Color("#123811")
const TERTIARY_CONTAINER := Color("#29512a")
const ON_TERTIARY_CONTAINER := Color("#c1efb4")
const ERROR := Color("#ffb4ab")
const ON_ERROR := Color("#690005")
const ERROR_CONTAINER := Color("#93000a")
const ON_ERROR_CONTAINER := Color("#ffdad6")
const SURFACE := Color("#18120c")
const ON_SURFACE := Color("#eee0d5")
const ON_SURFACE_VARIANT := Color("#d5c4b5")
const SURFACE_CONTAINER_LOWEST := Color("#120d07")
const SURFACE_CONTAINER_LOW := Color("#201a14")
const SURFACE_CONTAINER := Color("#251e17")
const SURFACE_CONTAINER_HIGH := Color("#2f2921")
const SURFACE_CONTAINER_HIGHEST := Color("#3a332c")
const OUTLINE := Color("#9e8e81")
const OUTLINE_VARIANT := Color("#51443a")
const SCRIM := Color(0, 0, 0, 0.55)
## The current player's ring (S1) and other "this one is you" marks.
const GOLD := Color(1.0, 0.82, 0.35)

## State layers (Material: hover 8%, pressed 12%), disabled content 38%.
const PRESSED_LAYER := 0.12
const DISABLED_ALPHA := 0.38

# --- Shape tokens (corner radius) --------------------------------------------

const SHAPE_XS := 4.0
const SHAPE_S := 8.0
const SHAPE_M := 12.0
const SHAPE_L := 16.0
const SHAPE_XL := 28.0

# --- Type tokens (font size in units) ----------------------------------------
# Material's scale, about 1.5x, so a sight word reads from arm's length.

const DISPLAY := 56
const HEADLINE := 40
const TITLE := 30
const LABEL := 28
const BODY := 24
const SMALL := 18

# --- Part sizes --------------------------------------------------------------

const BUTTON_H := 64.0
const BUTTON_PAD := 32.0  # side padding inside a button
const BUTTON_MIN_W := 112.0
const ICON := 28.0  # icon size inside buttons
const ICON_GAP := 8.0
const ICON_BUTTON := 64.0
const TOP_BAR_H := 80.0
const FIELD_H := 80.0
const DIALOG_W := 480.0
const DIALOG_PAD := 24.0

## Button styles.
enum Style { FILLED, TONAL, OUTLINED, TEXT }
## Part states.
enum State { NORMAL, PRESSED, DISABLED }
## Code-drawn icons.
enum Icon { NONE, PLUS, PENCIL, CHECK, BACK, SWAP, LOCK, BIN }


static func font() -> Font:
	return ThemeDB.fallback_font


## A rect grown, around its middle, to at least TARGET both ways: the area a
## tap should count in even when the drawn part is smaller.
static func target(r: Rect2) -> Rect2:
	var s := Vector2(maxf(r.size.x, TARGET), maxf(r.size.y, TARGET))
	return Rect2(r.get_center() - s / 2.0, s)


static func snap(v: float) -> float:
	return roundf(v / GRID) * GRID


# --- Text --------------------------------------------------------------------

static func text_width(text: String, size: int) -> float:
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Text centred in `r` both ways (the baseline is placed from the font's
## ascent and descent, so caps sit in the optical middle).
static func text_center(ci: CanvasItem, r: Rect2, text: String, size: int, col: Color) -> void:
	var f := font()
	var y := r.get_center().y + (f.get_ascent(size) - f.get_descent(size)) / 2.0
	ci.draw_string(f, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, col)


## Text from the left of `r`, middle of `r` up and down.
static func text_left(ci: CanvasItem, r: Rect2, text: String, size: int, col: Color) -> void:
	var f := font()
	var y := r.get_center().y + (f.get_ascent(size) - f.get_descent(size)) / 2.0
	ci.draw_string(f, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, size, col)


# --- Buttons -----------------------------------------------------------------

## The width a button needs for its label and icon (at least BUTTON_MIN_W).
static func button_width(text: String, icon := Icon.NONE) -> float:
	var w := BUTTON_PAD * 2.0 + text_width(text, LABEL)
	if icon != Icon.NONE:
		w += ICON + (ICON_GAP if text != "" else 0.0)
	return maxf(BUTTON_MIN_W, ceilf(w / GRID) * GRID)


## A button rect with its top-left at `at`, sized for the label.
static func button_rect(at: Vector2, text: String, icon := Icon.NONE) -> Rect2:
	return Rect2(at, Vector2(button_width(text, icon), BUTTON_H))


## A full-round button. One FILLED button per screen for the main action,
## TONAL or OUTLINED for the rest, TEXT for the least important.
static func button(ci: CanvasItem, r: Rect2, text: String, style := Style.FILLED, icon := Icon.NONE,
		state := State.NORMAL) -> void:
	var radius := r.size.y / 2.0
	var fg := ON_PRIMARY
	match style:
		Style.FILLED:
			RoundBox.fill(ci, r, _dim(PRIMARY, state, true), radius)
		Style.TONAL:
			RoundBox.fill(ci, r, _dim(SECONDARY_CONTAINER, state, true), radius)
			fg = ON_SECONDARY_CONTAINER
		Style.OUTLINED:
			RoundBox.frame(ci, r.grow(-1.0), _dim(OUTLINE, state, false), 2.0, radius - 1.0)
			fg = PRIMARY
		Style.TEXT:
			fg = PRIMARY
	if state == State.PRESSED:
		RoundBox.fill(ci, r, Color(fg, PRESSED_LAYER), radius)
	if state == State.DISABLED:
		fg = Color(ON_SURFACE, DISABLED_ALPHA)
	_label_with_icon(ci, r, text, icon, fg)


## A round icon-only button (the top bar's back arrow, for one). `tonal`
## gives it a filled circle; otherwise it is just the icon.
static func icon_button(ci: CanvasItem, r: Rect2, icon: Icon, tonal := false, state := State.NORMAL) -> void:
	var fg := ON_SURFACE_VARIANT
	if tonal:
		RoundBox.fill(ci, r, _dim(SECONDARY_CONTAINER, state, true), r.size.y / 2.0)
		fg = ON_SECONDARY_CONTAINER
	if state == State.PRESSED:
		RoundBox.fill(ci, r, Color(fg, PRESSED_LAYER), r.size.y / 2.0)
	if state == State.DISABLED:
		fg = Color(ON_SURFACE, DISABLED_ALPHA)
	var s := Vector2(ICON, ICON) * 1.15
	draw_icon(ci, icon, Rect2(r.get_center() - s / 2.0, s), fg)


static func _label_with_icon(ci: CanvasItem, r: Rect2, text: String, icon: Icon, fg: Color) -> void:
	var tw := text_width(text, LABEL) if text != "" else 0.0
	var iw := ICON if icon != Icon.NONE else 0.0
	var gap := ICON_GAP if (icon != Icon.NONE and text != "") else 0.0
	var x := r.get_center().x - (tw + iw + gap) / 2.0
	if icon != Icon.NONE:
		draw_icon(ci, icon, Rect2(Vector2(x, r.get_center().y - ICON / 2.0), Vector2(ICON, ICON)), fg)
	if text != "":
		text_left(ci, Rect2(Vector2(x + iw + gap, r.position.y), Vector2(tw + 4.0, r.size.y)), text, LABEL, fg)


static func _dim(c: Color, state: State, is_fill: bool) -> Color:
	if state != State.DISABLED:
		return c
	return Color(ON_SURFACE, 0.12 if is_fill else DISABLED_ALPHA)


# --- Card --------------------------------------------------------------------

## A filled card. `selected` adds the gold ring and a check badge at the
## top right (the chosen avatar, the current player).
static func card(ci: CanvasItem, r: Rect2, selected := false, state := State.NORMAL) -> void:
	RoundBox.fill(ci, r, SURFACE_CONTAINER_HIGHEST, SHAPE_M)
	if state == State.PRESSED:
		RoundBox.fill(ci, r, Color(ON_SURFACE, PRESSED_LAYER), SHAPE_M)
	if selected:
		RoundBox.frame(ci, r.grow(-2.0), GOLD, 4.0, SHAPE_M - 2.0)
		check_badge(ci, Vector2(r.end.x - 18.0, r.position.y + 18.0))
	if state == State.DISABLED:
		RoundBox.fill(ci, r, Color(SURFACE, 1.0 - DISABLED_ALPHA), SHAPE_M)


## A small gold disc with a check, centred on `at`.
static func check_badge(ci: CanvasItem, at: Vector2, radius := 14.0) -> void:
	ci.draw_circle(at, radius + 2.0, SURFACE, true, -1.0, true)
	ci.draw_circle(at, radius, GOLD, true, -1.0, true)
	var s := Vector2(radius, radius) * 1.3
	draw_icon(ci, Icon.CHECK, Rect2(at - s / 2.0, s), ON_PRIMARY)


# --- Outlined text field -----------------------------------------------------

## An outlined text field. The label sits in a notch on the top edge, the
## text inside, and a counter like "5/12" under the right end when
## `max_len` > 0. `focused` thickens the outline in the primary colour. A
## screen that takes typing puts a line_edit() over field_text_rect(r).
static func text_field(ci: CanvasItem, r: Rect2, label: String, value: String, max_len := 0,
		focused := false, error := false) -> void:
	var edge := ERROR if error else (PRIMARY if focused else OUTLINE)
	var width := 3.0 if focused or error else 2.0
	RoundBox.fill(ci, r, SURFACE_CONTAINER_LOW, SHAPE_XS)
	RoundBox.frame(ci, r, edge, width, SHAPE_XS)
	if label != "":
		var lw := text_width(label, SMALL) + 8.0
		var notch := Rect2(r.position + Vector2(12.0, -width - 1.0), Vector2(lw, width * 2.0 + 2.0))
		ci.draw_rect(notch, SURFACE)
		text_left(ci, Rect2(notch.position + Vector2(4.0, -SMALL / 2.0 + width + 1.0), Vector2(lw, SMALL)),
				label, SMALL, edge if focused or error else ON_SURFACE_VARIANT)
	if value != "" and not focused:
		text_left(ci, field_text_rect(r), value, TITLE, ON_SURFACE)
	if max_len > 0:
		var count := "%d/%d" % [value.length(), max_len]
		var cr := Rect2(Vector2(r.end.x - 120.0, r.end.y + 4.0), Vector2(116.0, SMALL + 6.0))
		ci.draw_string(font(), Vector2(cr.position.x, cr.end.y - 6.0), count, HORIZONTAL_ALIGNMENT_RIGHT,
				cr.size.x, SMALL, ERROR if error else ON_SURFACE_VARIANT)


## Where the typed text goes inside a field.
static func field_text_rect(r: Rect2) -> Rect2:
	return Rect2(r.position + Vector2(16.0, 8.0), r.size - Vector2(32.0, 16.0))


## A LineEdit styled to sit inside a text_field (no box of its own), so the
## tablet's keyboard comes up and typing is cut at `max_len`. The owner adds
## it as a child and keeps drawing the field under it with focused = true.
static func line_edit(r: Rect2, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	var tr := field_text_rect(r)
	e.position = tr.position
	e.size = tr.size
	e.max_length = max_len
	e.add_theme_font_size_override("font_size", TITLE)
	e.add_theme_color_override("font_color", ON_SURFACE)
	e.add_theme_color_override("caret_color", PRIMARY)
	e.add_theme_color_override("selection_color", Color(PRIMARY, 0.35))
	e.add_theme_constant_override("caret_width", 3)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(s, empty)
	return e


# --- Top bar -----------------------------------------------------------------

## The bar across the top of a screen: full frame wide (so 16:9 shows no
## gap), parts inside the safe band.
static func top_bar_rect() -> Rect2:
	return Rect2(-480.0, 0.0, DESIGN.x + 960.0, TOP_BAR_H)


## The back arrow's tap rect, at the left of the safe band.
static func top_bar_back_rect() -> Rect2:
	var y := (TOP_BAR_H - ICON_BUTTON) / 2.0
	return Rect2(Vector2(SAFE.position.x + GRID, y), Vector2(ICON_BUTTON, ICON_BUTTON))


## The i-th action from the right of the safe band (0 is the rightmost).
## An action with text is a TONAL button; pass its label and icon to size it.
static func top_bar_action_rect(i: int, text := "", icon := Icon.NONE) -> Rect2:
	var y := (TOP_BAR_H - ICON_BUTTON) / 2.0
	var right := SAFE.end.x - GRID
	var w := ICON_BUTTON if text == "" else button_width(text, icon)
	# Earlier actions are assumed icon-sized; screens with several labelled
	# actions place them with button_rect() instead.
	right -= i * (ICON_BUTTON + GRID)
	return Rect2(Vector2(right - w, y), Vector2(w, ICON_BUTTON))


## Draws the bar, its title and (when `with_back`) the back arrow. Actions
## are drawn by the screen with button() or icon_button() at
## top_bar_action_rect().
static func top_bar(ci: CanvasItem, title: String, with_back := true, back_state := State.NORMAL) -> void:
	ci.draw_rect(top_bar_rect(), SURFACE_CONTAINER)
	var x := SAFE.position.x + GRID * 3.0
	if with_back:
		icon_button(ci, top_bar_back_rect(), Icon.BACK, false, back_state)
		x = top_bar_back_rect().end.x + GRID * 2.0
	text_left(ci, Rect2(Vector2(x, 0.0), Vector2(SAFE.end.x - x, TOP_BAR_H)), title, TITLE, ON_SURFACE)


# --- Dialog ------------------------------------------------------------------

## The dialog box, centred in the design frame, tall enough for its body.
static func dialog_rect(body_lines := 1) -> Rect2:
	var h := DIALOG_PAD * 3.0 + HEADLINE + body_lines * (BODY + 8.0) + GRID * 2.0 + BUTTON_H
	h = ceilf(h / GRID) * GRID
	return Rect2((DESIGN - Vector2(DIALOG_W, h)) / 2.0, Vector2(DIALOG_W, h))


## The dialog's button rects, right-aligned in the order given (the last is
## the confirming one, at the far right, as Material lays them out).
static func dialog_button_rects(box: Rect2, labels: Array) -> Array:
	var out := []
	var x := box.end.x - DIALOG_PAD
	var y := box.end.y - DIALOG_PAD - BUTTON_H
	for i in range(labels.size() - 1, -1, -1):
		var w := button_width(str(labels[i]))
		x -= w
		out.push_front(Rect2(Vector2(x, y), Vector2(w, BUTTON_H)))
		x -= GRID
	return out


## Draws a scrim over the whole frame, then the dialog with its title, body
## lines and buttons. The last button confirms and is FILLED; the others
## are TEXT. With `danger` the confirming button uses the error colours
## (Remove). Returns the button rects.
static func dialog(ci: CanvasItem, title: String, body: Array, labels: Array, danger := false,
		icon := Icon.NONE) -> Array:
	ci.draw_rect(Rect2(-480.0, -100.0, DESIGN.x + 960.0, DESIGN.y + 200.0), SCRIM)
	var box := dialog_rect(body.size())
	RoundBox.fill(ci, box, SURFACE_CONTAINER_HIGH, SHAPE_XL)
	var y := box.position.y + DIALOG_PAD
	if icon != Icon.NONE:
		draw_icon(ci, icon, Rect2(Vector2(box.position.x + DIALOG_PAD, y + 4.0), Vector2(32, 32)),
				ERROR if danger else SECONDARY)
	var tx := box.position.x + DIALOG_PAD + (44.0 if icon != Icon.NONE else 0.0)
	text_left(ci, Rect2(Vector2(tx, y), Vector2(box.end.x - DIALOG_PAD - tx, HEADLINE)), title, HEADLINE - 8,
			ON_SURFACE)
	y += HEADLINE + DIALOG_PAD
	for line in body:
		text_left(ci, Rect2(Vector2(box.position.x + DIALOG_PAD, y), Vector2(DIALOG_W - DIALOG_PAD * 2, BODY)),
				str(line), BODY, ON_SURFACE_VARIANT)
		y += BODY + 8.0
	var rects := dialog_button_rects(box, labels)
	for i in rects.size():
		var last: bool = i == rects.size() - 1
		if last and danger:
			RoundBox.fill(ci, rects[i], ERROR_CONTAINER, BUTTON_H / 2.0)
			text_center(ci, rects[i], str(labels[i]), LABEL, ON_ERROR_CONTAINER)
		else:
			button(ci, rects[i], str(labels[i]), Style.FILLED if last else Style.TEXT)
	return rects


# --- Icons -------------------------------------------------------------------

## Draws `icon` to fill the square-ish rect `r` in colour `col`. Icons are
## strokes on a 24-point grid (Material Symbols' grid), scaled to `r`.
static func draw_icon(ci: CanvasItem, icon: Icon, r: Rect2, col: Color) -> void:
	var k := minf(r.size.x, r.size.y) / 24.0
	var o := r.get_center() - Vector2(12, 12) * k
	var w := maxf(2.0, 2.5 * k)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * k
	match icon:
		Icon.PLUS:
			ci.draw_line(p.call(12, 4), p.call(12, 20), col, w, true)
			ci.draw_line(p.call(4, 12), p.call(20, 12), col, w, true)
		Icon.CHECK:
			ci.draw_polyline(PackedVector2Array([p.call(4.5, 12.5), p.call(9.5, 17.5), p.call(19.5, 6.5)]),
					col, w, true)
		Icon.BACK:
			ci.draw_line(p.call(5, 12), p.call(20, 12), col, w, true)
			ci.draw_polyline(PackedVector2Array([p.call(11, 5.5), p.call(4.5, 12), p.call(11, 18.5)]), col, w, true)
		Icon.PENCIL:
			# A pencil leaning right: body, wood tip, and the lead point.
			var body := PackedVector2Array([p.call(16, 3.5), p.call(20.5, 8), p.call(9, 19.5), p.call(4.5, 15)])
			ci.draw_colored_polygon(body, col)
			var tip := PackedVector2Array([p.call(4.5, 15), p.call(9, 19.5), p.call(3, 21)])
			ci.draw_colored_polygon(tip, col)
			ci.draw_line(p.call(13.5, 6), p.call(18, 10.5), Color(0, 0, 0, 0.35), w * 0.6, true)
		Icon.SWAP:
			# Two arrows: right along the top, left along the bottom.
			ci.draw_line(p.call(4, 8), p.call(19, 8), col, w, true)
			ci.draw_polyline(PackedVector2Array([p.call(15, 4), p.call(19.5, 8), p.call(15, 12)]), col, w, true)
			ci.draw_line(p.call(20, 16), p.call(5, 16), col, w, true)
			ci.draw_polyline(PackedVector2Array([p.call(9, 12), p.call(4.5, 16), p.call(9, 20)]), col, w, true)
		Icon.LOCK:
			ci.draw_arc(p.call(12, 9.5), 4.5 * k, PI, TAU, 12, col, w, true)
			ci.draw_line(p.call(7.5, 9.5), p.call(7.5, 11), col, w, true)
			ci.draw_line(p.call(16.5, 9.5), p.call(16.5, 11), col, w, true)
			RoundBox.fill(ci, Rect2(p.call(5, 11), Vector2(14, 10) * k), col, 2.0 * k)
			ci.draw_circle(p.call(12, 16), 1.6 * k, Color(0, 0, 0, 0.5), true, -1.0, true)
		Icon.BIN:
			ci.draw_line(p.call(4, 6.5), p.call(20, 6.5), col, w, true)
			ci.draw_polyline(PackedVector2Array([p.call(9, 6.5), p.call(9.5, 3.5), p.call(14.5, 3.5), p.call(15, 6.5)]),
					col, w * 0.8, true)
			ci.draw_polyline(PackedVector2Array([p.call(6, 6.5), p.call(7, 20.5), p.call(17, 20.5), p.call(18, 6.5)]),
					col, w, true)
			ci.draw_line(p.call(10, 10), p.call(10.3, 17), col, w * 0.7, true)
			ci.draw_line(p.call(14, 10), p.call(13.7, 17), col, w * 0.7, true)
