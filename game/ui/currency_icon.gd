## A currency's icon (content/store.json "icon"): its pixel art when it has
## one (gem, crystal, brooch, leaf, feather), else a shape drawn in code.
## Shared by the store, the crossing's counter and the boss's bucket.
extends RefCounted

const Store := preload("res://logic/core/store.gd")

static var _tex := {}


## The icon's art, or null for a currency drawn in code (the stars).
static func texture(cid: String) -> Texture2D:
	if not _tex.has(cid):
		var art := str(Store.catalog()["currencies"].get(cid, {}).get("icon", {}).get("art", ""))
		_tex[cid] = load(art) if art != "" else null
	return _tex[cid]


## The art drawn `size` tall (whole look kept), centred on c. False when the
## currency has no art, so the caller can draw its own shape.
static func draw(ci: CanvasItem, cid: String, c: Vector2, size: float, tint := Color.WHITE) -> bool:
	var t := texture(cid)
	if t == null:
		return false
	var s := size / maxf(t.get_width(), t.get_height())
	var sz := t.get_size() * s
	ci.draw_texture_rect(t, Rect2(c - sz / 2.0, sz), false, tint)
	return true
