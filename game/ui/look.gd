## What the player has equipped from the store (content/store.json): the
## hero sprite every screen draws and the dice skin DieView uses. Set from
## the save when the main menu opens and again on every equip; the screens
## read it, so no save has to be passed down to them.
extends RefCounted

const Store := preload("res://logic/core/store.gd")

const DEFAULT_HERO := "robodragon"
## The one pixel grid for every hero and enemy sprite (2026-11-05, Terrence:
## sizes were "wildly different"): one art pixel is one unit of the 960x540
## frame, on every screen. Characters are never scaled up or down; a character
## that has to be bigger or smaller gets art made at that size instead.
## (On the 1340x800 tablet one unit is about 1.5 screen pixels.)
const CHAR_PX := 1.0

static var hero_id := DEFAULT_HERO
static var dice_id := "classic"
static var _hero_tex := {}


static func apply(save: Dictionary) -> void:
	var cat := Store.catalog()
	hero_id = Store.equipped(cat, save, "hero")
	dice_id = Store.equipped(cat, save, "dice")


## The hero's sprite (faces right), drawn at CHAR_PX like every character.
static func hero_texture(id := "") -> Texture2D:
	if id == "":
		id = hero_id
	if _hero_tex.has(id):
		return _hero_tex[id]
	var it := Store.item(Store.catalog(), id)
	if it.is_empty() or it["kind"] != "hero":
		it = Store.item(Store.catalog(), DEFAULT_HERO)
	var tex: Texture2D = load(it["art"])
	if it.has("paint"):
		tex = painted(tex, it["paint"])
	_hero_tex[id] = tex
	return tex


## True for Bolt in any color: the screens know where the robot dragon's eye is.
static func is_default_hero() -> bool:
	var it := Store.item(Store.catalog(), hero_id)
	return hero_id == DEFAULT_HERO or (not it.is_empty() and it.get("art", "") == Store.item(Store.catalog(), DEFAULT_HERO).get("art"))


## Bolt in another color (2026-11-06, Terrence: red, black, green, purple,
## pink), done in code from the one sprite so it stays on the same pixel grid.
## The body's blue-grey shades take the paint's hue; the dark outline and the
## teal eyes and lights stay as they are. paint: {hue, sat, value} with hue
## 0..1, sat the added saturation, value a brightness factor.
static func painted(src: Texture2D, paint: Dictionary) -> Texture2D:
	var img: Image = src.get_image().duplicate()  # get_image can hand back the texture's own copy
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var hue := float(paint.get("hue", 0.0))
	var add_sat := float(paint.get("sat", 0.5))
	var vf := float(paint.get("value", 1.0))
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0 or not is_body_shade(c):
				continue
			var out := Color.from_hsv(hue, clampf(c.s + add_sat, 0.0, 1.0), clampf(c.v * vf, 0.0, 1.0), c.a)
			img.set_pixel(x, y, out)
	return ImageTexture.create_from_image(img)


## The robot dragon's body: blue-grey (blue a little over red and green, not
## saturated), not the near-black outline and not the teal eyes and lights.
static func is_body_shade(c: Color) -> bool:
	if c.v < 0.16:
		return false
	if c.g > c.r + 0.12 and c.g >= c.b - 0.02:
		return false  # teal: eyes, chest light
	return c.b >= c.r and c.b >= c.g and c.s < 0.55
