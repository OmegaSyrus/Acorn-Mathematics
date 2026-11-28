## The add-on's own records on the device, pure (family.gd does the files):
##
## user://device_token.json  {"schema": "acorn.family_token", "v": 1, "dev", "token", "base", "at"}
##   The token from pairing. Never backed up, and only good for the device id
##   and server it was made for: a file copied to another tablet (which gets
##   a new device id) or a build pointed at another server reads as unpaired.
## user://family_state.json  (fresh() below lists every field)
##   Upload position, the parent's consent, the profile-to-child map, the
##   family's children, cached settings, snapshot revisions, minutes played.
extends RefCounted

const FamilyApi := preload("res://addons/acorn_family/family_api.gd")

const SCHEMA := "acorn.family_state"
const TOKEN_SCHEMA := "acorn.family_token"


static func fresh() -> Dictionary:
	return {
		"schema": SCHEMA, "v": 1,
		# the family this tablet is in (empty when unpaired)
		"family": "", "name": "",
		# a grown-up turned on "Send play records to the parent app"
		"consent": false,
		# the upload position (family_events.gd) and the batch on its way
		"sent": 0, "inflight": {}, "skipped": 0, "last_upload": 0,
		# the family's children [{child, nickname, picture}]
		"children": [],
		# local profile id -> child id, "new" (make one) or null (not linked)
		"map": {}, "map_dirty": false,
		# profiles to restore from the parent app's snapshots
		"restore": [],
		# child id -> last snapshot rev this device sent; profiles with a newer save
		"snap_rev": {}, "snap_dirty": [],
		# child id -> family.settings, kept for offline play
		"settings": {},
		# every Guest profile id seen (their lines never go)
		"guests": [],
		# minutes played (family_limits.gd) and grown-up passes {profile: until unix}
		"playtime": {"date": "", "secs": {}}, "passes": {},
	}


static func to_text(s: Dictionary) -> String:
	return JSON.stringify(s, "\t", false)


## The state from the file's text; anything missing or broken takes its
## default, so a bad file never stops the game.
static func from_text(text: String) -> Dictionary:
	var s := fresh()
	var d = _parse(text)
	if not (d is Dictionary):
		return s
	d = FamilyApi.normalize(d)
	for k in s:
		if d.has(k) and typeof(d[k]) == typeof(s[k]):
			s[k] = d[k]
	if typeof(d.get("sent")) == TYPE_INT:
		s["sent"] = maxi(0, int(d["sent"]))
	return s


## JSON text as data, or null (quietly: a broken file is only a fresh start).
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	if text == "" or json.parse(text) != OK:
		return null
	return json.data


# --- the token -------------------------------------------------------------------

static func token_text(token: String, dev: String, base: String, now: int) -> String:
	return JSON.stringify({"schema": TOKEN_SCHEMA, "v": 1, "dev": dev, "token": token, "base": base, "at": now}, "\t", false)


## The token in the file, or "" when there is none, or it was made for
## another device id or another server.
static func token_from_text(text: String, dev: String, base: String) -> String:
	var d = _parse(text)
	if not (d is Dictionary):
		return ""
	if str(d.get("dev", "")) != dev or str(d.get("base", "")).rstrip("/") != base.rstrip("/"):
		return ""
	return str(d.get("token", ""))


# --- pairing and being removed -----------------------------------------------------

## A grown-up approved the pairing (the poll's approved answer). Consent
## starts off: the pairing screen asks for it next.
static func adopt_approved(s: Dictionary, data: Dictionary) -> void:
	s["family"] = str(data.get("family", ""))
	s["name"] = str(data.get("name", ""))
	s["children"] = _children(data.get("children"))
	s["consent"] = false
	s["map"] = {}
	s["map_dirty"] = false
	s["restore"] = []
	s["snap_rev"] = {}
	s["snap_dirty"] = []
	s["settings"] = {}
	s["inflight"] = {}


## The token stopped working (410 gone, 401, 403) or a grown-up unlinked the
## tablet: back to unpaired. The upload position, Guest ids and minutes
## played stay (seq ranges are per device, so lines already stored are never
## sent again); the family's things go.
static func drop(s: Dictionary) -> void:
	var keep := {"sent": s.get("sent", 0), "skipped": s.get("skipped", 0), "guests": s.get("guests", []),
			"playtime": s.get("playtime", {"date": "", "secs": {}})}
	s.clear()
	s.merge(fresh())
	s.merge(keep, true)


static func _children(v: Variant) -> Array:
	var out := []
	if v is Array:
		for c in v:
			if c is Dictionary and FamilyApi.is_child_id(c.get("child")):
				out.append({"child": str(c["child"]), "nickname": str(c.get("nickname", "")),
						"picture": str(c.get("picture", "")) if c.get("picture") is String else ""})
	return out


# --- the profile-to-child map -------------------------------------------------------

## Local profile -> child id, "new" or null.
static func child_of(s: Dictionary, profile: String) -> Variant:
	var c = s["map"].get(profile)
	return c if c is String else null


## A grown-up picked who a profile is: a child id, "new" or null (not linked).
static func set_child(s: Dictionary, profile: String, child: Variant) -> void:
	if child is String and child != FamilyApi.NEW_CHILD and not FamilyApi.is_child_id(child):
		child = null
	s["map"][profile] = child
	s["map_dirty"] = true


static func has_child(s: Dictionary, child: String) -> bool:
	for c in s["children"]:
		if c["child"] == child:
			return true
	return false


static func child_name(s: Dictionary, child: String) -> String:
	for c in s["children"]:
		if c["child"] == child:
			return str(c["nickname"])
	return ""


## The PUT profiles items for the local roster ([{id, nickname, picture,
## guest}]): every child profile, with its pick. A Guest is never sent.
static func profile_items(s: Dictionary, roster: Array) -> Array:
	var out := []
	for p in roster:
		if bool(p.get("guest", false)):
			continue
		var id := str(p.get("id", ""))
		if not FamilyApi.is_id(id, FamilyApi.PROFILE):
			continue
		out.append({"profile": id, "child": child_of(s, id), "nickname": str(p.get("nickname", "")).left(24),
				"picture": str(p.get("picture", "")), "guest": false})
	return out


## The answer to GET or PUT profiles. rows_too: take the server's map for
## each profile (false while a newer local pick waits to be sent; "created"
## is always taken). Returns the profiles that now map to a child they did
## not map to before and that existed already: the ones to restore.
static func adopt_profiles(s: Dictionary, data: Dictionary, rows_too := true) -> Array:
	if data.get("children") is Array:
		s["children"] = _children(data["children"])
	var before: Dictionary = s["map"].duplicate()
	var made := {}
	if data.get("created") is Array:
		for c in data["created"]:
			if c is Dictionary and FamilyApi.is_child_id(c.get("child")):
				s["map"][str(c.get("profile", ""))] = str(c["child"])
				made[str(c.get("profile", ""))] = true
	if rows_too and data.get("profiles") is Array:
		for row in data["profiles"]:
			if not (row is Dictionary):
				continue
			var id := str(row.get("profile", ""))
			if made.has(id) or bool(row.get("guest", false)):
				continue
			s["map"][id] = str(row["child"]) if FamilyApi.is_child_id(row.get("child")) else null
	# a child removed on the web: its profiles are not linked any more
	for id in s["map"]:
		var c = s["map"][id]
		if FamilyApi.is_child_id(c) and not has_child(s, c) and rows_too:
			s["map"][id] = null
	var out := []
	for id in s["map"]:
		var c = s["map"][id]
		if FamilyApi.is_child_id(c) and before.get(id) != c and not made.has(id):
			out.append(id)
	return out


## Child ids this tablet's profiles map to.
static func mapped_children(s: Dictionary) -> Array:
	var out := []
	for id in s["map"]:
		var c = s["map"][id]
		if FamilyApi.is_child_id(c) and not out.has(c):
			out.append(c)
	return out


static func note_guests(s: Dictionary, roster: Array) -> void:
	for p in roster:
		if bool(p.get("guest", false)) and not s["guests"].has(str(p.get("id", ""))):
			s["guests"].append(str(p.get("id", "")))
