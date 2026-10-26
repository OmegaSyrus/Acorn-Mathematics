## Placeholder sounds: short synthesized tones until real audio arrives.
## Autoloaded as Beeper.
extends Node

const RATE := 22050
const VOICES := 6

var _players := []
var _next := 0
var _cache := {}


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func tone(freq: float, dur := 0.12, vol_db := -10.0) -> void:
	var key := "%d:%d" % [int(freq), int(dur * 1000)]
	if not _cache.has(key):
		_cache[key] = _make(freq, dur)
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _cache[key]
	p.volume_db = vol_db
	p.play()


## Hop and dot counts climb a major scale so counting sounds like counting.
func count(n: int) -> void:
	var steps := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23]
	var s: int = steps[clampi(n - 1, 0, steps.size() - 1)]
	tone(440.0 * pow(2.0, s / 12.0), 0.1)


func good() -> void:
	for i in 3:
		get_tree().create_timer(i * 0.09).timeout.connect(tone.bind(660.0 * pow(1.26, i), 0.12))


func bad() -> void:
	tone(180.0, 0.35, -6.0)


func roll() -> void:
	for i in 5:
		get_tree().create_timer(i * 0.12).timeout.connect(tone.bind(240.0 + 40.0 * i, 0.04, -14.0))


## A wrong space: the slime sinks into the lava. A falling, wobbling gulp
## with two bubble pops after it.
func blorp() -> void:
	if not _cache.has("blorp"):
		_cache["blorp"] = _make_blorp()
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _cache["blorp"]
	p.volume_db = -4.0
	p.play()


## Chest gems: a bright run of chimes, one per gem.
func gems(n: int) -> void:
	for i in n:
		get_tree().create_timer(0.1 + i * 0.11).timeout.connect(tone.bind(1046.0 * pow(1.12, i), 0.09, -12.0))


func _make_blorp() -> AudioStreamWAV:
	var dur := 0.75
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		if t < 0.42:
			var k := t / 0.42
			var f := lerpf(300.0, 70.0, pow(k, 0.6)) * (1.0 + 0.12 * sin(TAU * 18.0 * t))
			ph += TAU * f / RATE
			v = sin(ph) * minf(1.0, i / 300.0) * (1.0 - k * 0.6) * 0.8
		for pop in [[0.5, 520.0], [0.62, 700.0]]:
			var dt: float = t - pop[0]
			if dt >= 0.0 and dt < 0.06:
				v += sin(TAU * lerpf(pop[1], pop[1] * 1.6, dt / 0.06) * dt) * (1.0 - dt / 0.06) * 0.45
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _make(freq: float, dur: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, i / 200.0) * (1.0 - float(i) / n)
		var v := sin(TAU * freq * t) * env * 0.6
		data.encode_s16(i * 2, int(v * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
