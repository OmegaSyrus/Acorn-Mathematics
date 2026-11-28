## A currency's icon (content/store.json "icon"): its pixel art when it has
## one (gem, crystal, brooch, leaf, feather), else a shape drawn in code.
## Shared by the store, the crossing's counter and the boss's bucket.
extends RefCounted

const Store := preload("res://logic/core/store.gd")

static var _tex := {}
static var _small := {}


## The icon's art, or null for a currency drawn in code (the stars).
static func texture(cid: String) -> Texture2D:
	if not _tex.has(cid):
		var art := str(Store.catalog()["currencies"].get(cid, {}).get("icon", {}).get("art", ""))
		_tex[cid] = load(art) if art != "" else null
	return _tex[cid]


## The small twin (24x24, "<art>-24.png") drawn where an icon is asked for
## under 32 units tall; the main art is 40x40 (art grid plan P3).
static func texture_small(cid: String) -> Texture2D:
	if not _small.has(cid):
		var t := texture(cid)
		var p := t.resource_path.get_basename() + "-24.png" if t != null else ""
		_small[cid] = load(p) if p != "" and ResourceLoader.exists(p) else t
	return _small[cid]


## The icon centred on c, drawn 1:1 so its pixels sit on the unit grid:
## the 24 unit twin when `size` is under 32, else the 40 unit art. False when
## the currency has no art, so the caller can draw its own shape.
static func draw(ci: CanvasItem, cid: String, c: Vector2, size: float, tint := Color.WHITE) -> bool:
	var t := texture_small(cid) if size < 32.0 else texture(cid)
	if t == null:
		return false
	var sz := t.get_size()
	ci.draw_texture_rect(t, Rect2((c - sz / 2.0).round(), sz), false, tint)
	return true
