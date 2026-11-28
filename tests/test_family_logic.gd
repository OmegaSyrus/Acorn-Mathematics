## The family add-on's pure parts (addons/acorn_family): pairing as a state
## machine, play log batches and their ranges, the play log keeping unsent
## lines, settings and the time limits, the state file and the token.
extends "res://tests/support/test_case.gd"

const FamilyApi := preload("res://addons/acorn_family/family_api.gd")
const FamilyPairing := preload("res://addons/acorn_family/family_pairing.gd")
const FamilyEvents := preload("res://addons/acorn_family/family_events.gd")
const FamilyLimits := preload("res://addons/acorn_family/family_limits.gd")
const FamilyState := preload("res://addons/acorn_family/family_state.gd")
const FamilyConfig := preload("res://addons/acorn_family/family_config.gd")
const PlayLog := preload("res://game/play_log.gd")

const DEV := "d_7f3a9c1e04b25d68"
const P1 := "p_04a2c9e1f3b7"
const P2 := "p_91c0d2e4a6b8"
const GUEST := "p_5e5e00a1b2c3"
const CHILD := "c_9b2f00e1a7c4"


# --- calls ---------------------------------------------------------------------------

func test_paths_and_ranges() -> bool:
	eq(FamilyApi.range_name(10430, 10435), "10430-10435", "range name")
	eq(FamilyApi.put_events("acorn-math", DEV, 10430, 10435)["path"],
			"/events/acorn-math/d_7f3a9c1e04b25d68/10430-10435", "the sample's events path")
	eq(FamilyApi.put_snapshot(CHILD, "acorn-math", DEV, {})["path"],
			"/children/c_9b2f00e1a7c4/games/acorn-math/snapshots/d_7f3a9c1e04b25d68", "snapshot path")
	eq(FamilyApi.pair_poll("pr_6c1d8e")["path"], "/devices/pair/poll?pair_id=pr_6c1d8e", "poll path")
	var start := FamilyApi.pair_start("acorn-math", DEV, "0.23.1", 42)
	var sample: Dictionary = JsonUtil.load_file("res://docs/contract/samples/api-pair.json")
	eq(start["json"], sample["pair_start"]["request"], "pair/start body is the sample's")
	eq(start["method"], "POST", "POST")
	return true


func test_classify_answers() -> bool:
	for s in [200, 201, 204]:
		eq(FamilyApi.classify(s), "ok", str(s))
	for s in [401, 403, 410]:
		eq(FamilyApi.classify(s), "gone", "%d drops the token" % s)
	eq(FamilyApi.classify(409), "conflict", "409")
	for s in [400, 413, 422]:
		eq(FamilyApi.classify(s), "bad", str(s))
	for s in [0, 429, 500, 502, 503]:
		eq(FamilyApi.classify(s), "retry", "%d is tried again later" % s)
	eq(FamilyApi.parse_body("{\"stored_rev\": 7}".to_utf8_buffer()), {"stored_rev": 7}, "whole numbers are ints")
	check(FamilyApi.parse_body(PackedByteArray()).is_empty(), "no body")
	check(FamilyApi.parse_body("<html>".to_utf8_buffer()).is_empty(), "not JSON")
	return true


func test_base_url_setting() -> bool:
	check(FamilyConfig.DEFAULT_BASE_URL.ends_with("/functions/v1/api/v1"), "staging default")
	if OS.get_environment(FamilyConfig.ENV) == "":
		eq(FamilyConfig.base_url(), str(ProjectSettings.get_setting(FamilyConfig.SETTING)), "project setting")
	check(not FamilyConfig.base_url().ends_with("/"), "no trailing slash")
	return true


# --- pairing -------------------------------------------------------------------------

func _waiting(now := 0.0) -> FamilyPairing:
	var p := FamilyPairing.new()
	p.begin()
	p.started(201, {"pair_id": "pr_" + "a".repeat(32), "code": "K7Q-42M", "qr_url": null, "expires_in": 600}, now)
	return p


func test_pairing_to_approved() -> bool:
	var p := FamilyPairing.new()
	eq(p.state, FamilyPairing.State.IDLE, "idle first")
	check(not p.due(100.0), "no polls while idle")
	p = _waiting(0.0)
	eq(p.state, FamilyPairing.State.WAITING, "waiting with a code")
	eq(p.code, "K7Q-42M", "code")
	eq(p.qr_url, "", "a null qr_url is no link")
	check(not p.due(2.9), "not before 3 s")
	check(p.due(3.0), "a poll at 3 s")
	p.polling = true
	check(not p.due(4.0), "one poll at a time")
	eq(p.polled(200, {"state": "waiting", "expires_in": 590}, 3.2), FamilyPairing.State.WAITING, "still waiting")
	eq(p.next_poll_at, 6.2, "next poll 3 s on")
	eq(p.seconds_left(3.2), 590, "expires_in from the answer")
	var done: Dictionary = JsonUtil.load_file("res://docs/contract/samples/api-pair.json")["pair_poll"]["response_done"]
	eq(p.polled(200, done, 6.3), FamilyPairing.State.APPROVED, "approved")
	eq(p.approved["device_token"], "dt_example_not_a_real_token", "the token handed over")
	check(not p.due(100.0), "no polls once approved")
	return true


func test_pairing_expiry_and_offline() -> bool:
	var p := _waiting(0.0)
	eq(p.polled(200, {"state": "expired"}, 3.0), FamilyPairing.State.EXPIRED, "server says expired")
	p = _waiting(0.0)
	eq(p.polled(404, {"error": "not_found"}, 3.0), FamilyPairing.State.EXPIRED, "a forgotten pairing is expired")
	p = _waiting(0.0)
	eq(p.polled(200, {"state": "waiting", "expires_in": 0}, 3.0), FamilyPairing.State.EXPIRED, "ran out locally")
	# offline while waiting: slower polls, still waiting, until it runs out
	p = _waiting(0.0)
	eq(p.polled(0, {}, 3.0), FamilyPairing.State.WAITING, "no answer keeps waiting")
	eq(p.poll_delay(), 6.0, "doubling while offline")
	p.polled(0, {}, 9.0)
	p.polled(0, {}, 21.0)
	p.polled(0, {}, 45.0)
	eq(p.poll_delay(), 30.0, "at most 30 s offline")
	p.polled(200, {"state": "waiting", "expires_in": 500}, 80.0)
	eq(p.net_failures, 0, "back online")
	eq(p.polled(0, {}, 700.0), FamilyPairing.State.EXPIRED, "offline past the expiry")
	# a start that gets no answer
	var q := FamilyPairing.new()
	q.begin()
	q.started(0, {}, 0.0)
	eq(q.state, FamilyPairing.State.OFFLINE, "offline start")
	check(q.describe(0.0).contains("Wi-Fi"), "a friendly line")
	return true


func test_pairing_backs_off_after_a_minute() -> bool:
	var p := _waiting(0.0)
	var now := 0.0
	var delays := []
	for i in 30:
		now = p.next_poll_at
		p.polled(200, {"state": "waiting", "expires_in": 600 - int(now)}, now)
		delays.append(p.poll_delay())
	eq(delays[0], 3.0, "3 s at first")
	eq(delays[FamilyPairing.FAST_POLLS - 2], 3.0, "3 s for about a minute")
	check(delays[FamilyPairing.FAST_POLLS] > 3.0, "then slower")
	eq(delays[29], FamilyPairing.SLOW_POLL, "at most 10 s")
	return true


# --- batches -------------------------------------------------------------------------

func _line(seq: int, profile := P1, dev := DEV, v := 2) -> String:
	return JSON.stringify({"v": v, "game": "acorn-math", "kind": "event", "dev": dev, "profile": profile, "seq": seq,
			"boot": 1, "t": 1763290000 + seq, "mono_ms": seq, "app": "0.29.0", "code": 48, "cv": 2, "event": "e%d" % seq})


func _items(lines: Array) -> Array:
	var out := []
	for l in lines:
		var it := FamilyEvents.parse_line(l)
		if not it.is_empty():
			out.append(it)
	return out


func test_batches_and_ranges() -> bool:
	var lines := []
	for s in range(1, 11):
		lines.append(_line(s))
	var items := _items(lines)
	var b := FamilyEvents.plan(items, 0, DEV, [], {}, 4)
	eq([b["first"], b["last"], b["advance"], b["lines"].size()], [1, 4, 4, 4], "four lines a batch")
	b = FamilyEvents.plan(items, 4, DEV, [], {}, 4)
	eq([b["first"], b["last"]], [5, 8], "then the next four")
	b = FamilyEvents.plan(items, 8, DEV, [], {}, 4)
	eq([b["first"], b["last"], b["lines"].size()], [9, 10, 2], "the rest")
	b = FamilyEvents.plan(items, 10, DEV, [], {}, 4)
	check(b["lines"].is_empty(), "nothing after the end")
	eq(b["advance"], 10, "and the position stays")
	# a byte cap ends a batch early but always takes one line
	b = FamilyEvents.plan(items, 0, DEV, [], {}, 500, 10)
	eq(b["lines"].size(), 1, "one line even past the byte cap")
	eq(FamilyEvents.body_text(["a", "b"]), "a\nb\n", "one line each, newline at the end")
	return true


func test_guest_and_foreign_lines_never_go() -> bool:
	var lines := [_line(1), _line(2, GUEST), _line(3, P2), _line(4, GUEST), _line(5, P1, "d_00c0ffee00c0ffee"),
			_line(6, "1"), _line(7, GUEST)]
	lines.append('{"v":1,"kind":"event","profile":"1","t":5,"event":"old"}')
	var items := _items(lines)
	eq(items.size(), 7, "a version 1 line without seq is left out")
	var b := FamilyEvents.plan(items, 0, DEV, [GUEST])
	eq([b["first"], b["last"], b["advance"]], [1, 3, 7], "the range is the lines sent, the position past the trailing Guest lines")
	var sent := []
	for l in b["lines"]:
		sent.append(int(JSON.parse_string(l)["seq"]))
	eq(sent, [1, 3], "only this device's child lines with real profile ids")
	for l in b["lines"]:
		check(not l.contains(GUEST), "no Guest line in the body")
	# only Guest lines waiting: nothing goes, the position moves
	b = FamilyEvents.plan(_items([_line(8, GUEST), _line(9, GUEST)]), 7, DEV, [GUEST])
	check(b["lines"].is_empty(), "nothing to send")
	eq(b["advance"], 9, "past the Guest lines")
	return true


func test_inflight_goes_again_exactly() -> bool:
	var items := _items([_line(1), _line(2), _line(3)])
	var b := FamilyEvents.plan(items, 0, DEV, [], {}, 2)
	var inflight := FamilyEvents.inflight_of(b)
	eq(inflight, {"first": 1, "last": 2, "advance": 2}, "kept before sending")
	# more lines arrive; the answer was lost; the same range goes again
	items = _items([_line(1), _line(2), _line(3), _line(4), _line(5)])
	var again := FamilyEvents.plan(items, 0, DEV, [], inflight, 500)
	eq([again["first"], again["last"], again["lines"].size()], [1, 2, 2], "same range, same lines")
	return true


func test_refused_batches_split_then_skip() -> bool:
	var items := _items([_line(1), _line(2), _line(3), _line(4)])
	var b := FamilyEvents.plan(items, 0, DEV, [])
	var r := FamilyEvents.after_refusal(items, b, 0, DEV, [])
	eq(r["inflight"], {"first": 1, "last": 2, "advance": 2}, "first half alone next")
	eq(r["sent"], 0, "position unchanged")
	var one := FamilyEvents.plan(items, 0, DEV, [], {"first": 1, "last": 1, "advance": 1})
	r = FamilyEvents.after_refusal(items, one, 0, DEV, [])
	check(r["inflight"].is_empty(), "a single refused line is not sent again")
	eq(r["sent"], 1, "the position moves past it")
	eq(r["skipped"], 1, "counted")
	return true


func test_read_lines_from_every_file() -> bool:
	var base := OS.get_temp_dir().path_join("acorn_fam_read_%d.jsonl" % Time.get_ticks_usec())
	_write(PlayLog.kept_path(base, 2), _line(1) + "\n" + _line(2) + "\n")
	_write(PlayLog.kept_path(base, 1), _line(3) + "\nnot json\n" + _line(4) + "\n")
	_write(base, _line(5) + "\n")
	var files := PlayLog.log_files(base)
	eq(files, [PlayLog.kept_path(base, 2), PlayLog.kept_path(base, 1), base], "oldest first")
	var items := FamilyEvents.read_lines(files, 2)
	var seqs := []
	for it in items:
		seqs.append(it["seq"])
	eq(seqs, [3, 4, 5], "lines after the position, broken lines skipped")
	for f in files:
		DirAccess.remove_absolute(f)
	return true


func test_gzip_body() -> bool:
	var text := FamilyEvents.body_text([_line(1), _line(2)])
	var z := FamilyEvents.pack(text, true)
	eq(z.slice(0, 2), PackedByteArray([0x1f, 0x8b]), "a gzip stream")
	eq(z.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8(), text, "unpacks to the text")
	eq(FamilyEvents.pack(text, false).get_string_from_utf8(), text, "plain text too")
	return true


func _write(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# --- the play log keeps unsent lines --------------------------------------------------

func _fill(p: String, first_seq: int) -> int:
	# a full file of lines with seqs from first_seq; returns the last seq
	var f := FileAccess.open(p, FileAccess.WRITE)
	var pad := "x".repeat(900)
	var s := first_seq
	while f.get_length() < PlayLog.MAX_BYTES:
		f.store_line('{"seq":%d,"pad":"%s"}' % [s, pad])
		s += 1
	f.close()
	return s - 1


func test_rotation_keeps_unsent_lines_when_paired() -> bool:
	var p := OS.get_temp_dir().path_join("acorn_fam_rot_%d.jsonl" % Time.get_ticks_usec())
	var keep := PlayLog.keep_after
	# unpaired: the old rotated file is dropped, as before
	PlayLog.keep_after = -1
	var last1 := _fill(p, 1)
	PlayLog.append('{"seq":%d}' % (last1 + 1), p)
	var last2 := _fill(p, last1 + 2)
	PlayLog.append('{"seq":%d}' % (last2 + 1), p)
	check(not FileAccess.file_exists(PlayLog.kept_path(p, 2)), "unpaired: only one old file")
	eq(PlayLog.last_seq(PlayLog.rotated_path(p)), last2, "the newest full file is .1")
	# paired, nothing sent past the start of .1: rotating keeps it as .2
	PlayLog.keep_after = last1
	var last3 := _fill(p, last2 + 2)
	PlayLog.append('{"seq":%d}' % (last3 + 1), p)
	check(FileAccess.file_exists(PlayLog.kept_path(p, 2)), "unsent lines kept in .2")
	eq(PlayLog.last_seq(PlayLog.kept_path(p, 2)), last2, ".2 holds the older lines")
	eq(PlayLog.last_seq(PlayLog.rotated_path(p)), last3, ".1 the newer")
	eq(PlayLog.log_files(p).size(), 3, "three files to read")
	# everything sent: the next rotation drops the sent ones
	PlayLog.keep_after = last3 + 1
	var last4 := _fill(p, last3 + 2)
	PlayLog.append('{"seq":%d}' % (last4 + 1), p)
	check(not FileAccess.file_exists(PlayLog.kept_path(p, 2)), "sent files go")
	eq(PlayLog.log_files(p).size(), 2, "back to two files")
	PlayLog.keep_after = keep
	for f in PlayLog.log_files(p):
		DirAccess.remove_absolute(f)
	return true


# --- settings and time limits ---------------------------------------------------------

func _settings(fields: Dictionary) -> Dictionary:
	var out := {}
	for k in fields:
		out[k] = {"value": fields[k], "rev": 1, "at": 1763291000, "by": "parent"}
	return {"schema": "family.settings", "v": 1, "child": CHILD, "game": "acorn-math", "rev": 1, "fields": out}


func test_settings_parsing() -> bool:
	var sample: Dictionary = JsonUtil.load_file("res://docs/contract/samples/settings.json")
	eq(FamilyLimits.parse_settings(sample), {"daily_minutes": 30, "bedtime": null}, "the sample (unknown keys ignored)")
	eq(FamilyLimits.parse_settings(_settings({"daily_minutes": 45, "bedtime": "19:30"})),
			{"daily_minutes": 45, "bedtime": "19:30"}, "both")
	eq(FamilyLimits.parse_settings(_settings({"daily_minutes": 300, "bedtime": "25:00"})), FamilyLimits.NO_LIMITS,
			"bad values are not set")
	eq(FamilyLimits.parse_settings(_settings({"daily_minutes": -1, "bedtime": 7})), FamilyLimits.NO_LIMITS, "bad types")
	eq(FamilyLimits.parse_settings(_settings({"daily_minutes": 0, "bedtime": null})), FamilyLimits.NO_LIMITS, "0 and null")
	eq(FamilyLimits.parse_settings(null), FamilyLimits.NO_LIMITS, "nothing cached")
	eq(FamilyLimits.parse_settings({"fields": "x"}), FamilyLimits.NO_LIMITS, "broken")
	eq(FamilyLimits.parse_hhmm("07:05"), 425, "HH:MM")
	eq(FamilyLimits.parse_hhmm("7:05"), -1, "two digits")
	return true


func test_daily_minutes() -> bool:
	var limits := {"daily_minutes": 30, "bedtime": null}
	var pt := {"date": "", "secs": {}}
	FamilyLimits.add_play(pt, "2026-11-28", P1, 29 * 60.0)
	eq(FamilyLimits.stop_reason(limits, FamilyLimits.used(pt, "2026-11-28", P1), 600), "", "29 minutes: play on")
	eq(FamilyLimits.minutes_left(limits, FamilyLimits.used(pt, "2026-11-28", P1)), 1, "a minute left")
	FamilyLimits.add_play(pt, "2026-11-28", P1, 60.0)
	eq(FamilyLimits.stop_reason(limits, FamilyLimits.used(pt, "2026-11-28", P1), 600), "daily", "30 minutes: rest")
	eq(FamilyLimits.used(pt, "2026-11-28", P2), 0.0, "per profile")
	eq(FamilyLimits.stop_reason(limits, 9999.0, 600, true), "", "a grown-up's pass")
	eq(FamilyLimits.stop_reason(FamilyLimits.NO_LIMITS, 99999.0, 600), "", "0 is no limit")
	eq(FamilyLimits.minutes_left(FamilyLimits.NO_LIMITS, 5.0), -1, "no limit, no count")
	# the next day starts from zero
	eq(FamilyLimits.used(pt, "2026-11-29", P1), 0.0, "a new day")
	FamilyLimits.add_play(pt, "2026-11-29", P1, 5.0)
	eq(pt["date"], "2026-11-29", "rolled over")
	eq(FamilyLimits.used(pt, "2026-11-29", P1), 5.0, "counting again")
	eq(FamilyLimits.date_of({"year": 2026, "month": 3, "day": 7}), "2026-03-07", "local date")
	return true


func test_bedtime() -> bool:
	var b := {"daily_minutes": 0, "bedtime": "19:30"}
	eq(FamilyLimits.stop_reason(b, 0.0, 19 * 60 + 29), "", "19:29")
	eq(FamilyLimits.stop_reason(b, 0.0, 19 * 60 + 30), "bedtime", "19:30")
	eq(FamilyLimits.stop_reason(b, 0.0, 23 * 60 + 59), "bedtime", "late")
	eq(FamilyLimits.stop_reason(b, 0.0, 2 * 60), "bedtime", "the small hours are night too")
	eq(FamilyLimits.stop_reason(b, 0.0, 5 * 60), "", "morning")
	var late := {"daily_minutes": 0, "bedtime": "00:30"}
	eq(FamilyLimits.stop_reason(late, 0.0, 23 * 60), "", "an after-midnight bedtime: 23:00 is fine")
	eq(FamilyLimits.stop_reason(late, 0.0, 45), "bedtime", "00:45 is not")
	eq(FamilyLimits.stop_reason({"daily_minutes": 10, "bedtime": "19:30"}, 9999.0, 20 * 60), "bedtime",
			"bedtime is named first")
	# a pass lasts until the next 05:00
	eq(FamilyLimits.pass_until(1000000, 20 * 60), 1000000 + 9 * 3600, "20:00 -> 05:00")
	eq(FamilyLimits.pass_until(1000000, 2 * 60, 30), 1000000 + 3 * 3600 - 30, "02:00:30 -> 05:00")
	eq(FamilyLimits.pass_until(1000000, 5 * 60), 1000000 + 24 * 3600, "05:00 -> the next one")
	return true


# --- the state file and the token -----------------------------------------------------

func test_state_round_trip_and_drop() -> bool:
	var s := FamilyState.fresh()
	var done: Dictionary = JsonUtil.load_file("res://docs/contract/samples/api-pair.json")["pair_poll"]["response_done"]
	FamilyState.adopt_approved(s, done)
	eq(s["name"], "Kitchen tablet", "device name")
	eq(s["children"], [{"child": CHILD, "nickname": "Bear", "picture": "fox"}], "children")
	check(not s["consent"], "consent starts off")
	FamilyState.set_child(s, P1, CHILD)
	FamilyState.set_child(s, P2, "new")
	FamilyState.set_child(s, GUEST, "garbage")
	eq(FamilyState.child_of(s, P1), CHILD, "mapped")
	eq(FamilyState.child_of(s, P2), "new", "new child")
	eq(FamilyState.child_of(s, GUEST), null, "a bad id is not linked")
	s["sent"] = 99
	s["consent"] = true
	var back := FamilyState.from_text(FamilyState.to_text(s))
	eq(back, s, "round trip")
	eq(FamilyState.from_text("{broken"), FamilyState.fresh(), "a broken file is a fresh state")
	eq(FamilyState.from_text('{"sent": "x", "consent": 1}')["sent"], 0, "wrong types take defaults")
	FamilyState.drop(s)
	eq(s["family"], "", "dropped")
	check(not s["consent"], "consent goes with the family")
	check(s["map"].is_empty() and s["children"].is_empty() and s["settings"].is_empty(), "the family's things go")
	eq(s["sent"], 99, "the upload position stays")
	return true


func test_token_tied_to_device_and_server() -> bool:
	var base := "https://example.invalid/v1"
	var text := FamilyState.token_text("dt_abc", DEV, base, 5)
	eq(FamilyState.token_from_text(text, DEV, base), "dt_abc", "this device, this server")
	eq(FamilyState.token_from_text(text, DEV, base + "/"), "dt_abc", "trailing slash")
	eq(FamilyState.token_from_text(text, "d_00c0ffee00c0ffee", base), "", "copied to another tablet")
	eq(FamilyState.token_from_text(text, DEV, "https://other.invalid/v1"), "", "another server")
	eq(FamilyState.token_from_text("", DEV, base), "", "no file")
	return true


func test_profile_items_and_adopting_answers() -> bool:
	var s := FamilyState.fresh()
	s["children"] = [{"child": CHILD, "nickname": "Bear", "picture": "fox"}]
	var roster := [{"id": P1, "nickname": "Bear", "picture": "fox", "guest": false},
			{"id": P2, "nickname": "Wren", "picture": "bunny", "guest": false},
			{"id": GUEST, "nickname": "Guest", "picture": "slime_knight", "guest": true}]
	FamilyState.set_child(s, P1, CHILD)
	FamilyState.set_child(s, P2, "new")
	var items := FamilyState.profile_items(s, roster)
	eq(items, [{"profile": P1, "child": CHILD, "nickname": "Bear", "picture": "fox", "guest": false},
			{"profile": P2, "child": "new", "nickname": "Wren", "picture": "bunny", "guest": false}],
			"every child profile with its pick; the Guest never goes")
	var c2 := "c_00000000beef"
	var answer := {"profiles": [{"profile": P1, "child": CHILD, "nickname": "Bear", "picture": "fox", "guest": false},
			{"profile": P2, "child": c2, "nickname": "Wren", "picture": "bunny", "guest": false}],
			"children": [{"child": CHILD, "nickname": "Bear", "picture": "fox"}, {"child": c2, "nickname": "Wren", "picture": "bunny"}],
			"created": [{"profile": P2, "child": c2}]}
	var restore := FamilyState.adopt_profiles(s, answer)
	eq(FamilyState.child_of(s, P2), c2, "the made child")
	eq(restore, [], "a brand new child has nothing to restore")
	eq(FamilyState.mapped_children(s), [CHILD, c2], "mapped children")
	# a child removed on the web: its profile row comes back with child null
	var later := {"profiles": [{"profile": P1, "child": null, "guest": false}],
			"children": [{"child": c2, "nickname": "Wren", "picture": "bunny"}]}
	FamilyState.adopt_profiles(s, later)
	eq(FamilyState.child_of(s, P1), null, "not linked any more")
	# linking a profile to an existing child asks for a restore
	s["map"][P1] = null
	restore = FamilyState.adopt_profiles(s, {"profiles": [{"profile": P1, "child": c2}], "children": later["children"]})
	eq(restore, [P1], "newly mapped to a child with a history")
	FamilyState.note_guests(s, roster)
	eq(s["guests"], [GUEST], "Guest ids remembered")
	return true
