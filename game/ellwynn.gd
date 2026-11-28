## Ellwynn, the companion (docs/ellwynn-intro.md). Autoloaded as Ellwynn.
## Mostly a voice (Terrence 2026-11-06). She is seen in three places:
##   - the main menu: her full body stands bottom left, bobs, blinks and talks
##     (mouth frames follow the loudness of her voice); tap her to hear her again;
##   - an enemy win: 1 time in 3 her portrait pops up in the corner with a "Yay!";
##   - a region boss win: her full body slides in to congratulate the player.
## Chests get her voice only.
##
## Cues (Phase 3, 2026-11-28): every place she speaks has a cue id from the
## lines sheet, listed in content/ellwynn_cues.json. A cue plays a recorded
## file dropped into audio/voice/lines/ named by its id (T2.mp3, P3.mp3,
## P3_2.mp3 ...; docs/voice-drop-in.md). With no file it falls back as the
## list says: a placeholder ("Yay!"), the tablet's own text-to-speech reading
## the stand-in words (Debug > Voice turns that off), or quiet. Older cue
## names (intro, welcome, play, shop, enemy, chest, boss_win, count_then ...)
## are aliases; content/ellwynn_lines.json still holds the placeholders, the
## number takes and any lines listed by hand.
## Draws in the 960x540 design space: main.gd keeps `offset` on the stage's.
extends CanvasLayer

const SaveStoreRef := preload("res://game/save_store.gd")
const Pointer := preload("res://game/ui/pointer.gd")
const LINES_PATH := "res://content/ellwynn_lines.json"
const CUES_PATH := "res://content/ellwynn_cues.json"
## Recorded lines are dropped in here, named by cue id (docs/voice-drop-in.md).
const DROP_DIR := "res://audio/voice/lines/"
const AUDIO_EXT := ["ogg", "mp3", "wav"]
## Her settings for the whole tablet (not per child).
const SETTINGS_PATH := "user://ellwynn_settings.json"
## Text-to-speech stand-in: a little higher and slower than the default.
const TTS_PITCH := 1.25
const TTS_RATE := 0.9
const WOOHOO := "res://audio/voice/ellwynn/placeholder-woohoo.mp3"
## Mouth tracks made from each voice file by tools/voice/mouth_tracks.py.
const MOUTH_PATH := "res://content/ellwynn_mouth.json"
const MOUTH_NAMES := ["closed", "half", "open"]
const FRAMES := {
	"closed": preload("res://art/ellwynn/fullbody-closed.png"),
	"half": preload("res://art/ellwynn/fullbody-mouth-half.png"),
	"open": preload("res://art/ellwynn/fullbody-mouth-open.png"),
	"blink": preload("res://art/ellwynn/fullbody-blink.png"),
}
const BUST := preload("res://art/ellwynn/bust-96.png")

## Full body, 1 art pixel = 1 unit (never scaled), feet on the bottom edge.
const MENU_POS := Vector2(130, 284)
const BODY_SIZE := Vector2(160, 256)
## The part of the image she covers (bounding box of the art), for taps.
const BODY_TAP := Rect2(9, 6, 135, 250)
## The pop-in portrait: bottom left of the 4:3 band, in a gold frame.
const POP_POS := Vector2(132, 420)
const POP_PAD := 4.0
## The answer pop-in after a wrong guess: top left, just below the hearts
## (Terrence 2026-11-12), clear of the fight's shields and the crossing's
## stones, sliding in from the left.
const ANSWER_POS := Vector2(132, 62)
## How often an enemy win brings the pop-in (Terrence 2026-11-07: 1 in 3).
const POP_CHANCE := 1.0 / 3.0
## Chests: a voice line on most, not all, so it stays special.
const CHEST_CHANCE := 2.0 / 3.0
## Music dips by this much while she talks.
const DUCK_DB := 10.0
## The right answer after a wrong guess: said this long after the guess, with
## the music dipped this much (it must be heard over the game).
const ANSWER_DELAY := 1.0
const ANSWER_DUCK_DB := 18.0
## Counting on after a wrong guess (Phase 2, logic/core/count_help.gd): one
## number this often, each cutting off the one before; the number takes
## start this far in, past their quiet lead-in. A "then" with no recording
## is a short beat instead; one with a recording gets its own length, within
## THEN_MAX_S. The last number gets COUNT_TAIL_S before the count is done.
const COUNT_STEP_S := 0.5
const COUNT_SKIP_S := 0.15
const THEN_GAP_S := 0.25
const THEN_MAX_S := 1.0
const COUNT_TAIL_S := 0.6
## Loudness (linear magnitude) for the half and open mouth.
const HALF_AT := 0.012
const OPEN_AT := 0.035

const INK := Color(0.96, 0.94, 0.9)
const DARK := Color(0.07, 0.04, 0.08)
const GOLD := Color(1.0, 0.82, 0.35)

var mode := "off"          # "off", "menu", "pop", "answer", "boss"
var bubble := ""
var player: AudioStreamPlayer
var lines: Dictionary = {}
var mouth_tracks: Dictionary = {}
var mouth_fps := 15.0
var _cur_file := ""
## Time into the line, kept by us so the mouth moves even with the sound off.
var _line_t := 0.0
var _line_len := 0.0
var rng := RandomNumberGenerator.new()
## The cue list by id (content/ellwynn_cues.json) and old names to ids.
var cues: Dictionary = {}
var aliases: Dictionary = {}
## Dropped-in files: lower-case base name ("p3_2") to res:// path.
var drop_files: Dictionary = {}
## The tablet's text-to-speech reads the stand-in words of a cue with no
## recording (fallback "tts"). Off in Debug > Voice; off with no TTS voice.
var stand_in_voice := true
## The last prompt said (prompt()), so a tap on the talk box says it again.
var last_prompt := ""
## The active child's save (taught first turn flags), set by use_save().
var _save_ref: Dictionary = {}
var _last_pick: Dictionary = {}   # cue id -> file played last, to avoid repeats
var _tts_voice := ""
var _tts_until := 0.0             # Time (s) her stand-in voice should be done by

var _fig: Node2D
var _queue: Array = []     # [{file, bubble}] still to play
var _mouth := "closed"
var _blink_in := 3.0
var _blinking := 0.0
var _t := 0.0
var _slide := 0.0          # 0 hidden .. 1 in place (pop and boss)
var _hop := 0.0
var _analyzer: AudioEffectSpectrumAnalyzerInstance
var _save: Dictionary = {}
var _gen := 0              # bumps when a show ends, so old timers do nothing
var _answer_token := 0     # bumps on every stop, so a waiting answer is dropped
var _count_token := -1     # the _answer_token of the count running now, -1 none


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	lines = _load_lines()
	_load_cues()
	scan_drop_folder()
	_load_settings()
	_load_mouth()
	_setup_bus()
	player = AudioStreamPlayer.new()
	player.bus = "Voice"
	add_child(player)
	player.finished.connect(_on_finished)
	_fig = Node2D.new()
	_fig.draw.connect(_draw_fig)
	add_child(_fig)


func _load_lines() -> Dictionary:
	var f := FileAccess.open(LINES_PATH, FileAccess.READ)
	if f == null:
		return {"placeholders": [], "cues": {}}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {"placeholders": [], "cues": {}}


func _load_cues() -> void:
	cues.clear()
	aliases.clear()
	var f := FileAccess.open(CUES_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return
	for c in data.get("cues", []):
		if c is Dictionary and c.has("id"):
			cues[String(c["id"])] = c
			if c.has("alias"):
				aliases[String(c["alias"])] = String(c["id"])


## Finds the recorded lines dropped into DROP_DIR. Names are matched without
## case, so "t2.MP3" counts for T2. Lists imported resources, so it works in
## an exported build too.
func scan_drop_folder(dir := DROP_DIR) -> void:
	drop_files.clear()
	var names := PackedStringArray()
	if ResourceLoader.has_method("list_directory"):
		names = ResourceLoader.call("list_directory", dir)
	else:
		names = DirAccess.get_files_at(dir)
	for n in names:
		var ext := n.get_extension().to_lower()
		if ext in AUDIO_EXT:
			drop_files[n.get_basename().to_lower()] = dir.path_join(n)


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if data is Dictionary:
			stand_in_voice = bool(data.get("stand_in_voice", true))


func set_stand_in_voice(on: bool) -> void:
	stand_in_voice = on
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"stand_in_voice": on}))
	if not on:
		_tts_stop()


func _load_mouth() -> void:
	var f := FileAccess.open(MOUTH_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		mouth_tracks = data.get("tracks", {})
		mouth_fps = float(data.get("fps", 15))


## The mouth frame for now: from the line's track when it has one, otherwise
## from the live loudness of her bus.
func _mouth_now() -> String:
	if not is_talking():
		return "closed"
	var tr: String = mouth_tracks.get(_cur_file, "")
	if tr != "":
		var pos := _line_t
		var i := int(pos * mouth_fps)
		if i >= 0 and i < tr.length():
			return MOUTH_NAMES[int(tr[i])]
		return "closed"
	if _tts_talking() and not player.playing:
		# the stand-in voice isn't on her bus: a simple flap
		return ["half", "open", "half", "closed"][int(_t * 9.0) % 4]
	if player.playing and _analyzer != null:
		var mag := _analyzer.get_magnitude_for_frequency_range(150.0, 4000.0).length()
		if mag > OPEN_AT:
			return "open"
		if mag > HALF_AT:
			return "half"
	return "closed"


## Her own bus, so the mouth can follow her voice alone.
func _setup_bus() -> void:
	var idx := AudioServer.get_bus_index("Voice")
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Voice")
		AudioServer.set_bus_send(idx, "Master")
		var spec := AudioEffectSpectrumAnalyzer.new()
		spec.buffer_length = 0.1
		AudioServer.add_bus_effect(idx, spec)
	_analyzer = AudioServer.get_bus_effect_instance(idx, 0) as AudioEffectSpectrumAnalyzerInstance


# --- what the game calls --------------------------------------------------

## The main menu opened. The first time ever she explains the game (cue
## "intro"), later she says a short welcome.
func menu_enter(save: Dictionary) -> void:
	_save = save
	use_save(save)
	_set_mode("menu")
	if not bool(save.get("ellwynn_intro_seen", false)):
		save["ellwynn_intro_seen"] = true
		SaveStoreRef.write(save)
		say("intro")
	else:
		say("welcome")


## Any screen other than the main menu: she steps out (her voice carries on).
func menu_leave() -> void:
	if mode == "menu":
		_set_mode("off")


## A button on the main menu was tapped: "play", "resume" or "shop".
func menu_tap(cue: String) -> void:
	_hop = 1.0
	say(cue)


## A monster was beaten: 1 time in 3 the quick pop-in with a "Yay!".
func enemy_beaten() -> void:
	if rng.randf() >= POP_CHANCE:
		return
	_set_mode("pop")
	say("enemy")
	var g := _gen
	await get_tree().create_timer(1.6, true, false, true).timeout
	if g == _gen and mode == "pop":
		_set_mode("off")


## A chest opened: voice only, on most chests.
func chest_opened() -> void:
	if rng.randf() < CHEST_CHANCE:
		say("chest")


## The region boss is beaten: she slides in to congratulate the player.
func boss_beaten(world_id := "") -> void:
	_set_mode("boss")
	say(world_cue("B2", world_id))
	var g := _gen
	await get_tree().create_timer(3.4, true, false, true).timeout
	if g == _gen and mode == "boss":
		_set_mode("off")


## A wrong guess: she says the right answer, cheerfully, from her portrait in
## the corner with the numeral in her bubble (Terrence 2026-11-07). Recorded
## 0 to 18 (2026-11-08); a number with no recording stays quiet.
## She waits ANSWER_DELAY first (Terrence 2026-11-08: 1 second later), so the
## "Oops!" blorp is over and she is heard on her own; the music dips further
## than for her other lines while she says it.
func say_answer(n: int) -> void:
	var file := answer_file(n)
	if file == "":
		push_warning("Ellwynn: no answer line for %d" % n)
		return
	stop_voice()
	var token := _answer_token
	await get_tree().create_timer(ANSWER_DELAY, true, false, true).timeout
	# a newer line (or a stop) came in while she waited
	if token != _answer_token:
		return
	_queue = [{"file": file, "bubble": str(n)}]
	if mode != "menu":
		_set_mode("answer")
	_next_line()
	_duck(ANSWER_DUCK_DB)
	var g := _gen
	await get_tree().create_timer(1.8, true, false, true).timeout
	if g == _gen and mode == "answer":
		_set_mode("off")


## A wrong guess with dice to count (Phase 2, 2026-11-28): after the same
## ANSWER_DELAY she counts on from the first die, "four, then five, six,
## seven", or back for a take-away, "six, then five, four", from her portrait
## with the running number in her bubble. steps is CountHelp.plan(); for
## each step she calls on_step(step) first, which lights that die or pip and
## returns false when the dice are gone (the crossing restarted, the fight
## moved on): the count then stops. No plan, or a number with no recording,
## and she says the answer as before (say_answer). Paced by timers, so it
## runs the same with the sound off; nothing waits on it unless it asks
## is_counting().
func say_counting(steps: Array, answer: int, on_step: Callable) -> void:
	if steps.is_empty() or not _has_numbers(steps):
		say_answer(answer)
		return
	stop_voice()
	var token := _answer_token
	_count_token = token
	await get_tree().create_timer(ANSWER_DELAY, true, false, true).timeout
	if token != _answer_token:
		return
	if mode != "menu":
		_set_mode("answer")
	var g := _gen
	var last := steps.size() - 1
	for k in steps.size():
		var st: Dictionary = steps[k]
		if not on_step.is_valid() or not bool(on_step.call(st)):
			# the dice are gone: stop cleanly
			if token == _answer_token:
				stop_voice()
			_portrait_off(g)
			return
		var wait := COUNT_STEP_S
		if st.has("n"):
			var n := int(st["n"])
			_play_now(_number_file(n), str(n), COUNT_SKIP_S)
		else:
			var line := _own_line(String(st.get("cue", "")))
			if line.is_empty():
				wait = THEN_GAP_S
			else:
				_play_now(String(line.get("file", "")), String(line.get("bubble", "")))
				wait = clampf(_line_len, COUNT_STEP_S, THEN_MAX_S)
		await get_tree().create_timer(wait if k < last else COUNT_TAIL_S, true, false, true).timeout
		if token != _answer_token:
			_portrait_off(g)
			return
	_count_token = -1
	await get_tree().create_timer(1.2, true, false, true).timeout
	_portrait_off(g)


## The answer portrait goes, unless a newer show took over (g is stale).
func _portrait_off(g: int) -> void:
	if g == _gen and mode == "answer":
		_set_mode("off")


## True while a count-on (say_counting) is waiting or counting.
func is_counting() -> bool:
	return _count_token >= 0 and _count_token == _answer_token


## Plays one of the cue's own lines, never a placeholder; false (and quiet)
## when the cue has no line yet. For lines that are better left unsaid than
## replaced with a "Yay!" (count_quiet).
func say_own(cue: String) -> bool:
	var line := _own_line(cue)
	if line.is_empty():
		return false
	stop_voice()
	_queue = [line]
	_next_line()
	return true


## A number said straight away, with no portrait and no bubble: the count
## as the child taps the pips on the crossing (Terrence 2026-11-17). A new
## number cuts off the one before.
func say_count(n: int) -> void:
	var file := _number_file(n)
	if file == "":
		push_warning("Ellwynn: no number line for %d" % n)
		return
	stop_voice()
	_queue = [{"file": file, "bubble": ""}]
	_next_line()
	_duck(ANSWER_DUCK_DB)


## A right guess (Terrence 2026-11-17): she says the right number straight
## away, while the hero moves on, and then celebrates with "Woo-hoo!", so
## the number always comes before the celebration.
func say_right(n: int) -> void:
	# the cheer after the number: a recorded C3 take, else "Woo-hoo!"
	var cheer := lines_for("C3")
	var line := [{"file": WOOHOO if cheer.is_empty() else String(cheer[rng.randi() % cheer.size()]["file"]), "bubble": ""}]
	var file := answer_file(n)
	if file != "":
		line.push_front({"file": file, "bubble": ""})
	stop_voice()
	_queue = line
	_next_line()
	_duck(ANSWER_DUCK_DB)


## Plays a cue by its sheet id ("T2") or old name ("intro"). An ordered cue
## (the intro) plays all its lines in turn; any other plays one at random,
## never the same take twice running. With no recording it falls back as
## content/ellwynn_cues.json says. True when something is said.
func say(cue: String) -> bool:
	return cue_play(cue)


func cue_play(cue: String) -> bool:
	var id := resolve(cue)
	var pick := lines_for(id)
	if pick.is_empty():
		return _fallback(id)
	var c: Dictionary = cues.get(id, {})
	if not bool(c.get("order", false)) and pick.size() > 1:
		var choices := pick.duplicate()
		var last: String = _last_pick.get(id, "")
		choices = choices.filter(func(l): return String(l["file"]) != last)
		if choices.is_empty():
			choices = pick
		pick = [choices[rng.randi() % choices.size()]]
		_last_pick[id] = String(pick[0]["file"])
	stop_voice()
	_queue = pick.duplicate()
	_next_line()
	return true


## A talk box prompt (the P cues, and any line that tells the child what to
## do): said now, and again when the talk box is tapped (replay_prompt).
func prompt(cue: String) -> bool:
	last_prompt = resolve(cue)
	return cue_play(cue)


func replay_prompt() -> bool:
	if last_prompt == "" or is_talking():
		return false
	return cue_play(last_prompt)


## Forgets the last prompt (a new screen with nothing to replay).
func clear_prompt() -> void:
	last_prompt = ""


## The active child's save: the taught first turn marks it (save["taught"]).
func use_save(save: Dictionary) -> void:
	_save_ref = save


## True once this child has heard a taught line (save["taught"][id]).
func was_taught(cue: String, save: Dictionary = {}) -> bool:
	var sv: Dictionary = save if not save.is_empty() else _save_ref
	var t = sv.get("taught", {})
	return t is Dictionary and bool(t.get(resolve(cue), false))


## The taught first turn (T cues) and first-time lines (N cues): plays the
## cue the first time this child gets here and marks it in the save, so it
## never plays again for them. False when already taught (nothing said).
## Also a prompt, so a tap on the talk box says it again.
func teach(cue: String, save: Dictionary = {}) -> bool:
	var sv: Dictionary = save if not save.is_empty() else _save_ref
	var id := resolve(cue)
	if was_taught(id, sv):
		return false
	if typeof(sv.get("taught")) != TYPE_DICTIONARY:
		sv["taught"] = {}
	sv["taught"][id] = true
	if sv.has("profile"):
		SaveStoreRef.write(sv)
	prompt(id)
	return true


## Waits until she has finished talking, or max_s at most. Use with await.
func wait_quiet(max_s := 8.0) -> void:
	var until := Time.get_ticks_msec() + int(max_s * 1000.0)
	await get_tree().process_frame
	while is_talking() and Time.get_ticks_msec() < until:
		await get_tree().process_frame


## The per-world cue: world_cue("B2", "crystal_mines") is "B2-crystal".
const WORLD_KEYS := {"lava_caves": "lava", "crystal_mines": "crystal", "bog": "bog",
		"mushroom_forest": "mushroom", "space": "space"}


static func world_cue(prefix: String, world_id: String) -> String:
	return "%s-%s" % [prefix, WORLD_KEYS.get(world_id, "lava")]


## A cue id from an id or an old name.
func resolve(cue: String) -> String:
	if cues.has(cue):
		return cue
	return String(aliases.get(cue, cue))


## The recorded lines of a cue, in order: dropped-in files first (id, id_2,
## id_3 ...), else the ones listed in content/ellwynn_lines.json under its id
## or old name. [] when it has none.
func lines_for(cue: String) -> Array:
	var id := resolve(cue)
	var out: Array = []
	var c: Dictionary = cues.get(id, {})
	var bub := String(c.get("bubble", ""))
	var base := id.to_lower()
	if drop_files.has(base):
		out.append({"file": drop_files[base], "bubble": bub})
	for k in range(2, 21):
		var key := "%s_%d" % [base, k]
		if drop_files.has(key):
			out.append({"file": drop_files[key], "bubble": bub})
	if not out.is_empty():
		return out
	var listed: Array = lines.get("cues", {}).get(id, [])
	if listed.is_empty() and c.has("alias"):
		listed = lines.get("cues", {}).get(String(c["alias"]), [])
	for l in listed:
		if l is Dictionary and ResourceLoader.exists(String(l.get("file", ""))):
			out.append(l)
	return out


## True when the cue has a recording of its own (not a fallback).
func has_line(cue: String) -> bool:
	return not lines_for(cue).is_empty()


func _fallback(id: String) -> bool:
	var c: Dictionary = cues.get(id, {})
	match String(c.get("fallback", "placeholder" if not cues.has(id) else "quiet")):
		"placeholder":
			var ph: Array = lines.get("placeholders", [])
			if ph.is_empty():
				return false
			stop_voice()
			_queue = [ph[rng.randi() % ph.size()]]
			_next_line()
			return true
		"tts":
			var text := String(c.get("say", ""))
			if text == "" or not stand_in_voice:
				return false
			stop_voice()
			return _tts_say(text.replace("|", " "), String(c.get("bubble", "")))
	return false


# --- the stand-in voice (the tablet's text-to-speech) -----------------------

func tts_available() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		return false
	if _tts_voice == "":
		var v := DisplayServer.tts_get_voices_for_language("en")
		if v.is_empty():
			return false
		_tts_voice = v[0]
		for id in v:
			# a Canadian or British English voice if the tablet has one
			if "CA" in id or "GB" in id:
				_tts_voice = id
				break
	return true


func _tts_say(text: String, bub: String) -> bool:
	if not tts_available():
		return false
	DisplayServer.tts_speak(text, _tts_voice, 90, TTS_PITCH, TTS_RATE)
	# about 2.6 words a second at this rate, plus a beat
	var words := text.split(" ", false).size()
	_tts_until = Time.get_ticks_msec() / 1000.0 + 0.6 + words / 2.6
	bubble = bub
	_duck()
	_fig.queue_redraw()
	return true


func _tts_talking() -> bool:
	return _tts_until > Time.get_ticks_msec() / 1000.0


func _tts_stop() -> void:
	if _tts_until > 0.0:
		_tts_until = 0.0
		if DisplayServer.get_name() != "headless":
			DisplayServer.tts_stop()


func stop_voice() -> void:
	_tts_stop()
	_answer_token += 1
	_queue.clear()
	_line_len = 0.0
	player.stop()
	bubble = ""
	_unduck()


func is_talking() -> bool:
	return player.playing or _line_t < _line_len or _tts_talking()


# --- internals --------------------------------------------------------------

## The cheerful number take for n (cue A<n>): a dropped-in A<n> file, else
## the recorded answer-<n>. "" when there is none.
func answer_file(n: int) -> String:
	var key := "a%d" % n
	if drop_files.has(key):
		return drop_files[key]
	var file: String = lines.get("answers", {}).get(str(n), "")
	return file if file != "" and ResourceLoader.exists(file) else ""


## The plain number take for counting (cue Q<n>, "four" not "Four!"), falling
## back to the cheerful one until the plain takes are dropped in.
func _number_file(n: int) -> String:
	var key := "q%d" % n
	if drop_files.has(key):
		return drop_files[key]
	return answer_file(n)


func _has_numbers(steps: Array) -> bool:
	for st in steps:
		if st.has("n") and _number_file(int(st["n"])) == "":
			push_warning("Ellwynn: no number line for %d" % int(st["n"]))
			return false
	return true


## One of the cue's own recorded lines, {} when it has none. A take-away's
## "then" (count_back_then, H4) uses count_then's (H3) until it has its own.
func _own_line(cue: String) -> Dictionary:
	var own := lines_for(cue)
	if own.is_empty():
		if resolve(cue) == "H4":
			return _own_line("H3")
		return {}
	return own[rng.randi() % own.size()]


## Plays a file now, cutting off whatever she was saying, without dropping
## a count in progress (stop_voice would).
func _play_now(file: String, bub: String, from := 0.0) -> void:
	var stream = load(file) if file != "" else null
	if stream == null:
		return
	_queue.clear()
	player.stop()
	bubble = bub
	_cur_file = file
	player.stream = stream
	_line_len = stream.get_length()
	_line_t = minf(from, _line_len)
	player.play(_line_t)
	_duck(ANSWER_DUCK_DB)
	_fig.queue_redraw()


func _set_mode(m: String) -> void:
	_gen += 1
	mode = m
	_slide = 1.0 if m == "menu" else 0.0
	if m == "off":
		bubble = ""
	_fig.queue_redraw()


func _on_finished() -> void:
	if _line_t >= _line_len - 0.1:
		_line_len = 0.0
		_next_line()


func _next_line() -> void:
	if _queue.is_empty():
		bubble = ""
		_unduck()
		_fig.queue_redraw()
		return
	var line: Dictionary = _queue.pop_front()
	var stream = load(String(line.get("file", "")))
	if stream == null:
		_next_line()
		return
	bubble = String(line.get("bubble", ""))
	_cur_file = String(line.get("file", ""))
	player.stream = stream
	_line_t = 0.0
	_line_len = stream.get_length()
	player.play()
	_duck()


## Music is looked up, not named, so this script also loads where the Music
## autoload isn't there (the headless tests).
func _duck(db := DUCK_DB) -> void:
	var m := get_node_or_null("/root/Music")
	if m != null:
		m.player.volume_db = m.VOLUME_DB - db


func _unduck() -> void:
	var m := get_node_or_null("/root/Music")
	if m != null:
		m.player.volume_db = m.VOLUME_DB


func _process(delta: float) -> void:
	_t += delta
	if _line_len > 0.0:
		_line_t += delta
		# no sound (muted or no audio device): move on when the line's time is up
		if _line_t >= _line_len and not player.playing:
			_line_len = 0.0
			_next_line()
	if _tts_until > 0.0 and not _tts_talking():
		_tts_until = 0.0
		if _queue.is_empty() and not player.playing:
			bubble = ""
			_unduck()
	var m := _mouth_now()
	_mouth = m
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blinking = 0.14
		_blink_in = rng.randf_range(3.0, 5.0)
	_blinking = maxf(_blinking - delta, 0.0)
	_hop = maxf(_hop - delta * 3.0, 0.0)
	if mode == "pop" or mode == "boss" or mode == "answer":
		_slide = minf(_slide + delta * 4.0, 1.0)
	if mode != "off":
		_fig.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if mode != "menu" or not Pointer.is_press(event):
		return
	var local := Pointer.local_pos(_fig, event)
	if Rect2(MENU_POS + BODY_TAP.position, BODY_TAP.size).has_point(local):
		_hop = 1.0
		say("intro")
		get_viewport().set_input_as_handled()


func _body_frame() -> Texture2D:
	if _mouth != "closed":
		return FRAMES[_mouth]
	if _blinking > 0.0:
		return FRAMES["blink"]
	return FRAMES["closed"]


func _draw_fig() -> void:
	match mode:
		"menu":
			var bob := roundf(sin(_t * 2.0) * 2.0) - roundf(sin(_hop * PI) * 14.0)
			_draw_body(MENU_POS + Vector2(0, bob))
		"boss":
			var x := lerpf(-200.0, MENU_POS.x, _ease(_slide))
			_draw_body(Vector2(roundf(x), MENU_POS.y))
		"pop":
			var y := lerpf(560.0, POP_POS.y, _ease(_slide))
			_draw_portrait(Vector2(POP_POS.x, roundf(y)))
		"answer":
			var x := lerpf(-240.0, ANSWER_POS.x, _ease(_slide))
			_draw_portrait(Vector2(roundf(x), ANSWER_POS.y))


## Her 96 px portrait in a gold frame, with her bubble to its right.
func _draw_portrait(at: Vector2) -> void:
	var r := Rect2(at - Vector2(POP_PAD, POP_PAD), Vector2(96, 96) + Vector2(POP_PAD, POP_PAD) * 2)
	_fig.draw_rect(r.grow(3), DARK)
	_fig.draw_rect(r, GOLD)
	_fig.draw_texture(BUST, r.position + Vector2(POP_PAD, POP_PAD))
	if bubble != "":
		_draw_bubble(r.position + Vector2(r.size.x + 8, 10))


func _draw_body(at: Vector2) -> void:
	_fig.draw_texture(_body_frame(), at)
	if bubble != "":
		_draw_bubble(at + Vector2(BODY_SIZE.x - 6, 18))


## A small speech bubble with a sight word, beside her head.
func _draw_bubble(at: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var w := maxf(font.get_string_size(bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 28, 76)
	var r := Rect2(at, Vector2(w, 50))
	_fig.draw_rect(r.grow(3), DARK)
	_fig.draw_rect(r, INK)
	_fig.draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, 30), r.position + Vector2(-14, 40), r.position + Vector2(0, 40)]), INK)
	_fig.draw_string(font, r.position + Vector2(0, 36), bubble, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, DARK)


static func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)
