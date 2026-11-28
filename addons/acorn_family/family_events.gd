## Play log upload, the pure part (api-v1.md, Events): which lines go,
## in which batch, under which range name, and what to do when the server
## refuses one. family.gd reads the files and sends.
##
## The upload position ("sent") is the last seq dealt with: every line at or
## below it was stored by the server, or never goes (a Guest's line, another
## device's line, a line the server refused alone). It moves only after a
## 2xx. A batch about to go is kept as "inflight" {first, last, advance}
## before it is sent, so after a crash or a lost answer the same range goes
## again and the server answers "duplicate" instead of storing it twice.
extends RefCounted

const FamilyApi := preload("res://addons/acorn_family/family_api.gd")

const MAX_LINES := 500
## Text bytes per batch (the server takes 4 MB of text, 256 KB gzipped;
## play log lines pack about 10 to 1).
const MAX_BYTES := 600000


## Every line after `after` in the files (oldest file first), as
## {seq, profile, dev, v, text}, in seq order. Lines without a whole seq
## are left out (version 1 lines never upload).
static func read_lines(paths: Array, after: int) -> Array:
	var out := []
	for p in paths:
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		while not f.eof_reached():
			var line := f.get_line().strip_edges()
			if line == "":
				continue
			var item := parse_line(line)
			if not item.is_empty() and int(item["seq"]) > after:
				out.append(item)
		f.close()
	out.sort_custom(func(a, b): return int(a["seq"]) < int(b["seq"]))
	return out


## One line as {seq, profile, dev, v, text}, or {} when it has no seq.
static func parse_line(line: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(line) != OK:
		return {}
	var d = json.data
	if not (d is Dictionary):
		return {}
	var s = d.get("seq")
	if typeof(s) != TYPE_FLOAT and typeof(s) != TYPE_INT:
		return {}
	if float(s) != floorf(float(s)) or float(s) < 1:
		return {}
	return {"seq": int(s), "profile": str(d.get("profile", "")), "dev": str(d.get("dev", "")),
			"v": int(d.get("v", 0)) if (typeof(d.get("v")) == TYPE_FLOAT or typeof(d.get("v")) == TYPE_INT) else 0,
			"text": line,
			# "Who is playing?" picked the Guest: that profile never syncs
			"guest": str(d.get("event", "")) == "profile_picked" and d.get("guest") == true}


## True when this line may go to the server: this device's, not a Guest's,
## and a version 2 line has a real profile id (the server checks v2 lines
## against the schema and would refuse the whole batch).
static func sendable(item: Dictionary, dev: String, guests: Array) -> bool:
	if str(item.get("dev", "")) != dev:
		return false
	var profile := str(item.get("profile", ""))
	if guests.has(profile):
		return false
	if int(item.get("v", 0)) == 2 and not FamilyApi.is_id(profile, FamilyApi.PROFILE):
		return false
	return true


## The next batch: {first, last, advance, lines: [text]}. lines empty means
## nothing to send, only move the position to advance (Guest lines and the
## like). With an inflight batch, exactly its range again.
static func plan(items: Array, sent: int, dev: String, guests: Array, inflight := {},
		max_lines := MAX_LINES, max_bytes := MAX_BYTES) -> Dictionary:
	guests = with_logged_guests(items, guests)
	if not inflight.is_empty():
		var again := []
		for it in items:
			var s := int(it["seq"])
			if s >= int(inflight["first"]) and s <= int(inflight["last"]) and sendable(it, dev, guests):
				again.append(it["text"])
		return {"first": int(inflight["first"]), "last": int(inflight["last"]),
				"advance": int(inflight.get("advance", inflight["last"])), "lines": again}
	var lines := []
	var first := 0
	var last := 0
	var advance := sent
	var bytes := 0
	for it in items:
		var s := int(it["seq"])
		if s <= sent:
			continue
		if not sendable(it, dev, guests):
			advance = s
			continue
		var n: int = it["text"].length() + 1
		if not lines.is_empty() and (lines.size() >= max_lines or bytes + n > max_bytes):
			break
		if lines.is_empty():
			first = s
		lines.append(it["text"])
		last = s
		advance = s
		bytes += n
	return {"first": first, "last": last, "advance": advance, "lines": lines}


## The Guest ids given plus any the log itself names (a profile_picked
## line with guest true), so a Guest made since the roster was read never
## slips through.
static func with_logged_guests(items: Array, guests: Array) -> Array:
	var out := guests.duplicate()
	for it in items:
		if bool(it.get("guest", false)) and not out.has(it["profile"]):
			out.append(it["profile"])
	return out


## The inflight record for a planned batch.
static func inflight_of(batch: Dictionary) -> Dictionary:
	return {"first": int(batch["first"]), "last": int(batch["last"]), "advance": int(batch["advance"])}


## The server refused a batch as it is (400 or 413). Several lines: send the
## first half alone next (its own, smaller range). One line: it never goes;
## the position moves past it. Returns {inflight, sent, skipped}.
static func after_refusal(items: Array, batch: Dictionary, sent: int, dev: String, guests: Array) -> Dictionary:
	guests = with_logged_guests(items, guests)
	var seqs := []
	for it in items:
		var s := int(it["seq"])
		if s >= int(batch["first"]) and s <= int(batch["last"]) and sendable(it, dev, guests):
			seqs.append(s)
	if seqs.size() <= 1:
		return {"inflight": {}, "sent": maxi(sent, int(batch["advance"])), "skipped": seqs.size()}
	var half: int = seqs[seqs.size() / 2 - 1]
	return {"inflight": {"first": int(seqs[0]), "last": half, "advance": half}, "sent": sent, "skipped": 0}


## The request body: one line each, ending in a newline.
static func body_text(lines: Array) -> String:
	return "\n".join(PackedStringArray(lines)) + "\n"


## The body as bytes, gzipped when asked (Content-Encoding: gzip).
static func pack(text: String, gzip: bool) -> PackedByteArray:
	var raw := text.to_utf8_buffer()
	if not gzip:
		return raw
	var z := raw.compress(FileAccess.COMPRESSION_GZIP)
	return z if not z.is_empty() else raw
