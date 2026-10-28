## Rounded boxes for every panel, bubble, button, frame and flat die face
## (2026-10-28: the children's mother asked for rounded borders).
extends RefCounted

const RADIUS := 12.0

static var _box := StyleBoxFlat.new()


static func fill(ci: CanvasItem, r: Rect2, col: Color, radius := RADIUS) -> void:
	_shape(radius)
	_box.draw_center = true
	_box.bg_color = col
	_box.set_border_width_all(0)
	ci.draw_style_box(_box, r)


## A rounded outline of `width`, centered on the rect's edge like draw_rect's.
static func frame(ci: CanvasItem, r: Rect2, col: Color, width := 2.0, radius := RADIUS) -> void:
	_shape(radius + width / 2.0)
	_box.draw_center = false
	_box.border_color = col
	_box.set_border_width_all(int(ceilf(width)))
	ci.draw_style_box(_box, r.grow(width / 2.0))


static func _shape(radius: float) -> void:
	_box.set_corner_radius_all(int(radius))
	_box.corner_detail = 8
	_box.anti_aliasing = true
