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


## The fiery panel behind the text boxes at the top (2026-10-29, Terrence):
## a dark ember fill with low flames licking up from the bottom, in chunky
## pixels to match the art, with a rounded outline. The flames flicker
## through FIRE_FRAMES frames; each size is built once and cached.
const FIRE_PX := 3
const FIRE_FRAMES := 6
const FIRE_FPS := 7.0
const FIRE_TOP := Color(0.12, 0.05, 0.07)
const FIRE_LOW := Color(0.27, 0.08, 0.06)
const FIRE_MID := Color(0.42, 0.13, 0.05)
const FIRE_HOT := Color(0.58, 0.24, 0.07)
const FIRE_RIM := Color(0.95, 0.55, 0.2)

static var _fire_cache := {}


static func fire(ci: CanvasItem, r: Rect2, t: float, radius := RADIUS, rim := FIRE_RIM) -> void:
	var f := int(t * FIRE_FPS) % FIRE_FRAMES
	var key := "%dx%d:%d:%d" % [int(r.size.x), int(r.size.y), int(radius), f]
	if not _fire_cache.has(key):
		_fire_cache[key] = _fire_texture(r.size, radius, f)
	ci.draw_texture_rect(_fire_cache[key], r, false)
	frame(ci, r, rim, 3.0, radius)


static func _fire_texture(size: Vector2, radius: float, f: int) -> ImageTexture:
	var w := int(ceilf(size.x / FIRE_PX))
	var h := int(ceilf(size.y / FIRE_PX))
	var rr := radius / FIRE_PX
	var ph := TAU * f / FIRE_FRAMES
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		# flame height at this column, as a share of the panel height
		var flame := 0.26 + 0.08 * sin(x * 0.55 + ph) + 0.06 * sin(x * 1.37 - ph * 2.0) + 0.04 * sin(x * 3.1 + ph * 3.0)
		for y in h:
			if not _inside_round(x + 0.5, y + 0.5, w, h, rr):
				continue
			var up := 1.0 - (y + 0.5) / h   # 0 at the bottom, 1 at the top
			var col := FIRE_TOP.lerp(FIRE_LOW, clampf(0.6 - up, 0.0, 1.0))
			if up < flame:
				var heat := 1.0 - up / flame
				col = FIRE_LOW.lerp(FIRE_MID, clampf(heat * 1.4, 0.0, 1.0))
				if heat > 0.7:
					col = FIRE_MID.lerp(FIRE_HOT, (heat - 0.7) / 0.3)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _inside_round(x: float, y: float, w: int, h: int, r: float) -> bool:
	var cx := clampf(x, r, w - r)
	var cy := clampf(y, r, h - r)
	return Vector2(x - cx, y - cy).length() <= r
