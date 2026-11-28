## Parent limits, the pure part: the child_game settings daily_minutes
## (0 to 240 minutes a day, 0 = no limit) and bedtime ("HH:MM", or null for
## none) from family.settings (settings.v1.schema.json), minutes played per
## profile per local day, and whether it is time to stop.
##
## Bedtime: from that time until MORNING (05:00) it is night. A bedtime
## after midnight (00:30) means 00:30 to 05:00. A grown-up's pass (the PIN on
## the rest screen) lasts until the next 05:00.
extends RefCounted

const MAX_MINUTES := 240
const MORNING := 5 * 60

## Nothing set, nothing enforced.
const NO_LIMITS := {"daily_minutes": 0, "bedtime": null}


## The limits in a family.settings document. Unknown keys are ignored, a bad
## value counts as not set.
static func parse_settings(doc: Variant) -> Dictionary:
	var out := NO_LIMITS.duplicate()
	if not (doc is Dictionary) or not (doc.get("fields") is Dictionary):
		return out
	var fields: Dictionary = doc["fields"]
	var dm = _value(fields, "daily_minutes")
	if (typeof(dm) == TYPE_INT or typeof(dm) == TYPE_FLOAT) and float(dm) == floorf(float(dm)):
		var m := int(dm)
		if m >= 0 and m <= MAX_MINUTES:
			out["daily_minutes"] = m
	var bt = _value(fields, "bedtime")
	if bt is String and parse_hhmm(bt) >= 0:
		out["bedtime"] = bt
	return out


static func _value(fields: Dictionary, key: String) -> Variant:
	var f = fields.get(key)
	if f is Dictionary:
		return f.get("value")
	return null


## "19:30" -> 1170 (minutes after midnight), -1 when not HH:MM.
static func parse_hhmm(s: String) -> int:
	var re := RegEx.new()
	re.compile("^([01][0-9]|2[0-3]):([0-5][0-9])$")
	var m := re.search(s)
	if m == null:
		return -1
	return int(m.get_string(1)) * 60 + int(m.get_string(2))


## True when minute_of_day (local) is at or past bedtime and before morning.
static func is_night(minute_of_day: int, bedtime: Variant) -> bool:
	if not (bedtime is String):
		return false
	var b := parse_hhmm(bedtime)
	if b < 0:
		return false
	if b >= MORNING:
		return minute_of_day >= b or minute_of_day < MORNING
	return minute_of_day >= b and minute_of_day < MORNING


## Why play stops now: "bedtime", "daily" or "" (play on).
## used_secs: seconds played today; passed: a grown-up let them go on.
static func stop_reason(limits: Dictionary, used_secs: float, minute_of_day: int, passed := false) -> String:
	if passed:
		return ""
	if is_night(minute_of_day, limits.get("bedtime")):
		return "bedtime"
	var m := int(limits.get("daily_minutes", 0))
	if m > 0 and used_secs >= m * 60.0:
		return "daily"
	return ""


## Minutes left today (-1 for no limit).
static func minutes_left(limits: Dictionary, used_secs: float) -> int:
	var m := int(limits.get("daily_minutes", 0))
	if m <= 0:
		return -1
	return maxi(0, int(ceil(m - used_secs / 60.0)))


# --- time played -----------------------------------------------------------------
# playtime: {"date": "YYYY-MM-DD" (local), "secs": {profile: seconds}}. A new
# day starts from zero.

static func add_play(playtime: Dictionary, date: String, profile: String, secs: float) -> void:
	if profile == "" or secs <= 0.0:
		return
	if str(playtime.get("date", "")) != date or not (playtime.get("secs") is Dictionary):
		playtime["date"] = date
		playtime["secs"] = {}
	var by: Dictionary = playtime["secs"]
	by[profile] = float(by.get(profile, 0.0)) + secs


static func used(playtime: Dictionary, date: String, profile: String) -> float:
	if str(playtime.get("date", "")) != date or not (playtime.get("secs") is Dictionary):
		return 0.0
	return float(playtime["secs"].get(profile, 0.0))


## When a grown-up's pass given now runs out: the next MORNING, local time.
## now_unix and the local minute and second of the day it is now.
static func pass_until(now_unix: int, minute_of_day: int, second := 0) -> int:
	var since_midnight := minute_of_day * 60 + second
	var morning := MORNING * 60
	var wait := morning - since_midnight
	if wait <= 0:
		wait += 24 * 3600
	return now_unix + wait


## "YYYY-MM-DD" from Time.get_datetime_dict_from_system().
static func date_of(dt: Dictionary) -> String:
	return "%04d-%02d-%02d" % [int(dt.get("year", 0)), int(dt.get("month", 0)), int(dt.get("day", 0))]
