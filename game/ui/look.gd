## What the player has equipped from the store (content/store.json): the
## hero sprite every screen draws and the dice skin DieView uses. Set from
## the save when the main menu opens and again on every equip; the screens
## read it, so no save has to be passed down to them.
extends RefCounted

const Store := preload("res://logic/core/store.gd")

const DEFAULT_HERO := "robodragon"

static var hero_id := DEFAULT_HERO
static var dice_id := "classic"
static var color_id := "steel"   # the robot dragon's colour
static var _hero_tex := {}


static func apply(save: Dictionary) -> void:
	var cat := Store.catalog()
	hero_id = Store.equipped(cat, save, "hero")
	dice_id = Store.equipped(cat, save, "dice")
	color_id = Store.equipped(cat, save, "color")


## The hero's sprite (faces right), already at the size it is drawn at 1x:
## an item's "scale" is baked in with nearest filtering, so every screen can
## keep sizing the hero by its texture.
static func hero_texture(id := "") -> Texture2D:
	if id == "":
		id = hero_id
	var it := Store.item(Store.catalog(), id)
	if it.is_empty() or it["kind"] != "hero":
		it = Store.item(Store.catalog(), DEFAULT_HERO)
	var art: String = it["art"]
	var key: String = it["id"]
	if key == DEFAULT_HERO:
		# the robot dragon wears the colour in use
		var col := Store.item(Store.catalog(), color_id)
		if not col.is_empty() and col["kind"] == "color":
			art = col["art"]
			key += ":" + color_id
	if _hero_tex.has(key):
		return _hero_tex[key]
	var tex: Texture2D = load(art)
	var s := float(it.get("scale", 1.0))
	if not is_equal_approx(s, 1.0):
		var img := tex.get_image()
		img.resize(roundi(img.get_width() * s), roundi(img.get_height() * s), Image.INTERPOLATE_NEAREST)
		tex = ImageTexture.create_from_image(img)
	_hero_tex[key] = tex
	return tex


## A dragon colour's sprite, for the store's colour cards. Kept in a cache:
## a texture loaded fresh each frame is freed before it is drawn.
static func color_texture(cid: String) -> Texture2D:
	var key := "color:" + cid
	if not _hero_tex.has(key):
		var col := Store.item(Store.catalog(), cid)
		if col.is_empty() or col["kind"] != "color":
			col = Store.item(Store.catalog(), DEFAULT_HERO)
		_hero_tex[key] = load(col["art"])
	return _hero_tex[key]


static func is_default_hero() -> bool:
	return hero_id == DEFAULT_HERO
