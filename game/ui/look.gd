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
	_hero_tex[id] = tex
	return tex


static func is_default_hero() -> bool:
	return hero_id == DEFAULT_HERO
