## Sound effects (Phase 3). Autoloaded as Beeper.
##
## Every sound has an id ("roll", "gem", "block"...; the list and what each
## is for: audio/sfx/README.md). The built-in sounds are in
## audio/sfx/builtin/ (made by tools/sfx/make_sfx.py). A file named by the
## id in audio/sfx/ replaces the built-in one: audio/sfx/roll.mp3, or
## roll.ogg + roll_2.ogg + roll_3.ogg for several takes. Any of .ogg, .wav,
## .mp3; names are matched without case.
##
##   Beeper.play("gem")               a sound by id
##   Beeper.play("gem", -4.0, 1.12)   quieter, a little higher
##
## The older calls still work and now play real sounds: count(n) climbs a
## marimba up a major scale, good(), bad(), roll(), blorp(), gems(n),
## warble(). tone(freq, dur, vol_db) is routed to a named sound by the
## call site's frequency and length (TONE_MAP below), and anything it does
## not know plays a soft mallet note at that pitch.
extends Node

const SFX_DIR := "res://audio/sfx/"
const BUILTIN_DIR := "res://audio/sfx/builtin/"
const AUDIO_EXT := ["ogg", "wav", "mp3"]
const VOICES := 10

## Every built-in id. A drop-in file may add a new id too.
const IDS := [
	"roll", "hop", "land", "stone_pick", "tap", "nope", "sink", "chest_open",
	"gem", "coin", "bucket", "heart", "heart_land", "block", "hit", "poof",
	"win", "good", "wrong", "door", "peg", "peg_mod", "whiff", "launch",
	"buy", "select", "crack", "miss", "peek", "lantern", "reveal", "count",
	"mallet", "warble",
]

## A little random pitch (plus or minus this much) for sounds that repeat a
## lot, so they don't sound stamped. Tuned sounds (count, gem, good, win...)
## keep their pitch so the notes stay in tune.
const JITTER := {
	"roll": 0.06, "hop": 0.05, "land": 0.06, "stone_pick": 0.04, "tap": 0.03,
	"peg": 0.03, "hit": 0.06, "block": 0.04, "whiff": 0.08, "miss": 0.08,
	"crack": 0.05, "poof": 0.05, "launch": 0.04, "lantern": 0.05, "sink": 0.03,
}

## Beeper.tone(freq, dur, vol_db) call sites, routed to named sounds.
## Key "freq:ms" (or "freq:ms:vol" where one frequency means two things).
## Value: [id, vol_db, pitch]. An empty id plays nothing (the second note
## of a pair the first sound already covers). The call sites, 2026-11-28:
##   880:60     fight_screen  a die peeks               -> peek
##   260:100    fight_screen  the lantern goes out      -> lantern
##   1200:80    fight_screen  shield blocks / bash      -> block
##   330:120    fight_screen  "Miss!"                   -> miss
##   220:150    fight_screen  a shield cracks;
##              scroll_screen a heart breaks            -> crack
##   660:80     map/grownups/debug/store: a choice made
##              (difficulty, level, toggle, equip)      -> tap
##   330:80     map_screen    nothing else to pick      -> nope
##   440:80     store_screen  Back                      -> tap, lower
##   523:70     scroll_screen stone selected; store tab,
##              store item selected                     -> stone_pick
##   784:90     store_screen  item selected, 2nd note   -> select
##   196:160    store_screen  can't buy yet             -> wrong
##   165:200    store_screen  can't buy, 2nd note       -> (nothing)
##   880:80:-8  scroll_screen chest opens               -> chest_open
##   880:80     area_screen   question repeated         -> tap, higher
##   1046*1.12^k:90  scroll_screen a gem lands          -> gem, pitch 1.12^k
##   1046*1.06^k:70  bounce_screen a gem in the bucket  -> coin, pitch 1.06^k
##   523:100    bounce_screen bucket starts filling     -> bucket
##   150:40     bounce_screen ball ghosts through a peg -> whiff
##   880:100    bounce_screen a +/-1 peg                -> peg_mod
##   300:30     bounce_screen wall or bumper            -> peg
##   330:80 + 495:120  scroll_screen a space revealed   -> reveal
##   660:80 + 990:140  scroll_screen heart picked up    -> heart
##   1320:100   scroll_screen the heart lands           -> heart_land
##   330:60     pin_screen    clear                     -> tap, lower
##   520:50     pin_screen    a digit                   -> tap
## A pair played in the same frame (330:80 then 495:120, 660:80 then
## 990:140) is one sound: the second stops the first (PAIRS).
const TONE_MAP := {
	"880:60": ["peek", 0.0, 1.0],
	"260:100": ["lantern", 0.0, 1.0],
	"1200:80": ["block", 0.0, 1.0],
	"330:120": ["miss", 0.0, 1.0],
	"220:150": ["crack", 0.0, 1.0],
	"660:80": ["tap", 0.0, 1.0],
	"330:80": ["nope", 0.0, 1.0],
	"440:80": ["tap", 0.0, 0.85],
	"523:70": ["stone_pick", 0.0, 1.0],
	"784:90": ["select", -2.0, 1.0],
	"196:160": ["wrong", 0.0, 1.0],
	"165:200": ["", 0.0, 1.0],
	"880:80:-8": ["chest_open", 0.0, 1.0],
	"880:80": ["tap", 0.0, 1.12],
	"523:100": ["bucket", 0.0, 1.0],
	"150:40": ["whiff", 0.0, 1.0],
	"880:100": ["peg_mod", 0.0, 1.0],
	"300:30": ["peg", 0.0, 1.0],
	"495:120": ["reveal", 0.0, 1.0],
	"990:140": ["heart", 0.0, 1.0],
	"1320:100": ["heart_land", 0.0, 1.0],
	"330:60": ["tap", 0.0, 0.85],
	"520:50": ["tap", 0.0, 1.0],
}
## second tone key -> the first one it swallows when both come in one frame
const PAIRS := {"495:120": "330:80", "990:140": "660:80"}
## The gem runs climb in pitch: matched by length, pitch from the frequency.
const GEM_BASE := 1046.0
const TONE_DEFAULT_DB := -10.0

## id -> paths of its takes (override files if any, else built-ins)
var sounds := {}
var _streams := {}
var _last_take := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()
var _last_tone := {"key": "", "frame": -1, "player": null}


func _ready() -> void:
	_rng.randomize()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	rescan()


## Looks again for built-in and dropped-in sounds.
func rescan() -> void:
	sounds = scan(BUILTIN_DIR, SFX_DIR)
	_streams.clear()


## Plays a sound by id. vol_db adds to the sound's own level; pitch scales
## it (2.0 is an octave up). Returns the player, or null if there is no
## such sound.
func play(id: String, vol_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var stream := _stream_for(id)
	if stream == null:
		return null
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	var j: float = JITTER.get(id, 0.0)
	p.stream = stream
	p.volume_db = vol_db
	p.pitch_scale = maxf(0.05, pitch * (1.0 + _rng.randf_range(-j, j)))
	p.play()
	return p


func has_sound(id: String) -> bool:
	return sounds.has(id)


## The older placeholder call, now routed to a named sound (TONE_MAP) or,
## failing that, a soft mallet note at the asked pitch.
func tone(freq: float, dur := 0.12, vol_db := TONE_DEFAULT_DB) -> void:
	var r := route_tone(freq, dur, vol_db)
	var key: String = r[3]
	var frame := Engine.get_process_frames()
	if PAIRS.has(key) and _last_tone["key"] == PAIRS[key] and _last_tone["frame"] == frame:
		var first: AudioStreamPlayer = _last_tone["player"]
		if first != null:
			first.stop()
	var p: AudioStreamPlayer = null
	if r[0] != "":
		p = play(r[0], r[1], r[2])
	_last_tone = {"key": key, "frame": frame, "player": p}


## [id, vol_db, pitch, key] for a tone() call. Static so tests can check it.
static func route_tone(freq: float, dur: float, vol_db := TONE_DEFAULT_DB) -> Array:
	var ms := int(round(dur * 1000.0))
	var key := "%d:%d" % [int(round(freq)), ms]
	var key_vol := "%s:%d" % [key, int(round(vol_db))]
	var rel := vol_db - TONE_DEFAULT_DB
	if TONE_MAP.has(key_vol):
		var e: Array = TONE_MAP[key_vol]
		return [e[0], e[1], e[2], key_vol]
	if TONE_MAP.has(key):
		var e: Array = TONE_MAP[key]
		return [e[0], e[1], e[2], key]
	if freq >= GEM_BASE - 1.0 and ms == 90:
		return ["gem", rel, freq / GEM_BASE, key]
	if freq >= GEM_BASE - 1.0 and ms == 70:
		return ["coin", rel, freq / GEM_BASE, key]
	return ["mallet", rel, clampf(freq / 440.0, 0.25, 4.0), key]


## Hop and dot counts climb a major scale so counting sounds like counting.
func count(n: int) -> void:
	play("count", 0.0, count_pitch(n))


static func count_pitch(n: int) -> float:
	var steps := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23]
	var s: int = steps[clampi(n - 1, 0, steps.size() - 1)]
	return pow(2.0, s / 12.0)


func good() -> void:
	play("good")


## Gentle: a soft two-note step down, never a buzz.
func bad() -> void:
	play("wrong")


func roll() -> void:
	play("roll")


## A wrong space: the slime sinks into the lava.
func blorp() -> void:
	play("sink")


## Chest gems: a run of crystal chimes, one per gem, each a little higher.
func gems(n: int) -> void:
	for i in n:
		get_tree().create_timer(0.1 + i * 0.11).timeout.connect(play.bind("gem", -2.0, pow(1.12, i)))


## The last heart: time slows and the sound wobbles with it.
func warble() -> void:
	play("warble")


func _stream_for(id: String) -> AudioStream:
	var takes: Array = sounds.get(id, [])
	if takes.is_empty():
		return null
	var path: String = pick_take(takes, _last_take.get(id, ""), _rng)
	_last_take[id] = path
	if not _streams.has(path):
		_streams[path] = load(path) as AudioStream
	return _streams[path]


## A random take that is not the one played last (when there are two or more).
static func pick_take(takes: Array, last: String, rng: RandomNumberGenerator) -> String:
	if takes.size() == 1:
		return takes[0]
	var others := takes.filter(func(t): return t != last)
	return others[rng.randi_range(0, others.size() - 1)]


## id -> sorted take paths. A sound's takes come from the override folder
## when it has any file for that id, else from the built-ins.
static func scan(builtin_dir: String, override_dir: String) -> Dictionary:
	var out := takes_in(builtin_dir)
	var overrides := takes_in(override_dir)
	for id in overrides:
		out[id] = overrides[id]
	return out


## The audio files in one folder, grouped by id: "roll.ogg", "roll_2.ogg"
## and "Roll_3.MP3" are all takes of "roll". Lists imported resources, so
## it works in an exported build too.
static func takes_in(dir: String) -> Dictionary:
	var out := {}
	var names: PackedStringArray = ResourceLoader.list_directory(dir)
	for n in names:
		if n.ends_with("/"):
			continue
		if not n.get_extension().to_lower() in AUDIO_EXT:
			continue
		var id := id_of(n)
		if not out.has(id):
			out[id] = []
		out[id].append(dir.path_join(n))
	for id in out:
		out[id].sort_custom(func(a, b): return _take_no(a) < _take_no(b))
	return out


## "roll_2.ogg" -> "roll"; "stone_pick.ogg" -> "stone_pick".
static func id_of(file_name: String) -> String:
	var base := file_name.get_file().get_basename().to_lower()
	var cut := base.rfind("_")
	if cut > 0 and base.substr(cut + 1).is_valid_int():
		return base.substr(0, cut)
	return base


static func _take_no(path: String) -> int:
	var base := path.get_file().get_basename()
	var cut := base.rfind("_")
	if cut > 0 and base.substr(cut + 1).is_valid_int():
		return base.substr(cut + 1).to_int()
	return 1
