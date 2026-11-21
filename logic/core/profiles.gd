## Who plays on this device (family.profiles v1, docs/contract): the
## "Who is playing?" roster and the parent PIN. Pure: game/profile_store.gd
## does the file IO.
##
## Each profile has a random id (p_ + 12 hex), a nickname, a picture (one of
## the 14 shop looks, PICTURES), and guest true or false. A Guest plays and saves on the device
## but never syncs (docs/contract/api-v1.md). The PIN is kept as a salted
## sha256 and never leaves the device.
extends RefCounted

const Ids := preload("res://logic/core/ids.gd")
const JsonUtil := preload("res://logic/core/json_util.gd")
const AreaFlow := preload("res://logic/path/area_flow.gd")
const Content := preload("res://logic/core/content.gd")
const Store := preload("res://logic/core/store.gd")

const SCHEMA := "family.profiles"
const VERSION := 1
const MAX_PROFILES := 6
const NAME_MAX := 12
const PIN_LEN := 4
## Profile pictures (profile plan C1 and D1, 2026-11-21): the 14 hero looks in
## content/store.json, Bolt and his two colours first, then the 11 heroes
## friendliest first. A picture is only a picture: it does not unlock or equip
## that hero in play (the shop hero stays a reward). Screens draw one with
## Look.hero_texture(id) (game/ui/look.gd), which paints the Bolt colours.
const PICTURES := ["robodragon", "bolt_red", "bolt_green", "fox", "bunny", "hedgehog", "turtle",
		"lion", "eagle", "phoenix", "gryphon", "elf_mage", "templar", "slime_knight"]
## The first profile's picture, and what an unknown picture id becomes.
const DEFAULT_PICTURE := "fox"
const GUEST_NAME := "Guest"
const GUEST_PICTURE := "slime_knight"


## A roster with one child, "Player 1". fresh is true on a new install (no
## old save moved in): the game then opens the create flow for that first
## profile (finish_setup), and keeps opening it until it is done.
static func new_roster(now: int, fresh := false) -> Dictionary:
	var r := {"schema": SCHEMA, "v": VERSION, "active": "", "profiles": [], "pin": null}
	var p := add(r, "Player 1", DEFAULT_PICTURE, now)
	r["active"] = p["id"]
	if fresh:
		r["fresh"] = true
	return r


## True until the first profile on a new install has been through the create
## flow. Rosters from before this flag are never fresh.
static func is_fresh(r: Dictionary) -> bool:
	return bool(r.get("fresh", false))


## The end of the first-launch create flow: the first child takes the chosen
## name and picture (a blank name or unknown picture keeps what it has, so
## Back keeps "Player 1"), and the roster is no longer fresh.
static func finish_setup(r: Dictionary, nickname := "", picture := "") -> void:
	var kids := children(r)
	if not kids.is_empty():
		var id: String = kids[0]["id"]
		rename(r, id, nickname)
		set_picture(r, id, picture)
	r.erase("fresh")


## Adds a profile (not past MAX_PROFILES children plus one Guest) and returns
## it, or {} when full.
static func add(r: Dictionary, nickname: String, picture: String, now: int, guest := false) -> Dictionary:
	if guest and not guest_profile(r).is_empty():
		return guest_profile(r)
	if not guest and children(r).size() >= MAX_PROFILES:
		return {}
	var p := {"id": Ids.profile_id(), "nickname": clean_name(nickname), "picture": picture if PICTURES.has(picture) else DEFAULT_PICTURE,
			"guest": guest, "created": now, "child": null}
	r["profiles"].append(p)
	return p


## A new child profile (the create flow's "Yes"), or {} when full. A blank
## name becomes default_name ("Player N") and an unknown or blank picture
## the next free one, so add_child(r, now) alone still makes "Player N".
static func add_child(r: Dictionary, now: int, nickname := "", picture := "") -> Dictionary:
	var n := clean_name(nickname)
	if n.is_empty():
		n = default_name(r)
	if not PICTURES.has(picture):
		picture = next_free_picture(r)
	return add(r, n, picture, now)


## What the create flow's name box starts with: "Player N" for the next child.
static func default_name(r: Dictionary) -> String:
	return "Player %d" % (children(r).size() + 1)


## The first picture no profile uses yet (the create flow's first pick), or
## the first picture when all are used.
static func next_free_picture(r: Dictionary) -> String:
	var used := []
	for p in r["profiles"]:
		used.append(p["picture"])
	for c in PICTURES:
		if not used.has(c):
			return c
	return PICTURES[0]


## Room for another child (MAX_PROFILES, Guest not counted).
static func can_add(r: Dictionary) -> bool:
	return children(r).size() < MAX_PROFILES


## Making a new profile asks for the parent PIN when one is set (plan D2).
## The first profile on a new install is finish_setup, which never asks.
static func add_needs_pin(r: Dictionary) -> bool:
	return has_pin(r)


## The Guest profile, made the first time someone picks Guest.
static func ensure_guest(r: Dictionary, now: int) -> Dictionary:
	var g := guest_profile(r)
	if g.is_empty():
		g = add(r, GUEST_NAME, GUEST_PICTURE, now, true)
	return g


static func guest_profile(r: Dictionary) -> Dictionary:
	for p in r["profiles"]:
		if p.get("guest", false):
			return p
	return {}


## The non-guest profiles, in the order they were made.
static func children(r: Dictionary) -> Array:
	var out := []
	for p in r["profiles"]:
		if not p.get("guest", false):
			out.append(p)
	return out


static func find(r: Dictionary, id: String) -> Dictionary:
	for p in r["profiles"]:
		if p["id"] == id:
			return p
	return {}


static func active(r: Dictionary) -> Dictionary:
	var p := find(r, str(r.get("active", "")))
	if p.is_empty() and not r["profiles"].is_empty():
		p = r["profiles"][0]
		r["active"] = p["id"]
	return p


static func set_active(r: Dictionary, id: String) -> bool:
	if find(r, id).is_empty():
		return false
	r["active"] = id
	return true


## Removes a profile. The last child profile can't be removed (a device
## always has someone to play). Returns true when removed.
static func remove(r: Dictionary, id: String) -> bool:
	var p := find(r, id)
	if p.is_empty():
		return false
	if not p.get("guest", false) and children(r).size() <= 1:
		return false
	r["profiles"].erase(p)
	if r["active"] == id:
		r["active"] = children(r)[0]["id"]
	return true


static func rename(r: Dictionary, id: String, nickname: String) -> void:
	var p := find(r, id)
	if not p.is_empty() and not p.get("guest", false):
		var n := clean_name(nickname)
		if not n.is_empty():
			p["nickname"] = n


## Sets a child's picture to one of PICTURES. Guest can't be edited, and an
## unknown id changes nothing. Returns true when set.
static func set_picture(r: Dictionary, id: String, picture: String) -> bool:
	var p := find(r, id)
	if p.is_empty() or p.get("guest", false) or not PICTURES.has(picture):
		return false
	p["picture"] = picture
	return true


## The next picture in PICTURES for this profile.
static func next_picture(r: Dictionary, id: String) -> void:
	var p := find(r, id)
	if p.is_empty():
		return
	p["picture"] = PICTURES[(PICTURES.find(p["picture"]) + 1) % PICTURES.size()]


static func clean_name(s: String) -> String:
	var out := ""
	for c in s.strip_edges():
		if c.unicode_at(0) >= 32:
			out += c
	return out.left(NAME_MAX).strip_edges()


## The picker shows at launch only when two or more children share the device.
static func needs_picker(r: Dictionary) -> bool:
	return children(r).size() >= 2


# --- the parent PIN ------------------------------------------------------------

static func has_pin(r: Dictionary) -> bool:
	return r.get("pin") is Dictionary


static func valid_pin(pin: String) -> bool:
	return pin.length() == PIN_LEN and pin.is_valid_int() and not pin.contains("-") and not pin.contains("+")


static func set_pin(r: Dictionary, pin: String) -> bool:
	if not valid_pin(pin):
		return false
	var salt := Ids.hex(8)
	r["pin"] = {"salt": salt, "hash": Ids.sha256_hex(salt + pin)}
	return true


static func clear_pin(r: Dictionary) -> void:
	r["pin"] = null


## True when no PIN is set, or the PIN matches.
static func check_pin(r: Dictionary, pin: String) -> bool:
	if not has_pin(r):
		return true
	var p: Dictionary = r["pin"]
	return Ids.sha256_hex(str(p.get("salt", "")) + pin) == str(p.get("hash", ""))


# --- text ------------------------------------------------------------------------

static func to_text(r: Dictionary) -> String:
	return JSON.stringify(r, "\t", false)


## The roster from the file's text, or {} when the file is missing or broken
## (the store then makes one, moving an old save in).
static func from_text(text: String) -> Dictionary:
	var json := JSON.new()
	if text.is_empty() or json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var r: Dictionary = JsonUtil.normalize(json.data)
	if typeof(r.get("profiles")) != TYPE_ARRAY:
		return {}
	var kept := []
	for p in r["profiles"]:
		if p is Dictionary and Ids.is_profile_id(str(p.get("id", ""))):
			p["nickname"] = clean_name(str(p.get("nickname", "Player")))
			if not PICTURES.has(p.get("picture")):
				p["picture"] = DEFAULT_PICTURE
			p["guest"] = bool(p.get("guest", false))
			if typeof(p.get("created")) != TYPE_INT:
				p["created"] = 0
			if not p.has("child"):
				p["child"] = null
			kept.append(p)
	r["profiles"] = kept
	if children(r).is_empty():
		return {}
	r["schema"] = SCHEMA
	r["v"] = VERSION
	if not r.has("pin") or not (r["pin"] is Dictionary):
		r["pin"] = null
	if r.has("fresh") and not bool(r["fresh"]):
		r.erase("fresh")
	elif r.has("fresh"):
		r["fresh"] = true
	active(r)
	return r


# --- stats (the profile page, S3) ------------------------------------------------

## What the profile page shows for one child's save:
##   level:       the Level they play at (the menu's Level: the save's pick,
##                no higher than the highest Level open to them)
##   level_top:   the highest Level open to them
##   worlds_done: worlds beaten (boss and all) at that Level
##   worlds:      the worlds in a full pass (5)
##   stars:       every star earned (a crossing cleared without losing a heart)
##   currencies:  [{"id", "amount"}] for every open currency, in store order,
##                gems first
## worlds defaults to Content.worlds(); tests pass their own.
static func stats(save: Dictionary, worlds = null) -> Dictionary:
	var ws: Array = Content.worlds() if worlds == null else worlds
	var top := AreaFlow.level_reached(save, ws)
	var level := clampi(int(save.get("difficulty", 1)), 1, top)
	var done := 0
	for w in ws:
		if AreaFlow.world_beaten(save, String(w["id"]), level):
			done += 1
	var star_count := 0
	var stars = save.get("stars", {})
	if stars is Dictionary:
		for k in stars:
			if stars[k] is Array:
				star_count += stars[k].size()
	var money := []
	var cat := Store.catalog()
	for c in Store.open_currencies(cat):
		money.append({"id": c, "amount": Store.balance(save, c)})
	return {"level": level, "level_top": top, "worlds_done": done, "worlds": ws.size(),
			"stars": star_count, "currencies": money}
