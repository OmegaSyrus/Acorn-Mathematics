## The family sync add-on (autoload "Family"): pairs this tablet with a
## parent's family, says which local profile is which child, uploads the
## play log, backs saves up as snapshots and restores them, and fetches the
## parent's settings (time a day, bedtime). Only the /v1 API
## (docs/contract/api-v1.md) is called.
##
## It does nothing until the game calls configure() with its hooks, and
## nothing on the network until a grown-up pairs the tablet. Every call is
## asynchronous and every failure is quiet: offline, unpaired or removed,
## the game plays on exactly as before. What a grown-up may want to know
## goes in `message` for the PIN-guarded Family screen; a child never sees it.
##
## The game's hooks (configure(adapter)):
##   game, dev, app, code        ids for the calls and snapshots
##   roster: () -> [{id, nickname, picture, guest}]
##   active_profile: () -> String      who plays now (minutes are counted for them)
##   read_save: (profile) -> Dictionary
##   write_save: (profile, Dictionary)  (a restore writes the merged save)
##   snapshot: (save, dev, rev, now, child) -> family.snapshot Dictionary
##   merge: (snapshots: Array, profile, local_save) -> merged save
##   saved_at: (profile) -> int        unix time of the local save (0 if it is new)
##   log_files: () -> [path]           play log files, oldest first
##   last_seq: () -> int               the last seq written (cheap "anything new?")
##   keep_log_after: (int)             the play log keeps lines after this seq (-1: none)
## The pure parts are in family_*.gd beside this file, and tests drive them.
extends Node

## Something a screen shows changed (pairing, map, consent, a message).
signal changed

const FamilyConfig := preload("res://addons/acorn_family/family_config.gd")
const FamilyApi := preload("res://addons/acorn_family/family_api.gd")
const FamilyState := preload("res://addons/acorn_family/family_state.gd")
const FamilyPairing := preload("res://addons/acorn_family/family_pairing.gd")
const FamilyEvents := preload("res://addons/acorn_family/family_events.gd")
const FamilyLimits := preload("res://addons/acorn_family/family_limits.gd")
const FamilyHttp := preload("res://addons/acorn_family/family_http.gd")

## A sync every 5 minutes while the app is open, sooner after a run ends.
const SYNC_EVERY := 300.0
const SETTINGS_EVERY := 1800.0
## Snapshots go this long after the last save write, or at most this long
## after the first one.
const SNAP_DEBOUNCE := 15.0
const SNAP_MAX_WAIT := 120.0
## After a failed sync: 30 s, 1, 2, 4 ... minutes, up to 30.
const RETRY_BASE := 30.0
const RETRY_MAX := 1800.0
const MAX_BATCHES := 20
const SAVE_PLAY_EVERY := 60.0

var adapter := {}
var game := ""
var dev := ""
var app := ""
var code := 0
## Where the token and state files live (tests and the e2e script use a temp folder).
var dir := "user://"
var base_url := ""
## Anything with send(method, url, headers, body) -> {status, body}; family_http.gd by default.
var transport: Object = null
var state := FamilyState.fresh()
var token := ""
var pairing := FamilyPairing.new()
var configured := false
var busy := false
var failures := 0
var next_sync_at := 0.0
var settings_at := -INF
var want_profiles := true
var gzip_ok := true
## The last thing worth telling a grown-up (Family screen only).
var message := ""
## The game turns this off on screens that are not play (Grown-ups, rest).
var counting := true
## Seconds since configure(), advanced by _process (tests move it by hand).
var clock := 0.0
## -> {date: "YYYY-MM-DD", minute: minutes after local midnight, second, unix}. Tests set it.
var local_time := Callable()
var snap_due := -1.0
var snap_first := -1.0
var _paused := false
var _play_unsaved := 0.0
var _map_gen := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Starts the add-on with the game's hooks. Reads the token and state; the
## first sync follows a moment later (only when paired).
func configure(hooks: Dictionary, files_dir := "user://") -> void:
	adapter = hooks
	game = str(hooks.get("game", ""))
	dev = str(hooks.get("dev", ""))
	app = str(hooks.get("app", ""))
	code = int(hooks.get("code", 0))
	dir = files_dir
	if base_url == "":
		base_url = FamilyConfig.base_url()
	if transport == null:
		var h := FamilyHttp.new()
		add_child(h)
		transport = h
	_load()
	configured = true
	FamilyState.note_guests(state, _roster())
	_keep_log()
	next_sync_at = clock + 2.0
	changed.emit()


# --- what the game and its Family screen call --------------------------------------

func is_paired() -> bool:
	return token != ""


func device_name() -> String:
	return str(state.get("name", ""))


func children() -> Array:
	return state.get("children", [])


func consent() -> bool:
	return bool(state.get("consent", false))


## "Send play records to the parent app" on the Family screen. Turning it on
## backs up every linked profile's save too.
func set_consent(on: bool) -> void:
	state["consent"] = on
	if on:
		for p in _roster():
			save_written(str(p.get("id", "")))
		poke()
	_save_state()
	changed.emit()


## A profile's child id, "new" or null.
func child_of(profile: String) -> Variant:
	return FamilyState.child_of(state, profile)


## A grown-up picked who a profile is: a child id, "new" (make one) or null.
func set_child(profile: String, child: Variant) -> void:
	var before = child_of(profile)
	FamilyState.set_child(state, profile, child)
	# linked to a child who may have played on other tablets: restore after the PUT
	var now_child = child_of(profile)
	if FamilyApi.is_child_id(now_child) and now_child != before and not state["restore"].has(profile):
		state["restore"].append(profile)
	_map_gen += 1
	_save_state()
	sync_soon()
	changed.emit()


## A player was made, renamed or given a new picture: the parent app's list
## of players is sent again at the next sync.
func profiles_changed() -> void:
	if is_paired():
		state["map_dirty"] = true
		_map_gen += 1
		sync_soon()


func start_pairing() -> void:
	if pairing.state == FamilyPairing.State.STARTING or is_paired():
		return
	pairing.begin()
	message = ""
	changed.emit()
	var r: Dictionary = await _request(FamilyApi.pair_start(game, dev, app, code), PackedByteArray(), [], false)
	if pairing.state != FamilyPairing.State.STARTING:
		return
	pairing.started(int(r["status"]), r["data"], clock)
	changed.emit()


func cancel_pairing() -> void:
	pairing.cancel()
	changed.emit()


## "Unlink this tablet": forgets the pairing here. The parent app still lists
## the tablet until a grown-up removes it there.
func unlink() -> void:
	_forget()
	message = "Unlinked. The parent app still lists this tablet until a grown-up removes it there."
	changed.emit()


## "Restore from parent app": every linked profile merges in the snapshots
## from the family's other tablets.
func restore_all() -> void:
	for id in state["map"]:
		if FamilyApi.is_child_id(state["map"][id]) and not state["restore"].has(id):
			state["restore"].append(id)
	_save_state()
	sync_now()


## A run or level ended: upload soon (unless the network is in a backoff).
func poke() -> void:
	if failures == 0:
		next_sync_at = minf(next_sync_at, clock + 1.0)


## Sync as soon as possible, backoff or not (a grown-up pressed something).
func sync_now() -> void:
	failures = 0
	next_sync_at = clock


func sync_soon() -> void:
	failures = 0
	next_sync_at = minf(next_sync_at, clock + 0.5)


## The game wrote a profile's save: its snapshot goes after a short wait.
func save_written(profile: String) -> void:
	if is_paired():
		FamilyState.note_guests(state, _roster())
	if not is_paired() or not FamilyApi.is_child_id(child_of(profile)) or state["guests"].has(profile):
		return
	if not state["snap_dirty"].has(profile):
		state["snap_dirty"].append(profile)
	if snap_first < 0.0:
		snap_first = clock
	snap_due = minf(clock + SNAP_DEBOUNCE, snap_first + SNAP_MAX_WAIT)


## Play log lines not sent yet (Guest lines included in the count).
func waiting_lines() -> int:
	return maxi(0, _last_seq() - int(state["sent"]))


## One line for the Family screen.
func status_line() -> String:
	if not is_paired():
		return ""
	if not consent():
		return "Sending is off. Nothing leaves this tablet but who is who."
	var n := waiting_lines()
	if n == 0:
		return "Everything is sent."
	if failures > 0:
		return "%d play records waiting (no internet right now)." % n
	return "%d play records waiting to be sent." % n


# --- time limits -------------------------------------------------------------------

## The parent's limits for a profile ({daily_minutes, bedtime}), from the
## cached settings of the child it is linked to. None when not linked.
func limits_for(profile: String) -> Dictionary:
	var child = child_of(profile)
	if not is_paired() or not FamilyApi.is_child_id(child):
		return FamilyLimits.NO_LIMITS.duplicate()
	return FamilyLimits.parse_settings(state["settings"].get(child))


## "bedtime", "daily" or "" (play on) for this profile right now.
func stop_reason(profile: String) -> String:
	var limits := limits_for(profile)
	var t := now_local()
	var passed := int(state["passes"].get(profile, 0)) > int(t["unix"])
	return FamilyLimits.stop_reason(limits, minutes_played_secs(profile), int(t["minute"]), passed)


func minutes_played_secs(profile: String) -> float:
	return FamilyLimits.used(state["playtime"], str(now_local()["date"]), profile)


## A grown-up let this profile play on (the PIN on the rest screen), until
## the next morning.
func grant_pass(profile: String) -> void:
	var t := now_local()
	state["passes"][profile] = FamilyLimits.pass_until(int(t["unix"]), int(t["minute"]), int(t.get("second", 0)))
	_save_state()


func now_local() -> Dictionary:
	if local_time.is_valid():
		return local_time.call()
	var dt := Time.get_datetime_dict_from_system()
	return {"date": FamilyLimits.date_of(dt), "minute": int(dt["hour"]) * 60 + int(dt["minute"]),
			"second": int(dt["second"]), "unix": int(Time.get_unix_time_from_system())}


# --- the loop ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not configured:
		return
	clock += delta
	if not _paused:
		_count(delta)
	if pairing.due(clock):
		_poll_pairing()
	if is_paired() and not busy:
		if clock >= next_sync_at or (snap_due >= 0.0 and clock >= snap_due and failures == 0 and consent()):
			sync_once()


func _notification(what: int) -> void:
	if not configured:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not _paused:
				_paused = true
				_save_state()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _paused:
				_paused = false
				on_resume()


## Back from the background: profiles and settings again, and a sync now.
func on_resume() -> void:
	want_profiles = true
	settings_at = -INF
	sync_now()


static func retry_delay(n: int) -> float:
	return minf(RETRY_MAX, RETRY_BASE * pow(2.0, maxi(0, n - 1)))


## One sync: the profile map, restores, settings, then (with consent)
## snapshots and the play log. True when it got through (or the tablet was
## removed on the way); false means try again after a backoff.
func sync_once() -> bool:
	if busy or not is_paired():
		return false
	busy = true
	var ok: bool = await _sync()
	busy = false
	if not is_paired():
		ok = true
	if ok:
		failures = 0
		next_sync_at = clock + SYNC_EVERY
	else:
		failures += 1
		next_sync_at = clock + retry_delay(failures)
	_save_state()
	changed.emit()
	return ok


func _sync() -> bool:
	if state["map_dirty"]:
		if not await _put_profiles():
			return false
	if not is_paired():
		return true
	if want_profiles:
		if not await _get_profiles():
			return false
	for profile in state["restore"].duplicate():
		if not is_paired():
			return true
		if not await _restore(profile):
			return false
	if is_paired() and clock >= settings_at + SETTINGS_EVERY:
		if not await _fetch_settings():
			return false
	if is_paired() and consent():
		if not state["snap_dirty"].is_empty():
			if not await _put_snapshots():
				return false
		if is_paired() and not await _upload_events():
			return false
	return true


# --- the steps -----------------------------------------------------------------------

func _put_profiles() -> bool:
	var gen := _map_gen
	var items := FamilyState.profile_items(state, _roster())
	var r: Dictionary = await _request(FamilyApi.put_profiles(dev, items))
	match r["kind"]:
		"ok":
			var same := gen == _map_gen
			_queue_restore(FamilyState.adopt_profiles(state, r["data"], same))
			if same:
				state["map_dirty"] = false
			settings_at = -INF
			for id in state["map"]:
				save_written(id)
			_save_state()
			return true
		"conflict":
			# the family has 12 children: nothing in the call was written; the
			# "New child" picks go back to not linked, the rest go again
			for id in state["map"]:
				if state["map"][id] == FamilyApi.NEW_CHILD:
					state["map"][id] = null
			message = "The family already has 12 children. Remove one in the parent app first."
			_save_state()
			return true
		"bad", "missing":
			state["map_dirty"] = false
			want_profiles = true
			message = "The parent app did not take the list of players (%s)." % str(r["data"].get("detail", r["status"]))
			_save_state()
			return true
		"gone":
			return true
	return false


func _get_profiles() -> bool:
	var r: Dictionary = await _request(FamilyApi.get_profiles(dev))
	if r["kind"] == "retry":
		return false
	want_profiles = false
	if r["kind"] == "ok":
		_queue_restore(FamilyState.adopt_profiles(state, r["data"], not state["map_dirty"]))
		_save_state()
	return true


func _queue_restore(ids: Array) -> void:
	for id in ids:
		if not state["restore"].has(id):
			state["restore"].append(id)


func _restore(profile: String) -> bool:
	var child = child_of(profile)
	if not FamilyApi.is_child_id(child):
		state["restore"].erase(profile)
		return true
	var r: Dictionary = await _request(FamilyApi.get_snapshots(child, game))
	if r["kind"] == "retry":
		return false
	state["restore"].erase(profile)
	_save_state()
	if r["kind"] != "ok":
		return true
	var snaps := []
	var list = r["data"].get("snapshots", [])
	if list is Array:
		for s in list:
			if s is Dictionary and s.get("save") is Dictionary and str(s.get("game", game)) == game:
				snaps.append(s)
	if snaps.is_empty():
		return true
	merge_snapshots(profile, child, snaps)
	return true


## Merges the parent app's snapshots for a profile into its local save
## (the game's merge keeps everything earned anywhere) and writes it.
func merge_snapshots(profile: String, child: String, snaps: Array) -> void:
	var local: Dictionary = _hook("read_save").call(profile)
	var at := 0
	if _hook("saved_at").is_valid():
		at = int(_hook("saved_at").call(profile))
	var mine: Dictionary = _hook("snapshot").call(local, dev, 1, at, child)
	var all := [mine]
	all.append_array(snaps)
	var merged: Dictionary = _hook("merge").call(all, profile, local)
	_hook("write_save").call(profile, merged)
	save_written(profile)
	message = "Restored progress from the parent app."
	changed.emit()


func _fetch_settings() -> bool:
	var kids := FamilyState.mapped_children(state)
	for child in state["settings"].keys():
		if not kids.has(child):
			state["settings"].erase(child)
	for child in kids:
		var r: Dictionary = await _request(FamilyApi.get_settings(child, game))
		if r["kind"] == "retry":
			return false
		if not is_paired():
			return true
		if r["kind"] == "ok":
			state["settings"][child] = r["data"]
	settings_at = clock
	_save_state()
	return true


func _put_snapshots() -> bool:
	for profile in state["snap_dirty"].duplicate():
		var child = child_of(profile)
		if not FamilyApi.is_child_id(child) or state["guests"].has(profile):
			state["snap_dirty"].erase(profile)
			continue
		var save: Dictionary = _hook("read_save").call(profile)
		var rev := int(state["snap_rev"].get(child, 0)) + 1
		for _attempt in 3:
			var snap: Dictionary = _hook("snapshot").call(save, dev, rev, int(now_local()["unix"]), child)
			var r: Dictionary = await _request(FamilyApi.put_snapshot(child, game, dev, snap))
			if not is_paired():
				return true
			if r["kind"] == "ok":
				state["snap_rev"][child] = rev
				state["snap_dirty"].erase(profile)
				break
			if r["kind"] == "conflict" and typeof(r["data"].get("stored_rev")) == TYPE_INT:
				# another copy of this tablet's id got there first: jump past it
				state["snap_rev"][child] = int(r["data"]["stored_rev"])
				rev = int(r["data"]["stored_rev"]) + 1
				continue
			if r["kind"] == "retry":
				return false
			# too big, or refused: it will never pass as it is
			state["snap_dirty"].erase(profile)
			break
	snap_due = -1.0
	snap_first = -1.0
	_save_state()
	return true


func _upload_events() -> bool:
	if state["inflight"].is_empty() and _last_seq() <= int(state["sent"]) and _hook("last_seq").is_valid():
		return true
	FamilyState.note_guests(state, _roster())
	var items := FamilyEvents.read_lines(_hook("log_files").call(), int(state["sent"]))
	for i in MAX_BATCHES:
		var batch := FamilyEvents.plan(items, int(state["sent"]), dev, state["guests"], state["inflight"])
		if batch["lines"].is_empty():
			var was_inflight: bool = not state["inflight"].is_empty()
			state["sent"] = maxi(int(state["sent"]), int(batch["advance"]))
			state["inflight"] = {}
			_save_state()
			_keep_log()
			if was_inflight:
				continue
			return true
		state["inflight"] = FamilyEvents.inflight_of(batch)
		_save_state()
		var gz := gzip_ok
		var headers := ["Content-Type: application/x-ndjson"]
		if gz:
			headers.append("Content-Encoding: gzip")
		var body := FamilyEvents.pack(FamilyEvents.body_text(batch["lines"]), gz)
		var r: Dictionary = await _request(FamilyApi.put_events(game, dev, int(batch["first"]), int(batch["last"])), body, headers)
		match r["kind"]:
			"ok":
				state["sent"] = maxi(int(state["sent"]), int(batch["advance"]))
				state["inflight"] = {}
				state["last_upload"] = int(now_local()["unix"])
				_save_state()
				_keep_log()
			"bad":
				if gz and str(r["data"].get("detail", "")).contains("gzip"):
					gzip_ok = false
					continue
				var after := FamilyEvents.after_refusal(items, batch, int(state["sent"]), dev, state["guests"])
				state["inflight"] = after["inflight"]
				state["sent"] = int(after["sent"])
				state["skipped"] = int(state["skipped"]) + int(after["skipped"])
				_save_state()
				_keep_log()
			"gone":
				return true
			_:
				return false
	return true


# --- pairing -------------------------------------------------------------------------

func _poll_pairing() -> void:
	pairing.polling = true
	var pid := pairing.pair_id
	var r: Dictionary = await _request(FamilyApi.pair_poll(pid), PackedByteArray(), [], false)
	if pairing.pair_id != pid or pairing.state != FamilyPairing.State.WAITING:
		return
	if pairing.polled(int(r["status"]), r["data"], clock) == FamilyPairing.State.APPROVED:
		adopt_pairing(pairing.approved)
	changed.emit()


## The approved answer: keep the token, the family's name and children.
func adopt_pairing(data: Dictionary) -> void:
	if str(data.get("dev", dev)) != dev or str(data.get("device_token", "")) == "":
		pairing.state = FamilyPairing.State.OFFLINE
		return
	token = str(data["device_token"])
	_write(FamilyConfig.TOKEN_FILE, FamilyState.token_text(token, dev, base_url, int(now_local()["unix"])))
	FamilyState.adopt_approved(state, data)
	FamilyState.note_guests(state, _roster())
	message = "Linked to the family as \"%s\"." % device_name()
	want_profiles = true
	settings_at = -INF
	_keep_log()
	_save_state()
	sync_soon()


# --- one call ------------------------------------------------------------------------

## Sends one call. -> {status, data, kind} (kind from FamilyApi.classify).
## A device call answered 401, 403 or 410 drops the token: the tablet plays
## on unpaired.
func _request(req: Dictionary, raw := PackedByteArray(), extra := [], authed := true) -> Dictionary:
	var headers := PackedStringArray(["Accept: application/json"])
	if authed and token != "":
		headers.append("Authorization: Device " + token)
	var body := raw
	if req.has("json"):
		headers.append("Content-Type: application/json")
		body = JSON.stringify(req["json"]).to_utf8_buffer()
	for h in extra:
		headers.append(h)
	var sent_with := token
	var r: Dictionary = await transport.send(str(req["method"]), base_url + str(req["path"]), headers, body)
	var status := int(r.get("status", 0))
	var b = r.get("body", PackedByteArray())
	var data := FamilyApi.parse_body(b if b is PackedByteArray else PackedByteArray())
	var kind := FamilyApi.classify(status)
	if kind == "gone" and authed and sent_with != "" and sent_with == token:
		_forget()
		message = "This tablet was removed from the family. It plays on as before." if status == 410 \
				else "The parent app no longer knows this tablet. Link it again to send play records."
		changed.emit()
	return {"status": status, "data": data, "kind": kind}


func _forget() -> void:
	token = ""
	var p := dir.path_join(FamilyConfig.TOKEN_FILE)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	FamilyState.drop(state)
	pairing.cancel()
	snap_due = -1.0
	snap_first = -1.0
	_save_state()
	_keep_log()


# --- files and hooks -------------------------------------------------------------------

func _load() -> void:
	var tp := dir.path_join(FamilyConfig.TOKEN_FILE)
	token = FamilyState.token_from_text(FileAccess.get_file_as_string(tp) if FileAccess.file_exists(tp) else "", dev, base_url)
	var sp := dir.path_join(FamilyConfig.STATE_FILE)
	state = FamilyState.from_text(FileAccess.get_file_as_string(sp) if FileAccess.file_exists(sp) else "")
	if token == "" and str(state.get("family", "")) != "":
		# no usable token (a copied folder, another server): unpaired
		FamilyState.drop(state)


func _save_state() -> void:
	if configured:
		_write(FamilyConfig.STATE_FILE, FamilyState.to_text(state))


## Text to a file through a temp file, so a crash never leaves half a file.
func _write(name: String, text: String) -> void:
	var p := dir.path_join(name)
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	DirAccess.rename_absolute(tmp, p)


func _count(delta: float) -> void:
	if not counting or not is_paired() or not _hook("active_profile").is_valid():
		return
	var p := str(_hook("active_profile").call())
	if p == "" or state["guests"].has(p):
		return
	FamilyLimits.add_play(state["playtime"], str(now_local()["date"]), p, delta)
	_play_unsaved += delta
	if _play_unsaved >= SAVE_PLAY_EVERY:
		_play_unsaved = 0.0
		_save_state()


func _hook(name: String) -> Callable:
	var c = adapter.get(name)
	return c if c is Callable else Callable()


func _roster() -> Array:
	var c := _hook("roster")
	return c.call() if c.is_valid() else []


func _last_seq() -> int:
	var c := _hook("last_seq")
	return int(c.call()) if c.is_valid() else 0


func _keep_log() -> void:
	var c := _hook("keep_log_after")
	if c.is_valid():
		c.call(int(state["sent"]) if is_paired() else -1)
