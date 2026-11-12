## Ellwynn, the companion (docs/ellwynn-intro.md). Autoloaded as Ellwynn.
## Mostly a voice (Terrence 2026-11-06). She is seen in three places:
##   - the main menu: her full body stands bottom left, bobs, blinks and talks
##     (mouth frames follow the loudness of her voice); tap her to hear her again;
##   - an enemy win: 1 time in 3 her portrait pops up in the corner with a "Yay!";
##   - a region boss win: her full body slides in to congratulate the player.
## Chests get her voice only. Lines come from content/ellwynn_lines.json; a cue
## with no lines yet plays one of the three placeholders.
## Draws in the 960x540 design space: main.gd keeps `offset` on the stage's.
extends CanvasLayer

const SaveStoreRef := preload("res://game/save_store.gd")
const Pointer := preload("res://game/ui/pointer.gd")
const LINES_PATH := "res://content/ellwynn_lines.json"
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


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	lines = _load_lines()
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
func boss_beaten() -> void:
	_set_mode("boss")
	say("boss_win")
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
	var file: String = lines.get("answers", {}).get(str(n), "")
	if file == "" or not ResourceLoader.exists(file):
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


## Plays a cue: the intro plays all its lines in order; any other cue plays
## one of its lines at random. A cue with no lines plays a placeholder.
func say(cue: String) -> void:
	var own: Array = lines.get("cues", {}).get(cue, [])
	var pick: Array = []
	if own.is_empty():
		var ph: Array = lines.get("placeholders", [])
		if not ph.is_empty():
			pick = [ph[rng.randi() % ph.size()]]
	elif cue == "intro":
		pick = own.duplicate()
	else:
		pick = [own[rng.randi() % own.size()]]
	if pick.is_empty():
		return
	stop_voice()
	_queue = pick
	_next_line()


func stop_voice() -> void:
	_answer_token += 1
	_queue.clear()
	_line_len = 0.0
	player.stop()
	bubble = ""
	_unduck()


func is_talking() -> bool:
	return player.playing or _line_t < _line_len


# --- internals --------------------------------------------------------------

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


func _duck(db := DUCK_DB) -> void:
	if get_node_or_null("/root/Music") != null:
		Music.player.volume_db = Music.VOLUME_DB - db


func _unduck() -> void:
	if get_node_or_null("/root/Music") != null:
		Music.player.volume_db = Music.VOLUME_DB


func _process(delta: float) -> void:
	_t += delta
	if _line_len > 0.0:
		_line_t += delta
		# no sound (muted or no audio device): move on when the line's time is up
		if _line_t >= _line_len and not player.playing:
			_line_len = 0.0
			_next_line()
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
