## The store's rules (2026-11-05, Terrence): heroes and dice skins bought
## with currencies earned in play. Pure logic over the catalog
## (content/store.json) and the save; the game draws and plays sounds.
##
## An item without a price is owned from the start. An item priced in a
## currency whose "open" is false is locked: it can't be earned yet, so it
## can't be bought. Gems are the save's top-level "gems"; every other
## currency is save["currencies"][id].
extends RefCounted

const JsonUtil := preload("res://logic/core/json_util.gd")

const PATH := "res://content/store.json"
const KINDS := ["hero", "dice"]

## What an item's card shows.
const EQUIPPED := "equipped"  # owned and in use: a check mark
const OWNED := "owned"        # owned, not in use: "Use"
const BUY := "buy"            # open currency, enough of it: "Buy"
const SHORT := "short"        # open currency, not enough yet: greyed
const LOCKED := "locked"      # the currency can't be earned yet: a lock

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


## The item a kind starts with: its first unpriced item.
static func default_id(cat: Dictionary, kind: String) -> String:
	for it in items(cat, kind):
		if not it.has("price"):
			return it["id"]
	return ""


static func is_open(cat: Dictionary, currency: String) -> bool:
	return bool(cat["currencies"].get(currency, {}).get("open", false))


static func balance(save: Dictionary, currency: String) -> int:
	if currency == "gems":
		return int(save.get("gems", 0))
	return int(save.get("currencies", {}).get(currency, 0))


## Earning: gems go to the top-level "gems", the rest to "currencies".
static func add(save: Dictionary, currency: String, n: int) -> void:
	if currency == "gems":
		save["gems"] = int(save.get("gems", 0)) + n
		return
	if not save.has("currencies") or not save["currencies"] is Dictionary:
		save["currencies"] = {}
	save["currencies"][currency] = balance(save, currency) + n


## Sets a currency back to zero (the store's reset, Terrence 2026-11-05).
## Only the balance: heroes and dice already bought stay owned.
static func reset_balance(save: Dictionary, currency: String) -> void:
	add(save, currency, -balance(save, currency))


static func owns(cat: Dictionary, save: Dictionary, id: String) -> bool:
	var it := item(cat, id)
	if it.is_empty():
		return false
	return not it.has("price") or save.get("owned", []).has(id)


static func is_locked(cat: Dictionary, save: Dictionary, id: String) -> bool:
	var it := item(cat, id)
	if it.is_empty():
		return true
	if owns(cat, save, id):
		return false
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
