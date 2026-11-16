## Dice skins from the store, drawn in code (no art): each skin's six
## 96 px faces, built once in chunky 2 px pixels to sit beside the pixel art,
## with the pips exactly where the art has them (DieView counts taps there).
## Styles: plain, metal (brushed steel), gold (shine stripes), gem (facets).
## The die taken away (subtract) is always red: it keeps the skin's style
## but uses the catalog's subtract_look colours, so "red = take away" holds
## whatever the skin. The classic skin is the original face art.
extends RefCounted

const Store := preload("res://logic/core/store.gd")

const ART := "res://art/lava/"
const SIZE := 96
const PX := 2
const RADIUS := 12.0
const EDGE := Color(0.1, 0.06, 0.12)  # the face art's outline
const PIP_R := 8.0
## Pip centers in the 96 px frame (same as DieView.ART_PIPS, plus 48).
const PIPS := {
	1: [Vector2(48, 48)],
	2: [Vector2(69, 27), Vector2(27, 69)],
	3: [Vector2(69, 27), Vector2(48, 48), Vector2(27, 69)],
	4: [Vector2(27, 27), Vector2(69, 27), Vector2(27, 69), Vector2(69, 69)],
	5: [Vector2(27, 27), Vector2(69, 27), Vector2(48, 48), Vector2(27, 69), Vector2(69, 69)],
	6: [Vector2(27, 27), Vector2(27, 48), Vector2(27, 69), Vector2(69, 27), Vector2(69, 48), Vector2(69, 69)],
}

static var _cache := {}


## The face texture for value 1..6 of a skin; slip = the red subtract die.
static func face(skin_id: String, value: int, slip := false) -> Texture2D:
	var key := "%s:%d:%s" % [skin_id, value, slip]
	if _cache.has(key):
		return _cache[key]
	var it := Store.item(Store.catalog(), skin_id)
	var tex: Texture2D
	if it.is_empty() or it["kind"] != "dice" or skin_id == "classic":
		tex = load(ART + "die-%s-%d.png" % ["red" if slip else "wood", value])
	else:
		tex = ImageTexture.create_from_image(_build(it["look"], value, slip))
	_cache[key] = tex
	return tex


static func _build(look: Dictionary, value: int, slip: bool) -> Image:
	var style: String = look["style"]
	var face := Color(look["face"])
	var shade := Color(look["shade"])
	var pip := Color(look["pip"])
	if slip:
		var red: Dictionary = Store.catalog().get("subtract_look", {"face": "#d0321e", "shade": "#7e1408", "pip": "#ffffff"})
		face = Color(red["face"])
		shade = Color(red["shade"])
		pip = Color(red["pip"])
	var light_pips := pip.get_luminance() > 0.5
	var ring := shade.darkened(0.45)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var n := SIZE / PX
	for cy in n:
		for cx in n:
			var p := Vector2((cx + 0.5) * PX, (cy + 0.5) * PX)
			if not _inside(p, 0.0):
				continue
			var col := EDGE
			if _inside(p, PX * 1.0):
				col = _material(style, face, shade, p / SIZE, cx, cy)
				for c in PIPS[value]:
					var d := p.distance_to(c)
					if d <= PIP_R:
						col = pip
						# a little shine on the upper left of each pip
						if (p - c).x < -2.5 and (p - c).y < -2.5 and d > 3.0:
							col = pip.lightened(0.35) if not light_pips else pip
					elif d <= PIP_R + PX * 1.0 and light_pips:
						col = ring
			img.fill_rect(Rect2i(cx * PX, cy * PX, PX, PX), col)
	return img


## The face colour at uv (0..1 across the 96 px face) for a style.
static func _material(style: String, face: Color, shade: Color, uv: Vector2, cx: int, cy: int) -> Color:
	var bottom := uv.y > 0.86
	match style:
		"metal":
			var col := face.lerp(shade, clampf(uv.y * 0.75, 0.0, 1.0))
			# brushed streaks, row by row
			var streak := float((cy * 7 + (cy >> 1) * 3) % 5) / 5.0
			col = col.lightened(0.06 * streak) if cy % 2 == 0 else col.darkened(0.04 * streak)
			# a soft diagonal glint
			var g := absf(uv.x + uv.y - 0.7)
			if g < 0.06:
				col = col.lightened(0.35)
			elif g < 0.11:
				col = col.lightened(0.15)
			# rivets in the corners
			for r in [Vector2(0.12, 0.12), Vector2(0.88, 0.12), Vector2(0.12, 0.88), Vector2(0.88, 0.88)]:
				if uv.distance_to(r) < 0.03:
					col = shade.darkened(0.3)
			if bottom:
				col = col.darkened(0.25)
			return col
		"gold":
			var t := (uv.x + uv.y) / 2.0
			var col := face.lightened(0.4).lerp(face, clampf(t * 2.0, 0.0, 1.0))
			if t > 0.5:
				col = face.lerp(shade, clampf((t - 0.5) * 2.2, 0.0, 1.0))
			var d := uv.x - uv.y
			if absf(d + 0.25) < 0.05 or absf(d + 0.05) < 0.02:
				col = col.lightened(0.5)
			if bottom:
				col = col.darkened(0.2)
			return col
		"gem":
			var u := uv.x - 0.5
			var v := uv.y - 0.5
			var col := face.lightened(0.12)  # the table in the middle
			if maxf(absf(u), absf(v)) > 0.22:
				if absf(v) >= absf(u):
					col = face.lightened(0.38) if v < 0.0 else shade
				else:
					col = face if u < 0.0 else face.lerp(shade, 0.55)
			# facet edges
			if absf(absf(u) - absf(v)) < 0.02 and maxf(absf(u), absf(v)) > 0.22:
				col = col.lightened(0.2)
			# sparkles
			if (cx == 10 and cy == 9) or (cx == 11 and cy == 10) or (cx == 9 and cy == 10) or (cx == 10 and cy == 11) \
					or (cx == 36 and cy == 33):
				col = Color(1, 1, 1)
			return col
	# plain: the original's look, a lit top edge and a shaded bottom band
	var col := face
	if uv.y < 0.06:
		col = face.lightened(0.3)
	elif bottom:
		col = shade
	elif uv.x > 0.92:
		col = face.lerp(shade, 0.5)
	return col


static func _inside(p: Vector2, inset: float) -> bool:
	var lo := inset
	var hi := SIZE - inset
	var r := maxf(RADIUS - inset, 1.0)
	var cx := clampf(p.x, lo + r, hi - r)
	var cy := clampf(p.y, lo + r, hi - r)
	return p.x >= lo and p.x <= hi and p.y >= lo and p.y <= hi and Vector2(p.x - cx, p.y - cy).length() <= r
