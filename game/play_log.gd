## The play log: what the child answered, right or wrong, kept on the tablet
## for a parent report later. Append-only JSON lines in user://play_log.jsonl,
## one line per answered question and one per run event (run start, a heart
## lost, a restart, a level cleared, a boss won or lost, the app paused or
## resumed). Nothing is sent anywhere. At about 1 MB the file moves to
## play_log.1.jsonl (the one before that is dropped) and a new one starts.
##
## The entry builders are pure static functions (tests/test_play_log.gd);
## answer() and event() add the time and the place set by main.gd and write.
extends RefCounted

const Attack := preload("res://logic/fight/attack.gd")

const VERSION := 1
const MAX_BYTES := 1000000
const DEFAULT_PATH := "user://play_log.jsonl"

## Where lines go. Tests point it at a temp file.
static var path := DEFAULT_PATH
static var enabled := true
## {profile, world, area, level, level_id}: who is playing and where.
static var place := {}


# --- what the game calls ---------------------------------------------------

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
	write(answer_entry(now(), place, where, shown, right_answer, pick, secs))


static func event(name: String, extra := {}) -> void:
	write(event_entry(now(), place, name, extra))


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
	return e


static func event_entry(t: int, ctx: Dictionary, name: String, extra := {}) -> Dictionary:
	var e := _head(t, ctx, "event")
	e["event"] = name
	e.merge(extra)
	return e


static func _head(t: int, ctx: Dictionary, kind: String) -> Dictionary:
	var e := {"v": VERSION, "t": t, "kind": kind}
	for k in ["profile", "world", "area", "level", "level_id"]:
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

static func rotated_path(p: String) -> String:
	return p.get_basename() + ".1." + p.get_extension()


## Appends one line; moves a full file aside first.
static func append(line: String, at := DEFAULT_PATH) -> void:
	var size := 0
	if FileAccess.file_exists(at):
		var r := FileAccess.open(at, FileAccess.READ)
		if r != null:
			size = r.get_length()
			r.close()
	if size > 0 and size + line.length() + 1 > MAX_BYTES:
		var old := rotated_path(at)
		if FileAccess.file_exists(old):
			DirAccess.remove_absolute(old)
		DirAccess.rename_absolute(at, old)
		size = 0
	var f := FileAccess.open(at, FileAccess.READ_WRITE if size > 0 else FileAccess.WRITE)
	if f == null:
		push_warning("play log: %s" % error_string(FileAccess.get_open_error()))
		return
	f.seek_end()
	f.store_line(line)
	f.close()
