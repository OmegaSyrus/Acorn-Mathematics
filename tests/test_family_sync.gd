## The family add-on end to end against an in-memory server
## (tests/support/family_fake.gd), with no network: pairing, consent before
## anything uploads, Guest lines never sent, the upload position moving only
## after a 2xx, a removed tablet ("gone") playing on unpaired, "New child",
## restore by merge, snapshot revisions past a 409, settings and limits.
extends "res://tests/support/test_case.gd"

const Family := preload("res://addons/acorn_family/family.gd")
const FamilyPairing := preload("res://addons/acorn_family/family_pairing.gd")
const FamilyConfig := preload("res://addons/acorn_family/family_config.gd")
const Fake := preload("res://tests/support/family_fake.gd")
const SchemaCheck := preload("res://tests/support/schema_check.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const PlayLog := preload("res://game/play_log.gd")

const DEV := "d_7f3a9c1e04b25d68"
const OTHER_DEV := "d_00c0ffee00c0ffee"
const P1 := "p_04a2c9e1f3b7"
const P2 := "p_91c0d2e4a6b8"
const GUEST := "p_5e5e00a1b2c3"
const CHILD := "c_9b2f00e1a7c4"

## One test's world: the Family node, the fake server, the game's hooks.
class World:
	var fam: Node
	var server
	var dir: String
	var log_path: String
	var saves := {}
	var keep := -2
	var seq := 0
	var writes := []
	var roster := [{"id": P1, "nickname": "Bear", "picture": "fox", "guest": false},
			{"id": P2, "nickname": "Wren", "picture": "bunny", "guest": false},
			{"id": GUEST, "nickname": "Guest", "picture": "slime_knight", "guest": true}]
	var now := {"date": "2026-11-28", "minute": 10 * 60, "second": 0, "unix": 1764320000}

	func hooks() -> Dictionary:
		return {"game": "acorn-math", "dev": DEV, "app": "0.29.0", "code": 48,
				"roster": get_roster, "active_profile": active, "read_save": read_save, "write_save": write_save,
				"snapshot": snapshot, "merge": merge, "saved_at": saved_at, "log_files": log_files,
				"last_seq": last_seq, "keep_log_after": keep_log_after}

	func get_roster() -> Array:
		return roster

	func active() -> String:
		return P1

	func read_save(p: String) -> Dictionary:
		return saves.get(p, SaveData.new_profile(p)).duplicate(true)

	func write_save(p: String, s: Dictionary) -> void:
		saves[p] = s
		writes.append(p)

	func snapshot(s: Dictionary, d: String, rev: int, t: int, child: Variant) -> Dictionary:
		return SaveData.snapshot(s, d, rev, t, child)

	func merge(snaps: Array, p: String, local: Dictionary) -> Dictionary:
		return SaveData.merge(snaps, p, local.get("run"))

	func saved_at(_p: String) -> int:
		return 0

	func log_files() -> Array:
		return [log_path]

	func last_seq() -> int:
		return seq

	func keep_log_after(n: int) -> void:
		keep = n

	func get_now() -> Dictionary:
		return now

	func line(profile: String, name := "run_start") -> void:
		seq += 1
		var e := {"v": 2, "game": "acorn-math", "kind": "event", "dev": DEV, "profile": profile, "seq": seq, "boot": 3,
				"t": 1764320000 + seq, "mono_ms": seq * 10, "app": "0.29.0", "code": 48, "cv": 2, "event": name}
		PlayLog.append(JSON.stringify(e), log_path)

	func cleanup() -> void:
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		DirAccess.remove_absolute(dir)
		fam.free()


func _world(paired := false) -> World:
	var w := World.new()
	w.dir = OS.get_temp_dir().path_join("acorn_family_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(w.dir)
	w.log_path = w.dir.path_join("play_log.jsonl")
	w.server = Fake.new()
	w.server.dev = DEV
	w.fam = Family.new()
	w.fam.base_url = "https://fake.invalid/v1"
	w.fam.transport = w.server
	w.fam.local_time = w.get_now
	w.fam.configure(w.hooks(), w.dir)
	if paired:
		_pair(w)
	return w


func _pair(w: World) -> void:
	var f = w.fam
	f.call("start_pairing")
	f.call("_poll_pairing")


func _sync(w: World) -> bool:
	var f = w.fam
	return f.call("sync_once")


func test_unpaired_does_nothing() -> bool:
	var w := _world()
	w.line(P1)
	check(not w.fam.is_paired(), "unpaired")
	check(_sync(w) == false, "no sync")
	w.fam.save_written(P1)
	w.fam._process(500.0)
	eq(w.server.calls.size(), 0, "no call at all while unpaired")
	eq(w.keep, -1, "the play log rotates as before")
	eq(w.fam.stop_reason(P1), "", "no limits")
	check(not FileAccess.file_exists(w.dir.path_join(FamilyConfig.TOKEN_FILE)), "no token file")
	w.cleanup()
	return true


func test_pairing_stores_the_token() -> bool:
	var w := _world()
	w.server.pair_state = "waiting"
	var f = w.fam
	f.call("start_pairing")
	eq(w.fam.pairing.state, FamilyPairing.State.WAITING, "waiting with a code")
	eq(w.fam.pairing.code, "K7Q-42M", "the code to show")
	eq(w.server.calls[0]["json"], {"game": "acorn-math", "dev": DEV, "app": "0.29.0", "code": 48}, "pair/start body")
	check(not w.fam.pairing.due(w.fam.clock + 1.0), "first poll after 3 s")
	f.call("_poll_pairing")
	check(not w.fam.is_paired(), "still waiting")
	w.server.pair_state = "approved"
	f.call("_poll_pairing")
	check(w.fam.is_paired(), "paired")
	eq(w.fam.device_name(), "Kitchen tablet", "name")
	eq(w.fam.children().size(), 1, "the family's children")
	check(not w.fam.consent(), "sending stays off until a grown-up turns it on")
	check(FileAccess.file_exists(w.dir.path_join(FamilyConfig.TOKEN_FILE)), "token file")
	for c in w.server.calls:
		check(not c["headers"].has("Authorization: Device dt_fake_token"), "pairing calls carry no token")
	eq(w.keep, 0, "the play log now keeps unsent lines")
	# a new start (another launch) reads the same token
	var again := Family.new()
	again.base_url = "https://fake.invalid/v1"
	again.transport = w.server
	again.configure(w.hooks(), w.dir)
	check(again.is_paired(), "the token survives a restart")
	again.free()
	# but not on another server
	var other := Family.new()
	other.base_url = "https://other.invalid/v1"
	other.transport = w.server
	other.configure(w.hooks(), w.dir)
	check(not other.is_paired(), "a token is only for its server")
	other.free()
	w.cleanup()
	return true


func test_consent_gates_uploads() -> bool:
	var w := _world(true)
	w.fam.set_child(P1, CHILD)
	w.line(P1)
	w.line(GUEST)
	w.line(P2)
	w.fam.save_written(P1)
	check(_sync(w), "sync")
	eq(w.server.calls_to("/events/").size(), 0, "no play records before consent")
	eq(w.server.calls_to("/snapshots/", "PUT").size(), 0, "no save backup before consent")
	eq(w.server.calls_to("/profiles", "PUT").size(), 1, "who is who goes")
	check(w.fam.status_line().contains("off"), "the screen says sending is off")
	w.fam.set_consent(true)
	check(_sync(w), "sync with consent")
	eq(w.server.stored_seqs(), [1, 3], "the child lines went, the Guest line did not")
	for k in w.server.batches:
		eq(k, "1-3", "range {first_seq}-{last_seq}")
		for l in w.server.batches[k]:
			check(not l.contains(GUEST), "no Guest line")
	var put: Array = w.server.calls_to("/events/")
	check(Array(put[0]["headers"]).has("Content-Encoding: gzip"), "gzipped")
	eq(int(w.fam.state["sent"]), 3, "position after the 2xx")
	eq(w.keep, 3, "the play log may rotate away what is sent")
	eq(w.server.calls_to("/snapshots/", "PUT").size(), 1, "the save backed up once consent is on")
	eq(w.fam.status_line(), "Everything is sent.", "status")
	# a Guest line alone moves the position without a call
	w.line(GUEST)
	var before: int = w.server.calls_to("/events/").size()
	_sync(w)
	eq(w.server.calls_to("/events/").size(), before, "nothing sent for a Guest line")
	eq(int(w.fam.state["sent"]), 4, "but it is dealt with")
	# turned off again: nothing more goes
	w.fam.set_consent(false)
	w.line(P1)
	_sync(w)
	eq(w.server.stored_seqs(), [1, 3], "off means off")
	w.cleanup()
	return true


func test_position_moves_only_after_2xx() -> bool:
	var w := _world(true)
	w.fam.set_consent(true)
	w.fam.set_child(P1, CHILD)
	_sync(w)
	for i in 3:
		w.line(P1)
	w.server.fail_with = 503
	w.server.fail_path = "/events/"
	check(_sync(w) == false, "a failed sync")
	eq(int(w.fam.state["sent"]), 0, "nothing counted as sent")
	eq(w.fam.state["inflight"], {"first": 1, "last": 3, "advance": 3}, "the batch kept for next time")
	eq(w.fam.failures, 1, "a backoff")
	eq(w.fam.next_sync_at, w.fam.clock + Family.RETRY_BASE, "30 s first")
	check(w.fam.status_line().contains("no internet"), "the screen says why")
	# offline altogether
	w.server.fail_with = 0
	w.server.fail_path = ""
	_sync(w)
	eq(w.fam.failures, 2, "backing off")
	eq(Family.retry_delay(2), 60.0, "then a minute")
	eq(Family.retry_delay(20), Family.RETRY_MAX, "at most 30 minutes")
	# a lost answer: more lines meanwhile; the same range goes again
	w.line(P1)
	w.server.fail_with = -1
	check(_sync(w), "back online")
	eq(w.server.batches.keys(), ["1-3", "4-4"], "the kept range first, then the new line")
	eq(int(w.fam.state["sent"]), 4, "all sent")
	eq(w.fam.failures, 0, "backoff reset")
	w.cleanup()
	return true


func test_refused_line_is_skipped_not_stuck() -> bool:
	var w := _world(true)
	w.fam.set_consent(true)
	w.line(P1)
	# a line the server's schema refuses (no skill on an answer)
	w.seq += 1
	PlayLog.append(JSON.stringify({"v": 2, "game": "acorn-math", "kind": "answer", "dev": DEV, "profile": P1,
			"seq": w.seq, "boot": 3, "t": 1, "mono_ms": 1, "app": "0.29.0", "code": 48, "cv": 2}), w.log_path)
	w.line(P1)
	w.line(P1)
	check(_sync(w), "sync")
	eq(w.server.stored_seqs(), [1, 3, 4], "the good lines went")
	eq(int(w.fam.state["sent"]), 4, "past the bad one")
	eq(int(w.fam.state["skipped"]), 1, "one skipped")
	w.cleanup()
	return true


func test_gone_drops_the_token() -> bool:
	for status in [410, 401, 403]:
		var w := _world(true)
		w.fam.set_consent(true)
		w.fam.set_child(P1, CHILD)
		w.line(P1)
		_sync(w)
		eq(int(w.fam.state["sent"]), 1, "sent while in the family")
		w.line(P1)
		if status == 410:
			w.server.removed = true
		elif status == 401:
			w.server.token = "dt_another"
		else:
			w.server.fail_with = 403
		check(_sync(w), "a removed tablet is not an error to retry")
		check(not w.fam.is_paired(), "%d: token dropped" % status)
		check(not FileAccess.file_exists(w.dir.path_join(FamilyConfig.TOKEN_FILE)), "token file gone")
		check(not w.fam.consent(), "consent gone with the family")
		eq(w.fam.child_of(P1), null, "map gone")
		eq(int(w.fam.state["sent"]), 1, "the position stays")
		eq(w.keep, -1, "the play log rotates as before")
		check(w.fam.message != "", "a line for the grown-up")
		var n: int = w.server.calls.size()
		w.line(P1)
		_sync(w)
		w.fam._process(1000.0)
		eq(w.server.calls.size(), n, "%d: no more calls" % status)
		w.cleanup()
	return true


func test_unlink_forgets_here() -> bool:
	var w := _world(true)
	w.fam.set_child(P1, CHILD)
	w.fam.unlink()
	check(not w.fam.is_paired(), "unlinked")
	check(w.fam.message.contains("parent app"), "explains the parent app still lists it")
	w.cleanup()
	return true


func test_new_child_is_made_once() -> bool:
	var w := _world(true)
	w.fam.set_child(P2, "new")
	_sync(w)
	var put: Dictionary = w.server.calls_to("/profiles", "PUT")[0]["json"]
	var item: Dictionary = put["profiles"][1]
	eq([item["profile"], item["child"], item["nickname"], item["picture"]], [P2, "new", "Wren", "bunny"],
			"\"child\": \"new\" with the nickname and picture")
	for p in put["profiles"]:
		check(p["profile"] != GUEST, "a Guest is never sent")
	var made = w.fam.child_of(P2)
	check(made is String and made.begins_with("c_"), "mapped to the made child")
	eq(w.server.children.size(), 2, "one child made")
	check(not w.fam.state["map_dirty"], "sent")
	eq(w.fam.state["restore"], [], "a new child has nothing to restore")
	# twelve children: the call is refused and the pick goes back
	var w2 := _world(true)
	for i in 11:
		w2.server.children.append({"child": "c_%012x" % (0xa000 + i), "nickname": "K%d" % i, "picture": "fox"})
	w2.fam.set_child(P1, "new")
	_sync(w2)
	eq(w2.fam.child_of(P1), null, "not linked")
	check(w2.fam.message.contains("12"), "the grown-up hears why")
	w.cleanup()
	w2.cleanup()
	return true


func test_restore_merges_other_tablets() -> bool:
	var w := _world(true)
	w.fam.set_consent(true)
	# this tablet: Bear has played a little here
	var mine := SaveData.new_profile(P1)
	mine["marks"] = {"lava_caves": [1]}
	mine["gems"] = 3
	mine["gem_counts"] = {DEV: {"earned": 3, "spent": 0}}
	mine["run"] = {"area": "lava_scroll", "grade": 1, "seed": 5}
	w.saves[P1] = mine
	# another tablet backed Bear up with more
	var theirs := SaveData.new_profile("p_aaaaaaaaaaaa")
	theirs["marks"] = {"lava_caves": [1, 12], "crystal_mines": [21]}
	theirs["gems"] = 10
	theirs["gem_counts"] = {OTHER_DEV: {"earned": 12, "spent": 2}}
	theirs["hero"] = "fox"
	theirs["run"] = {"area": "crystal_scroll", "grade": 21, "seed": 9}
	w.server.snapshots[CHILD] = {OTHER_DEV: SaveData.snapshot(theirs, OTHER_DEV, 4, 1764000000, CHILD)}
	w.fam.set_child(P1, CHILD)
	_sync(w)
	eq(w.writes, [P1], "the merged save written")
	var got: Dictionary = w.saves[P1]
	eq(got["profile"], P1, "still this profile")
	eq(got["marks"], {"lava_caves": [1, 12], "crystal_mines": [21]}, "marks from both")
	eq(got["gems"], 13, "gems: every tablet's earned minus spent")
	eq(got["hero"], "fox", "the newer tablet's hero (this save is blank-old)")
	eq(got["run"], mine["run"], "this tablet's run stays")
	eq(w.fam.state["restore"], [], "done")
	var up: Array = w.server.calls_to("/snapshots/" + DEV, "PUT")
	check(up.size() >= 1, "the merged save backed up")
	eq(w.server.snapshots[CHILD][DEV]["save"]["gems"], 13, "the merged one")
	# "Restore from parent app" runs it again on demand
	w.writes.clear()
	w.fam.restore_all()
	_sync(w)
	eq(w.writes, [P1], "restored again")
	eq(w.saves[P1]["gems"], 13, "nothing counted twice")
	w.cleanup()
	return true


func test_snapshot_body_and_409() -> bool:
	var w := _world(true)
	w.fam.set_consent(true)
	w.fam.set_child(P1, CHILD)
	# another copy of this tablet's id stored rev 10 already
	var old := SaveData.snapshot(SaveData.new_profile(P1), DEV, 10, 1, CHILD)
	w.server.snapshots[CHILD] = {DEV: old}
	_sync(w)
	var puts: Array = w.server.calls_to("/snapshots/" + DEV, "PUT")
	eq(puts.size(), 2, "a 409, then past it")
	eq(int(puts[0]["json"]["rev"]), 1, "first try rev 1")
	eq(int(puts[1]["json"]["rev"]), 11, "then stored_rev + 1")
	eq(int(w.fam.state["snap_rev"][CHILD]), 11, "remembered")
	var schema: Dictionary = JsonUtil.load_file("res://docs/contract/schemas/snapshot.v1.schema.json")
	for p in puts:
		var errs := SchemaCheck.errors(p["json"], schema)
		check(errs.is_empty(), "snapshot.v1: " + "; ".join(errs))
		eq([p["json"]["dev"], p["json"]["profile"], p["json"]["child"]], [DEV, P1, CHILD], "ids")
	# the next save write goes as 12, after the debounce
	w.fam.save_written(P1)
	check(w.fam.snap_due > w.fam.clock, "debounced")
	_sync(w)
	eq(int(w.server.snapshots[CHILD][DEV]["rev"]), 12, "rev keeps rising")
	# a Guest's save is never backed up
	w.fam.save_written(GUEST)
	check(not w.fam.state["snap_dirty"].has(GUEST), "Guest never syncs")
	w.cleanup()
	return true


func test_settings_cached_and_enforced() -> bool:
	var w := _world(true)
	w.server.settings[CHILD] = {"schema": "family.settings", "v": 1, "child": CHILD, "game": "acorn-math", "rev": 2,
			"fields": {"daily_minutes": {"value": 20, "rev": 1, "at": 1, "by": "parent"},
			"bedtime": {"value": "19:30", "rev": 2, "at": 1, "by": "parent"}}}
	w.fam.set_child(P1, CHILD)
	_sync(w)
	eq(w.fam.limits_for(P1), {"daily_minutes": 20, "bedtime": "19:30"}, "fetched")
	eq(w.fam.limits_for(P2), {"daily_minutes": 0, "bedtime": null}, "an unlinked profile has none")
	eq(w.fam.stop_reason(P1), "", "10:00, nothing played")
	# minutes count while playing (the active profile), per local day
	w.fam._process(19 * 60.0)
	eq(w.fam.stop_reason(P1), "", "19 minutes")
	w.fam._process(61.0)
	eq(w.fam.stop_reason(P1), "daily", "20 minutes: time to rest")
	w.fam.counting = false
	w.fam._process(600.0)
	check(w.fam.minutes_played_secs(P1) < 21 * 60.0, "not counted while counting is off")
	w.fam.counting = true
	# offline: the cached settings still apply after a restart
	w.server.fail_with = 0
	var again := Family.new()
	again.base_url = "https://fake.invalid/v1"
	again.transport = w.server
	again.local_time = w.get_now
	again.configure(w.hooks(), w.dir)
	w.fam._save_state()
	again._load()
	eq(again.stop_reason(P1), "daily", "remembered offline, across restarts")
	# a grown-up's pass until the morning
	w.fam.grant_pass(P1)
	eq(w.fam.stop_reason(P1), "", "a grown-up said yes")
	# the next day: minutes start again, bedtime still applies at night
	w.now = {"date": "2026-11-29", "minute": 20 * 60, "second": 0, "unix": 1764320000 + 34 * 3600}
	eq(w.fam.stop_reason(P1), "bedtime", "20:00 the next day")
	w.now = {"date": "2026-11-29", "minute": 9 * 60, "second": 0, "unix": 1764320000 + 23 * 3600}
	eq(w.fam.stop_reason(P1), "", "a new morning")
	again.free()
	w.cleanup()
	return true
