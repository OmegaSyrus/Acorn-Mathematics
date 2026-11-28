## The play log: what the child answered, right or wrong, kept on the tablet
## for a parent report later. Append-only JSON lines in user://play_log.jsonl,
## one line per answered question and one per run event (run start, a heart
## lost, a restart, a level cleared, a boss won or lost, the app paused or
## resumed). At about 1 MB the file moves to play_log.1.jsonl (the one before
## that is dropped) and a new one starts. Once the tablet is paired with a
## family (addons/acorn_family), keep_after is the upload position: a full
## file that still holds unsent lines is never dropped, older ones move up
## to play_log.2.jsonl and on (at most MAX_KEPT files), and the uploader reads
## them all (log_files).
##
## The entry builders are pure static functions (tests/test_play_log.gd);
## answer() and event() add the time and the place set by main.gd and write.
##
## Version 2 lines (family.event, docs/contract/schemas/event.v2.schema.json)
## add the game, this install's device id, a sequence number that counts up
## per device (so an upload sent twice is harmless), the launch count and
## milliseconds since launch (order when the clock is wrong), the build and
## content versions, and a skill id on every answer (logic/core/skills.gd).
extends RefCounted

const Attack := preload("res://logic/fight/attack.gd")
const BuildInfo := preload("res://logic/core/build_info.gd")
const Skills := preload("res://logic/core/skills.gd")

const VERSION := 2
const MAX_BYTES := 1000000
## Rotated files kept while lines in them wait to be sent (about 8 MB).
const MAX_KEPT := 8
const DEFAULT_PATH := "user://play_log.jsonl"

## Where lines go. Tests point it at a temp file.
static var path := DEFAULT_PATH
static var enabled := true
## {profile, world, area, level, level_id}: who is playing and where.
static var place := {}
## This install (game/device_id.gd) and its launch count; start() sets them.
static var dev := ""
static var boot := 0
## The last sequence number written on this device.
static var seq := 0
## Lines after this seq wait for upload and are never rotated away; -1 when
## the tablet is not paired (the family add-on sets it).
static var keep_after := -1


# --- what the game calls ---------------------------------------------------

## At launch: the device, its launch count, and the sequence carried on from
## the last line already in the log.
static func start(device_id: String, launch: int) -> void:
	dev = device_id
	boot = launch
	seq = maxi(last_seq(path), last_seq(rotated_path(path)))

static func set_profile(profile: String) -> void:
	place["profile"] = profile


## The world, area and level being played (main.gd, as each one starts).
static func set_place(area: Dictionary, level_id: int, level_num: int) -> void:
	place["world"] = str(area.get("world", area.get("id", "")))
	place["area"] = str(area.get("id", ""))
	place["level"] = level_num
	place["level_id"] = level_id


## One answered question. where: stone, fight, duel or boss. shown: what the
## child saw (stone_shown, fight_shown, boss_shown). answer and pick are
## the numbers; secs is how long the choices were up before the pick.
static func answer(where: String, shown: Dictionary, right_answer: int, pick: int, secs: float) -> void:
	if enabled:
		write(answer_entry(now(), _ctx(), where, shown, right_answer, pick, secs))


static func event(name: String, extra := {}) -> void:
	if enabled:
		write(event_entry(now(), _ctx(), name, extra))


## The place plus this device's next sequence number.
static func _ctx() -> Dictionary:
	var c := place.duplicate()
	if dev != "":
		seq += 1
		c["dev"] = dev
		c["seq"] = seq
		c["boot"] = boot
		c["mono_ms"] = Time.get_ticks_msec()
	return c


static func now() -> int:
	return int(Time.get_unix_time_from_system())


static func write(entry: Dictionary) -> void:
	if enabled:
		append(to_line(entry), path)


# --- pure: building the lines ----------------------------------------------

static func answer_entry(t: int, ctx: Dictionary, where: String, shown: Dictionary, right_answer: int,
		pick: int, secs: float) -> Dictionary:
	var e := _head(t, ctx, "answer")
	e["where"] = where
	e.merge(shown)
	e["answer"] = right_answer
	e["pick"] = pick
	e["right"] = pick == right_answer
	e["secs"] = snappedf(maxf(0.0, secs), 0.1)
	e["skill"] = Skills.of(where, shown, right_answer)
	return e


static func event_entry(t: int, ctx: Dictionary, name: String, extra := {}) -> Dictionary:
	var e := _head(t, ctx, "event")
	e["event"] = name
	e.merge(extra)
	return e


static func _head(t: int, ctx: Dictionary, kind: String) -> Dictionary:
	var e := {"v": VERSION, "game": BuildInfo.GAME, "kind": kind}
	for k in ["dev", "profile", "seq", "boot"]:
		if ctx.has(k):
			e[k] = ctx[k]
	e["t"] = t
	if ctx.has("mono_ms"):
		e["mono_ms"] = ctx["mono_ms"]
	e["app"] = BuildInfo.APP
	e["code"] = BuildInfo.CODE
	e["cv"] = BuildInfo.cv()
	for k in ["world", "area", "level", "level_id"]:
		if ctx.has(k):
			e[k] = ctx[k]
	return e


## One line of JSON, keys in the order they were added.
static func to_line(entry: Dictionary) -> String:
	return JSON.stringify(entry, "", false)


## A crossing roll (ScrollRun / LevelGen / MoveGen problem): "3 + 2 = ?", or
## "3 + ? = 5" when one die lies face down.
static func stone_shown(problem: Dictionary) -> Dictionary:
	var dice: Array = problem.get("dice", [])
	var op := str(problem.get("op", "add"))
	var signs := str(problem.get("signs", "+" + ("-" if op == "sub" else "+")))
	var hidden := int(problem.get("hidden", -1))
	var q := ""
	for i in dice.size():
		if i > 0:
			q += " %s " % (signs[i] if i < signs.length() else "+")
		q += "?" if i == hidden else str(dice[i])
	q += " = " + (str(problem.get("total", "?")) if hidden >= 0 else "?")
	var out := {"q": q, "op": op, "dice": dice.duplicate()}
	if hidden >= 0:
		out["hidden"] = hidden
	out["choices"] = problem.get("choices", []).duplicate()
	return out


## A fight or duel swing (Attack): one die to count, two to add, die + ? =
## target, or a move die minus a slip die.
static func fight_shown(attack, phase: String) -> Dictionary:
	var d: Array = Array(attack.dice)
	var q := ""
	match attack.kind:
		Attack.Kind.ONE_DIE:
			q = "count %d" % d[0]
		Attack.Kind.TWO_DICE:
			q = "%d + %d = ?" % [d[0], d[1]]
		Attack.Kind.DIE_AND_TARGET:
			q = "%d + ? = %d" % [d[0], attack.target]
		Attack.Kind.MOVE_AND_SLIP:
			q = "%d - %d = ?" % [d[0], d[1]]
	return {"q": q, "phase": phase, "dice": d, "choices": Array(attack.choices)}


## A boss shot (BounceFight): the boss's number, the ball's die (above
## Acorn) and the peg faces offered.
static func boss_shown(fight) -> Dictionary:
	return {"q": "match %d" % fight.target if fight.rule == "match" else "%s %d ball %d" % [fight.rule, fight.target, fight.ball_value],
			"rule": fight.rule, "target": fight.target, "ball": fight.ball_value, "choices": Array(fight.choices)}


# --- the file ----------------------------------------------------------------

## The "seq" of the last line in a log file, 0 if none (read from its end).
static func last_seq(p: String) -> int:
	if not FileAccess.file_exists(p):
		return 0
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return 0
	var n := f.get_length()
	f.seek(maxi(0, n - 4096))
	var tail := f.get_buffer(mini(n, 4096)).get_string_from_utf8()
	f.close()
	var lines := tail.split("\n", false)
	for i in range(lines.size() - 1, -1, -1):
		var d = JSON.parse_string(lines[i])
		if d is Dictionary and d.has("seq"):
			return int(d["seq"])
	return 0

static func rotated_path(p: String) -> String:
	return kept_path(p, 1)


## The n-th rotated file: play_log.1.jsonl is the newest, .2 the one before.
static func kept_path(p: String, n: int) -> String:
	return p.get_basename() + ".%d." % n + p.get_extension()


## Every play log file there is, oldest first (the uploader reads them all).
static func log_files(p := DEFAULT_PATH) -> Array:
	var out := []
	for n in range(MAX_KEPT, 0, -1):
		if FileAccess.file_exists(kept_path(p, n)):
			out.append(kept_path(p, n))
	if FileAccess.file_exists(p):
		out.append(p)
	return out


## Moves a full log aside. The old .1 is dropped unless it still holds lines
## after keep_after; then the kept files move up one (.1 to .2 and on, the
## oldest past MAX_KEPT dropped). Kept files whose lines are all sent go.
static func rotate(at: String) -> void:
	var old := rotated_path(at)
	if FileAccess.file_exists(old):
		if keep_after >= 0 and last_seq(old) > keep_after:
			if FileAccess.file_exists(kept_path(at, MAX_KEPT)):
				DirAccess.remove_absolute(kept_path(at, MAX_KEPT))
			for n in range(MAX_KEPT - 1, 0, -1):
				if FileAccess.file_exists(kept_path(at, n)):
					DirAccess.rename_absolute(kept_path(at, n), kept_path(at, n + 1))
		else:
			DirAccess.remove_absolute(old)
	for n in range(2, MAX_KEPT + 1):
		var k := kept_path(at, n)
		if FileAccess.file_exists(k) and (keep_after < 0 or last_seq(k) <= keep_after):
			DirAccess.remove_absolute(k)
	DirAccess.rename_absolute(at, old)


## Appends one line; moves a full file aside first.
static func append(line: String, at := DEFAULT_PATH) -> void:
	var size := 0
	if FileAccess.file_exists(at):
		var r := FileAccess.open(at, FileAccess.READ)
		if r != null:
			size = r.get_length()
			r.close()
	if size > 0 and size + line.length() + 1 > MAX_BYTES:
		rotate(at)
		size = 0
	var f := FileAccess.open(at, FileAccess.READ_WRITE if size > 0 else FileAccess.WRITE)
	if f == null:
		push_warning("play log: %s" % error_string(FileAccess.get_open_error()))
		return
	f.seek_end()
	f.store_line(line)
	f.close()
