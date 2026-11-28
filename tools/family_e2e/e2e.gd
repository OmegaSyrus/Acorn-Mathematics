## The family add-on end to end over real HTTP: pair, link a profile as a
## new child, upload play log lines (a Guest's stay home), back up a save
## (and get past a 409), fetch settings, restore. Headless, its own files in
## a temp folder and a fresh random device id each run.
##
##   python3 -I tools/family_mock/server.py &            # or use staging
##   ACORN_FAMILY_URL=http://127.0.0.1:8787/v1 \
##     godot --headless --path . --script tools/family_e2e/e2e.gd
##
## Environment:
##   ACORN_FAMILY_URL        the /v1 base (default the mock: http://127.0.0.1:8787/v1)
##   ACORN_E2E_APPROVE_CMD   a shell command run once the code shows, with {code}
##                           replaced by it (for example a curl that approves it with a
##                           parent's token). Without it the script prints the code
##                           and polls until a grown-up approves it in the parent app.
##   ACORN_E2E_TIMEOUT       seconds to wait for approval (default 600)
##   ACORN_E2E_KEEP=1        leave the tablet paired at the end (default: against the
##                           mock it removes the tablet and checks the 410 "gone" path)
## Exit code 0 when every step passed.
extends SceneTree

const BuildInfo := preload("res://logic/core/build_info.gd")
const Family := preload("res://addons/acorn_family/family.gd")
const FamilyPairing := preload("res://addons/acorn_family/family_pairing.gd")
const FamilyApi := preload("res://addons/acorn_family/family_api.gd")
const FamilyHttp := preload("res://addons/acorn_family/family_http.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const PlayLog := preload("res://game/play_log.gd")
const Ids := preload("res://logic/core/ids.gd")

const DEFAULT_URL := "http://127.0.0.1:8787/v1"


## Logs every call and answer, then hands it to the real transport.
class Recorder extends Node:
	var http: Node
	var log := []

	func send(method: String, url: String, headers: PackedStringArray, body := PackedByteArray()) -> Dictionary:
		var r: Dictionary = await http.send(method, url, headers, body)
		var path := url.substr(url.rfind("/v1/") + 3) if url.contains("/v1/") else url
		var text: String = r["body"].get_string_from_utf8()
		log.append({"method": method, "path": path, "status": r["status"], "body": text})
		print("    %s %s -> %d %s" % [method, path, r["status"], text.left(160)])
		return r


var fam: Node
var rec: Recorder
var dir := ""
var dev := ""
var kid := ""
var guest := ""
var saves := {}
var failed := []
var passed := []


func _initialize() -> void:
	_run.call_deferred()


func _step(ok: bool, what: String) -> bool:
	if ok:
		passed.append(what)
		print("ok    " + what)
	else:
		failed.append(what)
		print("FAIL  " + what)
	return ok


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _run() -> void:
	var base := OS.get_environment("ACORN_FAMILY_URL").strip_edges().rstrip("/")
	if base == "":
		base = DEFAULT_URL
	dev = Ids.device_id()
	kid = Ids.profile_id()
	guest = Ids.profile_id()
	SaveData.device = dev
	dir = OS.get_temp_dir().path_join("acorn_family_e2e_" + dev)
	DirAccess.make_dir_recursive_absolute(dir)
	PlayLog.path = dir.path_join("play_log.jsonl")
	PlayLog.dev = dev
	PlayLog.boot = 1
	PlayLog.seq = 0
	print("family e2e against %s\n  device %s, files in %s" % [base, dev, dir])

	rec = Recorder.new()
	rec.http = FamilyHttp.new()
	rec.add_child(rec.http)
	root.add_child(rec)
	fam = Family.new()
	fam.base_url = base
	fam.transport = rec
	root.add_child(fam)
	fam.configure(_hooks(), dir)

	var h: Dictionary = await fam._request({"method": "GET", "path": "/health"}, PackedByteArray(), [], false)
	if not _step(h["kind"] == "ok", "health"):
		return _finish()
	var is_mock := bool(h["data"].get("mock", false))

	# 1. pairing ------------------------------------------------------------------
	await fam.start_pairing()
	if not _step(fam.pairing.state == FamilyPairing.State.WAITING, "pair/start gives a code"):
		return _finish()
	print("\n  PAIRING CODE:  %s\n  %s\n" % [fam.pairing.code, fam.pairing.qr_url])
	var cmd := OS.get_environment("ACORN_E2E_APPROVE_CMD")
	if cmd != "":
		var out := []
		var code: int = OS.execute("sh", ["-c", cmd.replace("{code}", fam.pairing.code)], out, true)
		print("  approve hook exited %d: %s" % [code, "".join(out).strip_edges().left(300)])
	else:
		print("  Approve it in the parent app (Add a tablet). Polling...")
	var limit := float(OS.get_environment("ACORN_E2E_TIMEOUT")) if OS.get_environment("ACORN_E2E_TIMEOUT").is_valid_float() else 600.0
	var waited := 0.0
	while not fam.is_paired() and fam.pairing.state == FamilyPairing.State.WAITING and waited < limit:
		await _wait(0.25)
		waited += 0.25
	if not _step(fam.is_paired(), "approved, token kept (%s)" % fam.device_name()):
		return _finish()
	# from here the script drives each sync itself
	fam.set_process(false)
	print("  family children: %s" % JSON.stringify(fam.children()))

	# 2. who is who: the profile becomes a new child ------------------------------------
	fam.set_child(kid, "new")
	await _sync()
	var child = fam.child_of(kid)
	if not _step(FamilyApi.is_child_id(child), "PUT profiles with \"child\": \"new\" made child %s" % child):
		return _finish()
	_step(not fam.state["map_dirty"], "map sent")

	# 3. play log lines, with consent ---------------------------------------------------
	fam.set_consent(true)
	PlayLog.set_profile(kid)
	PlayLog.set_place({"id": "lava_scroll", "world": "lava_caves"}, 1, 1)
	PlayLog.event("run_start")
	PlayLog.answer("stone", PlayLog.stone_shown({"op": "add", "dice": [3, 2], "choices": [3, 4, 5, 6]}), 5, 5, 2.1)
	PlayLog.answer("stone", PlayLog.stone_shown({"op": "add", "dice": [4, 2], "choices": [5, 6, 7]}), 6, 5, 3.4)
	PlayLog.event("heart_lost", {"where": "stone", "hearts_left": 2})
	PlayLog.set_profile(guest)
	PlayLog.event("profile_picked", {"guest": true})
	PlayLog.event("run_start")
	PlayLog.set_profile(kid)
	PlayLog.event("level_cleared")
	var before: int = rec.log.size()
	await _sync()
	var puts := _calls_since(before, "/events/")
	_step(puts.size() >= 1 and puts.all(func(c): return c["status"] == 201 or c["status"] == 200),
			"PUT events stored (%d batch)" % puts.size())
	_step(int(fam.state["sent"]) == PlayLog.seq and fam.state["inflight"].is_empty(), "upload position at seq %d" % PlayLog.seq)
	for c in puts:
		_step(c["path"].ends_with("/1-%d" % PlayLog.seq), "range named {first}-{last}: " + c["path"].get_file())

	# 4. snapshot, then a 409 ------------------------------------------------------------
	var s := SaveData.new_profile(kid)
	SaveData.add_mark(s, "lava_caves", 1)
	SaveData.add_gems(s, 7)
	saves[kid] = s
	fam.save_written(kid)
	before = rec.log.size()
	await _sync()
	var snap_puts := _calls_since(before, "/snapshots/")
	_step(snap_puts.size() >= 1 and snap_puts[-1]["status"] == 200, "PUT snapshot stored (rev %s)" % str(fam.state["snap_rev"].get(child)))
	fam.state["snap_rev"][child] = 0
	fam.save_written(kid)
	before = rec.log.size()
	await _sync()
	snap_puts = _calls_since(before, "/snapshots/")
	_step(snap_puts.size() == 2 and snap_puts[0]["status"] == 409 and snap_puts[1]["status"] == 200,
			"a stale rev hears 409 stored_rev and goes past it (rev %s)" % str(fam.state["snap_rev"].get(child)))

	# 5. settings: set them as the device may (PATCH), then fetch ------------------------
	var patch: Dictionary = await fam._request({"method": "PATCH", "path": "/children/%s/games/acorn-math/settings" % child,
			"json": {"fields": {"daily_minutes": {"value": 30}, "bedtime": {"value": "19:30"}}}})
	if patch["status"] == 422:
		print("  note: PATCH settings answered 422 (%s): the latest published manifest has no such settings yet"
				% str(patch["data"].get("detail", "")))
	fam.settings_at = -INF
	before = rec.log.size()
	await _sync()
	var got := _calls_since(before, "/settings")
	_step(got.size() == 1 and got[0]["status"] == 200, "GET settings")
	if patch["status"] == 200:
		_step(fam.limits_for(kid) == {"daily_minutes": 30, "bedtime": "19:30"}, "settings parsed: 30 minutes, bedtime 19:30")
	print("  limits for the child: %s (stop now: \"%s\")" % [JSON.stringify(fam.limits_for(kid)), fam.stop_reason(kid)])

	# 6. restore -----------------------------------------------------------------------------
	saves[kid] = SaveData.new_profile(kid)
	fam.restore_all()
	await _sync()
	_step(SaveData.has_mark(saves[kid], "lava_caves", 1) and int(saves[kid]["gems"]) == 7,
			"restore merged the backed-up save back in")

	# 7. removed ------------------------------------------------------------------------------
	if is_mock and OS.get_environment("ACORN_E2E_KEEP") != "1":
		await fam._request({"method": "DELETE", "path": "/devices/" + dev}, PackedByteArray(), [], false)
		PlayLog.event("run_start")
		await _sync()
		_step(not fam.is_paired() and not FileAccess.file_exists(dir.path_join("device_token.json")),
				"410 gone: token dropped, the tablet plays on unpaired")
	_finish()


## One sync, after any the add-on started by itself has finished.
func _sync() -> void:
	while fam.busy:
		await _wait(0.1)
	await fam.sync_once()


func _calls_since(i: int, part: String) -> Array:
	var out := []
	for c in rec.log.slice(i):
		if c["path"].contains(part):
			out.append(c)
	return out


func _finish() -> void:
	print("\n%d steps passed, %d failed%s" % [passed.size(), failed.size(), "" if failed.is_empty() else ": " + ", ".join(failed)])
	print("device %s; files kept in %s" % [dev, dir])
	quit(0 if failed.is_empty() else 1)


# --- the game's hooks, for one made-up child and a Guest ----------------------------------

func _hooks() -> Dictionary:
	return {"game": "acorn-math", "dev": dev, "app": BuildInfo.APP, "code": BuildInfo.CODE, "roster": _roster,
			"active_profile": _active, "read_save": _read_save, "write_save": _write_save, "snapshot": _snapshot,
			"merge": _merge, "saved_at": _saved_at, "log_files": _log_files, "last_seq": _last_seq,
			"keep_log_after": _keep_log_after}


func _roster() -> Array:
	return [{"id": kid, "nickname": "E2E Kid", "picture": "fox", "guest": false},
			{"id": guest, "nickname": "Guest", "picture": "slime_knight", "guest": true}]


func _active() -> String:
	return kid


func _read_save(p: String) -> Dictionary:
	return saves.get(p, SaveData.new_profile(p)).duplicate(true)


func _write_save(p: String, s: Dictionary) -> void:
	saves[p] = s


func _snapshot(s: Dictionary, d: String, rev: int, now: int, child: Variant) -> Dictionary:
	return SaveData.snapshot(s, d, rev, now, child)


func _merge(snaps: Array, p: String, local: Dictionary) -> Dictionary:
	return SaveData.merge(snaps, p, local.get("run"))


func _saved_at(_p: String) -> int:
	return 0


func _log_files() -> Array:
	return PlayLog.log_files(PlayLog.path)


func _last_seq() -> int:
	return PlayLog.seq


func _keep_log_after(n: int) -> void:
	PlayLog.keep_after = n
