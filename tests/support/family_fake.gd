## A stand-in for the /v1 API (docs/contract/api-v1.md), in memory, for the
## family add-on's tests: it answers at once (so a whole sync runs inside one
## test call) and checks what it is sent against the contract's schemas, the
## way the backend does. tools/family_mock/server.py is the same idea over HTTP.
extends RefCounted

const SchemaCheck := preload("res://tests/support/schema_check.gd")
const JsonUtil := preload("res://logic/core/json_util.gd")

const C := "res://docs/contract/"

## Every call: {method, path, headers, body (text), json}.
var calls := []
## Answer every call with this status (0 = offline) when set.
var fail_with := -1
## Answer only paths containing this with fail_with.
var fail_path := ""
var removed := false
var token := "dt_fake_token"
var dev := ""
var pair_state := "approved"
var children := [{"child": "c_9b2f00e1a7c4", "nickname": "Bear", "picture": "fox"}]
## dev/profile -> child or null
var profiles := {}
## "first-last" -> lines (texts)
var batches := {}
## child -> {dev -> snapshot}
var snapshots := {}
## child -> family.settings
var settings := {}
var _event_schema: Dictionary
var _snapshot_schema: Dictionary
var _made := 0


func _init() -> void:
	_event_schema = JsonUtil.load_file(C + "schemas/event.v2.schema.json")
	_snapshot_schema = JsonUtil.load_file(C + "schemas/snapshot.v1.schema.json")


func calls_to(part: String, method := "") -> Array:
	var out := []
	for c in calls:
		if c["path"].contains(part) and (method == "" or c["method"] == method):
			out.append(c)
	return out


func stored_seqs() -> Array:
	var out := []
	for k in batches:
		for l in batches[k]:
			out.append(int(JSON.parse_string(l)["seq"]))
	out.sort()
	return out


func send(method: String, url: String, headers: PackedStringArray, body := PackedByteArray()) -> Dictionary:
	var path := url.substr(url.find("/v1/") + 3) if url.contains("/v1/") else url
	var gz := false
	var is_json := false
	for h in headers:
		if h.to_lower().begins_with("content-encoding:") and h.to_lower().contains("gzip"):
			gz = true
		if h.to_lower() == "content-type: application/json":
			is_json = true
	var text := (body.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP) if gz else body).get_string_from_utf8()
	var json = null
	var parser := JSON.new()
	if is_json and parser.parse(text) == OK:
		json = parser.data
	calls.append({"method": method, "path": path, "headers": headers, "body": text,
			"json": JsonUtil.normalize(json) if json != null else null})
	if fail_with >= 0 and (fail_path == "" or path.contains(fail_path)):
		return _answer(fail_with, {"error": "internal"} if fail_with > 0 else {})
	var authed := false
	for h in headers:
		if h == "Authorization: Device " + token:
			authed = true
	var seg := path.split("?")[0].split("/", false)
	if seg.size() >= 2 and seg[0] == "devices" and seg[1] == "pair":
		return _pair(seg[2], path)
	if not authed:
		return _answer(401, {"error": "unauthorized"})
	if removed:
		return _answer(410, {"error": "gone"})
	if seg[0] == "devices" and seg[2] == "profiles":
		if seg[1] != dev:
			return _answer(403, {"error": "forbidden"})
		return _profiles(method, json)
	if seg[0] == "events":
		return _events(seg, text)
	if seg[0] == "children" and seg.size() >= 5:
		var child := seg[1]
		if not _has_child(child):
			return _answer(404, {"error": "not_found"})
		if seg[4] == "snapshots" and method == "GET":
			var list := []
			for d in snapshots.get(child, {}):
				list.append(snapshots[child][d])
			return _answer(200, {"child": child, "game": seg[3], "snapshots": list})
		if seg[4] == "snapshots" and method == "PUT":
			return _put_snapshot(child, seg[5], JsonUtil.normalize(json))
		if seg[4] == "settings":
			return _answer(200, settings.get(child, {"schema": "family.settings", "v": 1, "child": child, "game": seg[3], "rev": 0, "fields": {}}))
	return _answer(404, {"error": "not_found"})


func _answer(status: int, data: Dictionary) -> Dictionary:
	return {"status": status, "body": JSON.stringify(data).to_utf8_buffer() if status > 0 else PackedByteArray()}


func _has_child(c: String) -> bool:
	for k in children:
		if k["child"] == c:
			return true
	return false


func _pair(what: String, path: String) -> Dictionary:
	if what == "start":
		return _answer(201, {"pair_id": "pr_" + "0".repeat(32), "code": "K7Q-42M", "qr_url": null, "expires_in": 600})
	if pair_state == "approved":
		return _answer(200, {"state": "approved", "device_token": token, "family": "8a1f2c3e-0000-4000-8000-00000000f00d",
				"dev": dev, "name": "Kitchen tablet", "children": children})
	return _answer(200, {"state": pair_state, "expires_in": 500})


func _profiles(method: String, json: Variant) -> Dictionary:
	var created := []
	if method == "PUT":
		for p in json["profiles"]:
			var child = p.get("child")
			if bool(p.get("guest", false)):
				child = null
			if child is String and child == "new":
				var had = profiles.get(p["profile"])
				if had is String and _has_child(had):
					child = had
				else:
					if children.size() >= 12:
						return _answer(409, {"error": "conflict", "reason": "children_limit", "profile": p["profile"]})
					_made += 1
					child = "c_%012x" % (0xbeef00 + _made)
					children.append({"child": child, "nickname": p["nickname"], "picture": p.get("picture", "fox")})
					created.append({"profile": p["profile"], "child": child})
			if child is String and not _has_child(child):
				return _answer(400, {"error": "bad_request", "detail": "child %s is not in this family" % child})
			profiles[p["profile"]] = child
	var rows := []
	for id in profiles:
		rows.append({"profile": id, "child": profiles[id], "nickname": "", "picture": "", "guest": false})
	var out := {"profiles": rows, "children": children}
	if method == "PUT":
		out["created"] = created
	return _answer(200, out)


func _events(seg: Array, text: String) -> Dictionary:
	var r: Array = seg[3].split("-")
	var first := int(r[0])
	var last := int(r[1])
	if batches.has(seg[3]):
		return _answer(200, {"stored": false, "duplicate": true, "lines": batches[seg[3]].size()})
	var lines := []
	for l in text.split("\n", false):
		var e = JsonUtil.normalize(JSON.parse_string(l))
		if not (e is Dictionary):
			return _answer(400, {"error": "bad_request", "detail": "line is not JSON"})
		if int(e.get("v", 0)) == 2 and not SchemaCheck.errors(e, _event_schema).is_empty():
			return _answer(400, {"error": "bad_request", "detail": "schema: " + "; ".join(SchemaCheck.errors(e, _event_schema))})
		if int(e["seq"]) < first or int(e["seq"]) > last or str(e.get("dev", dev)) != dev:
			return _answer(400, {"error": "bad_request", "detail": "seq outside the range"})
		lines.append(l)
	batches[seg[3]] = lines
	return _answer(201, {"stored": true, "lines": lines.size(), "children": [], "unmapped_profiles": []})


func _put_snapshot(child: String, d: String, snap: Dictionary) -> Dictionary:
	var errs := SchemaCheck.errors(snap, _snapshot_schema)
	if not errs.is_empty():
		return _answer(400, {"error": "bad_request", "detail": "; ".join(errs)})
	if not snapshots.has(child):
		snapshots[child] = {}
	var cur = snapshots[child].get(d)
	if cur is Dictionary and int(snap["rev"]) <= int(cur["rev"]):
		return _answer(409, {"error": "conflict", "detail": "an equal or newer snapshot is stored", "stored_rev": int(cur["rev"])})
	snap["child"] = child
	snapshots[child][d] = snap
	return _answer(200, {"stored": true, "rev": snap["rev"]})
