## The store's rules (2026-11-05, Terrence): heroes and dice skins bought
## with currencies earned in play. Pure logic over the catalog
## (content/store.json) and the save; the game draws and plays sounds.
##
## An item without a price is owned from the start. An item priced in a
## currency whose "open" is false is locked: it can't be earned yet, so it
## can't be bought. Gems are the save's top-level "gems"; every other
## currency is save["currencies"][id].
##
## Level heroes (Phase 6, 2026-11-28): an item with "reward": {"level_pass": N}
## has no price. It becomes the child's ("owned") the first time every world
## is beaten at Level N (AreaFlow.level_beaten), after that boss or when a
## save that already did it is loaded (grant_level_rewards).
extends RefCounted

const JsonUtil := preload("res://logic/core/json_util.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const AreaFlow := preload("res://logic/path/area_flow.gd")

const PATH := "res://content/store.json"
const KINDS := ["hero", "dice"]

## What an item's card shows.
const EQUIPPED := "equipped"  # owned and in use: a check mark
const OWNED := "owned"        # owned, not in use: "Use"
const BUY := "buy"            # open currency, enough of it: "Buy"
const SHORT := "short"        # open currency, not enough yet: greyed
const LOCKED := "locked"      # the currency can't be earned yet: a lock
const LEVEL := "level"        # a Level hero not won yet: a lock and "Level N"

static var _cached := {}


static func catalog() -> Dictionary:
	if _cached.is_empty():
		var data = JsonUtil.load_file(PATH)
		_cached = data if data is Dictionary else {"currencies": {}, "items": []}
	return _cached


static func items(cat: Dictionary, kind: String) -> Array:
	var out := []
	for it in cat["items"]:
		if it["kind"] == kind:
			out.append(it)
	return out


static func item(cat: Dictionary, id: String) -> Dictionary:
	for it in cat["items"]:
		if it["id"] == id:
			return it
	return {}


## The item a kind starts with: its first item with no price and no reward.
static func default_id(cat: Dictionary, kind: String) -> String:
	for it in items(cat, kind):
		if not it.has("price") and not it.has("reward"):
			return it["id"]
	return ""


## The Level whose first full pass gives this item, 0 for a shop item.
static func reward_level(it: Dictionary) -> int:
	var r = it.get("reward", {})
	return int(r.get("level_pass", 0)) if r is Dictionary else 0


## The items of a kind that are bought (no reward), in catalog order.
static func shop_items(cat: Dictionary, kind: String) -> Array:
	return items(cat, kind).filter(func(it): return reward_level(it) == 0)


## Every Level reward (any kind), by its Level.
static func reward_items(cat: Dictionary) -> Array:
	var out: Array = cat["items"].filter(func(it): return reward_level(it) > 0)
	out.sort_custom(func(a, b): return reward_level(a) < reward_level(b))
	return out


## Gives every Level reward whose Level has had its full pass and isn't
## owned yet; returns the ids given, in Level order (empty when nothing is
## new). Run after each boss and on every save load, so a save that beat a
## Level before the rewards existed gets them too. A reward is given once:
## a replay of the Level gives nothing.
static func grant_level_rewards(cat: Dictionary, save: Dictionary, worlds: Array) -> Array:
	var given := []
	if typeof(save.get("marks")) != TYPE_DICTIONARY:
		return given
	for it in reward_items(cat):
		var id: String = it["id"]
		if save.get("owned", []).has(id):
			continue
		if AreaFlow.level_beaten(save, worlds, reward_level(it)):
			if not save.has("owned") or not save["owned"] is Array:
				save["owned"] = []
			save["owned"].append(id)
			given.append(id)
	return given


## The currency a world pays (its chests and its boss's bucket): the open
## currency whose "world" is that world, else gems (Phase 0, 2026-11-16).
static func currency_of_world(cat: Dictionary, world_id: String) -> String:
	for id in cat["currencies"]:
		var c: Dictionary = cat["currencies"][id]
		if str(c.get("world", "")) == world_id and bool(c.get("open", false)):
			return id
	return "gems"


## The open currencies, in catalog order (the store's balances strip).
static func open_currencies(cat: Dictionary) -> Array:
	var out := []
	for id in cat["currencies"]:
		if is_open(cat, id):
			out.append(id)
	return out


static func is_open(cat: Dictionary, currency: String) -> bool:
	return bool(cat["currencies"].get(currency, {}).get("open", false))


static func balance(save: Dictionary, currency: String) -> int:
	if currency == "gems":
		return int(save.get("gems", 0))
	return int(save.get("currencies", {}).get(currency, 0))


## Earning: gems go to the top-level "gems", the rest to "currencies".
static func add(save: Dictionary, currency: String, n: int) -> void:
	if currency == "gems":
		SaveData.add_gems(save, n)  # counts earned and spent per device
		return
	if not save.has("currencies") or not save["currencies"] is Dictionary:
		save["currencies"] = {}
	save["currencies"][currency] = balance(save, currency) + n


static func owns(cat: Dictionary, save: Dictionary, id: String) -> bool:
	var it := item(cat, id)
	if it.is_empty():
		return false
	if not it.has("price") and not it.has("reward"):
		return true
	return save.get("owned", []).has(id)


static func is_locked(cat: Dictionary, save: Dictionary, id: String) -> bool:
	var it := item(cat, id)
	if it.is_empty():
		return true
	if owns(cat, save, id):
		return false
	if not it.has("price"):
		return true  # a Level reward not won yet
	return not is_open(cat, it["price"]["currency"])


static func can_afford(cat: Dictionary, save: Dictionary, id: String) -> bool:
	var it := item(cat, id)
	if it.is_empty() or not it.has("price") or is_locked(cat, save, id):
		return false
	var p: Dictionary = it["price"]
	return balance(save, p["currency"]) >= int(p["amount"])


## The equipped item of a kind; falls back to the default when the save
## names something missing or not owned.
static func equipped(cat: Dictionary, save: Dictionary, kind: String) -> String:
	var id := str(save.get(kind, ""))
	var it := item(cat, id)
	if not it.is_empty() and it["kind"] == kind and owns(cat, save, id):
		return id
	return default_id(cat, kind)


static func state(cat: Dictionary, save: Dictionary, id: String) -> String:
	var it := item(cat, id)
	if it.is_empty():
		return LOCKED
	if owns(cat, save, id):
		return EQUIPPED if equipped(cat, save, it["kind"]) == id else OWNED
	if reward_level(it) > 0:
		return LEVEL
	if is_locked(cat, save, id):
		return LOCKED
	return BUY if can_afford(cat, save, id) else SHORT


## Spends the price and adds the item to "owned". False (and no change)
## when it is owned already, locked or too dear.
static func buy(cat: Dictionary, save: Dictionary, id: String) -> bool:
	if owns(cat, save, id) or not can_afford(cat, save, id):
		return false
	var p: Dictionary = item(cat, id)["price"]
	add(save, p["currency"], -int(p["amount"]))
	if not save.has("owned") or not save["owned"] is Array:
		save["owned"] = []
	save["owned"].append(id)
	return true


## Puts an owned item in use (save "hero" or "dice"). False when not owned.
static func equip(cat: Dictionary, save: Dictionary, id: String) -> bool:
	if not owns(cat, save, id):
		return false
	save[item(cat, id)["kind"]] = id
	return true
