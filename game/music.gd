## Background music. Autoloaded as Music.
## The main menu loops "Welcome to Math Land"; the lava crossing (and its
## fights) plays the lava songs in a shuffled order, never the same song twice
## in a row. play_menu() and play_lava() do nothing if that set is already on,
## so screens can call them freely without restarting the song.
extends Node

const MENU := "res://audio/music/welcome-to-math-land.mp3"
const LAVA := [
	"res://audio/music/lava-pixel-run.mp3",
	"res://audio/music/lava-pixel-run-2.mp3",
	"res://audio/music/lava-cave-jump.mp3",
	"res://audio/music/lava-jump.mp3",
	"res://audio/music/volcano-jump.mp3",
]
const VOLUME_DB := -8.0
const FADE_S := 0.6

var _player: AudioStreamPlayer
var _set := ""          # "menu", "lava" or ""
var _queue: Array = []  # lava songs still to play this round
var _last := ""
var _rng := RandomNumberGenerator.new()
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps playing under the pause menu
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_player.finished.connect(_on_finished)


func play_menu() -> void:
	if _set == "menu":
		return
	_set = "menu"
	_start(MENU, true)


func play_lava() -> void:
	if _set == "lava":
		return
	_set = "lava"
	_queue.clear()
	_start(_next_lava(), false)


func stop() -> void:
	_set = ""
	_player.stop()


func current_set() -> String:
	return _set


## Shuffled rounds through every lava song; a new round never opens with the
## song that just ended.
func _next_lava() -> String:
	if _queue.is_empty():
		_queue = LAVA.duplicate()
		for i in range(_queue.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var t = _queue[i]
			_queue[i] = _queue[j]
			_queue[j] = t
		if _queue.size() > 1 and _queue[0] == _last:
			_queue.push_back(_queue.pop_front())
	_last = _queue.pop_front()
	return _last


func _start(path: String, loop: bool) -> void:
	var stream := load(path) as AudioStreamMP3
	if stream == null:
		push_error("music missing: %s" % path)
		return
	stream = stream.duplicate()
	stream.loop = loop
	if _fade != null:
		_fade.kill()
	_player.stream = stream
	_player.volume_db = -40.0
	_player.play()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", VOLUME_DB, FADE_S)


func _on_finished() -> void:
	if _set == "lava":
		_start(_next_lava(), false)
