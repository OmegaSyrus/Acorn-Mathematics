## Who plays on this device (family.profiles v1, docs/contract): the
## "Who is playing?" roster and the parent PIN. Pure: game/profile_store.gd
## does the file IO.
##
## Each profile has a random id (p_ + 12 hex), a nickname, a picture from the
## hero art, and guest true or false. A Guest plays and saves on the device
## but never syncs (docs/contract/api-v1.md). The PIN is kept as a salted
## sha256 and never leaves the device.
extends RefCounted

const Ids := preload("res://logic/core/ids.gd")
const JsonUtil := preload("res://logic/core/json_util.gd")

const SCHEMA := "family.profiles"
const VERSION := 1
const MAX_PROFILES := 6
const NAME_MAX := 12
const PIN_LEN := 4
## Profile pictures: art/heroes/<id>.png, friendliest first.
const PICTURES := ["fox", "bunny", "hedgehog", "turtle", "lion", "eagle", "phoenix", "gryphon",
		"elf_mage", "templar", "slime_knight"]
const GUEST_NAME := "Guest"
const GUEST_PICTURE := "slime_knight"


static func new_roster(now: int) -> Dictionary:
	var r := {"schema": SCHEMA, "v": VERSION, "active": "", "profiles": [], "pin": null}
	var p := add(r, "Player 1", PICTURES[0], now)
	r["active"] = p["id"]
	return r


## Adds a profile (not past MAX_PROFILES children plus one Guest) and returns
## it, or {} when full.
static func add(r: Dictionary, nickname: String, picture: String, now: int, guest := false) -> Dictionary:
	if guest and not guest_profile(r).is_empty():
		return guest_profile(r)
	if not guest and children(r).size() >= MAX_PROFILES:
		return {}
	var p := {"id": Ids.profile_id(), "nickname": clean_name(nickname), "picture": picture if PICTURES.has(picture) else PICTURES[0],
			"guest": guest, "created": now, "child": null}
	r["profiles"].append(p)
	return p


## A new child profile with the next free picture and "Player N".
static func add_child(r: Dictionary, now: int) -> Dictionary:
	var used := []
	for p in r["profiles"]:
		used.append(p["picture"])
	var pic: String = PICTURES[0]
	for c in PICTURES:
		if not used.has(c):
			pic = c
			break
	return add(r, "Player %d" % (children(r).size() + 1), pic, now)


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
				p["picture"] = PICTURES[0]
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
	active(r)
	return r
