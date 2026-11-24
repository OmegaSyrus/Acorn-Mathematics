## Small sprites for the half-size crossings (art grid plan; Terrence
## 2026-11-24 picked "make small crossing sprites"). A crossing after Lava 1
## draws its world at half size, which used to shrink every 1:1 sprite and
## smooth away half its pixels. Each sprite now has a hand-made half-size twin
## at art/<world>/half/<same name>.png, drawn into the full-size rect, so on
## screen it lands back on the 1 art pixel = 1 unit grid. A sprite with no
## twin falls back to itself (shrunk and smoothed, as before).
extends RefCounted

static var _cache := {}


static func of(t: Texture2D) -> Texture2D:
	if t == null or t.resource_path == "":
		return t
	var p := t.resource_path
	if not _cache.has(p):
		var hp := p.get_base_dir().path_join("half").path_join(p.get_file())
		_cache[p] = load(hp) if ResourceLoader.exists(hp) else t
	return _cache[p]


## True when t has a half-size twin.
static func has(t: Texture2D) -> bool:
	return of(t) != t
