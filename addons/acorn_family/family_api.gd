## The /v1 calls a device makes (docs/contract/api-v1.md), as plain data:
## each builder returns {method, path, json?}. Pure, so tests read them
## without a network. family.gd sends them through its transport.
extends RefCounted

const DEV := "^d_[0-9a-f]{16}$"
const PROFILE := "^p_[0-9a-f]{12}$"
const CHILD := "^c_[0-9a-f]{12}$"
## "child": "new" in PUT profiles (api-v1 pairing step 5).
const NEW_CHILD := "new"


static func pair_start(game: String, dev: String, app: String, code: int) -> Dictionary:
	return {"method": "POST", "path": "/devices/pair/start", "json": {"game": game, "dev": dev, "app": app, "code": code}}


static func pair_poll(pair_id: String) -> Dictionary:
	return {"method": "GET", "path": "/devices/pair/poll?pair_id=" + pair_id.uri_encode()}


static func get_profiles(dev: String) -> Dictionary:
	return {"method": "GET", "path": "/devices/%s/profiles" % dev}


## items: [{profile, child (id, "new" or null), nickname, picture, guest}]
static func put_profiles(dev: String, items: Array) -> Dictionary:
	return {"method": "PUT", "path": "/devices/%s/profiles" % dev, "json": {"profiles": items}}


## The batch's name in the path: "{first_seq}-{last_seq}".
static func range_name(first: int, last: int) -> String:
	return "%d-%d" % [first, last]


static func put_events(game: String, dev: String, first: int, last: int) -> Dictionary:
	return {"method": "PUT", "path": "/events/%s/%s/%s" % [game, dev, range_name(first, last)]}


static func get_snapshots(child: String, game: String) -> Dictionary:
	return {"method": "GET", "path": "/children/%s/games/%s/snapshots" % [child, game]}


static func put_snapshot(child: String, game: String, dev: String, snapshot: Dictionary) -> Dictionary:
	return {"method": "PUT", "path": "/children/%s/games/%s/snapshots/%s" % [child, game, dev], "json": snapshot}


static func get_settings(child: String, game: String) -> Dictionary:
	return {"method": "GET", "path": "/children/%s/games/%s/settings" % [child, game]}


# --- answers -------------------------------------------------------------------

## What an answer means for a device call:
##   "ok"       2xx
##   "gone"     401, 403 or 410: the token no longer works here (removed, unknown,
##              or another device's); the game drops it and plays on unpaired
##   "conflict" 409 (a snapshot's stored_rev, the children limit)
##   "bad"      400, 413, 422: this request will never pass as it is
##   "missing"  404
##   "retry"    no answer (offline, timeout), 429 or 5xx: try again later
static func classify(status: int) -> String:
	if status >= 200 and status < 300:
		return "ok"
	match status:
		401, 403, 410:
			return "gone"
		409:
			return "conflict"
		400, 413, 422:
			return "bad"
		404:
			return "missing"
	return "retry"


static func is_id(s: Variant, pattern: String) -> bool:
	if not (s is String):
		return false
	var re := RegEx.new()
	re.compile(pattern)
	return re.search(s) != null


static func is_child_id(s: Variant) -> bool:
	return is_id(s, CHILD)


## Godot reads every JSON number as a float; whole ones come back as ints.
static func normalize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			if v == floorf(v) and absf(v) < 9.0e15:
				return int(v)
			return v
		TYPE_ARRAY:
			var out := []
			for x in v:
				out.append(normalize(x))
			return out
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = normalize(v[k])
			return d
	return v


## An answer body as data: a Dictionary (or {} when it is not JSON).
static func parse_body(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return normalize(json.data)
