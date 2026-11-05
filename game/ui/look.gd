## What the player has equipped from the store (content/store.json): the
## hero sprite every screen draws and the dice skin DieView uses. Set from
## the save when the main menu opens and again on every equip; the screens
## read it, so no save has to be passed down to them.
extends RefCounted

const Store := preload("res://logic/core/store.gd")

const DEFAULT_HERO := "robodragon"

static var hero_id := DEFAULT_HERO
static var dice_id := "classic"
static var _hero_tex := {}


static func apply(save: Dictionary) -> void:
	var cat := Store.catalog()
	hero_id = Store.equipped(cat, save, "hero")
	dice_id = Store.equipped(cat, save, "dice")


## The hero's sprite (faces right), already at the size it is drawn at 1x:
## an item's "scale" is baked in with nearest filtering, so every screen can
## keep sizing the hero by its texture.
static func hero_texture(id := "") -> Texture2D:
	if id == "":
		id = hero_id
	if _hero_tex.has(id):
		return _hero_tex[id]
	var it := Store.item(Store.catalog(), id)
	if it.is_empty() or it["kind"] != "hero":
		it = Store.item(Store.catalog(), DEFAULT_HERO)
	var tex: Texture2D = load(it["art"])
	var s := float(it.get("scale", 1.0))
	if not is_equal_approx(s, 1.0):
		var img := tex.get_image()
		img.resize(roundi(img.get_width() * s), roundi(img.get_height() * s), Image.INTERPOLATE_NEAREST)
		tex = ImageTexture.create_from_image(img)
	_hero_tex[id] = tex
	return tex


static func is_default_hero() -> bool:
	return hero_id == DEFAULT_HERO
