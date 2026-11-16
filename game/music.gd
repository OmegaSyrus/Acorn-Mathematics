## Background music (Terrence's songs, 2026-11-05). Autoloaded as Music.
## The main menu loops "Welcome to Math Land!"; the lava section plays its
## five songs in a random order, never the same song twice in a row. Keeps
## playing while the in-game menu has the game paused.
extends Node

const DIR := "res://audio/music/"
const MENU := ["menu-welcome-to-math-land.mp3"]
const LAVA := [
	"lava-pixel-lava-run-1.mp3",
	"lava-cave-jump.mp3",
	"lava-jump.mp3",
	"lava-pixel-lava-run.mp3",
	"lava-volcano-jump.mp3",
]
## Under the beeps and, later, Ellwynn's voice.
const VOLUME_DB := -8.0

var player: AudioStreamPlayer
var playlist := ""     # "menu", "lava" or "" when quiet
var current := ""      # the file playing now
var _tracks: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	player = AudioStreamPlayer.new()
	player.volume_db = VOLUME_DB
	add_child(player)
	player.finished.connect(_next)


func play_menu() -> void:
	_start("menu", MENU)


func play_lava() -> void:
	_start("lava", LAVA)


func stop() -> void:
	playlist = ""
	current = ""
	player.stop()


## The app went to the background (game/app_life.gd): hold the song.
func pause() -> void:
	player.stream_paused = true


## Back from the background: the held song plays on, or the list starts
## again if the song was lost while away.
func resume() -> void:
	player.stream_paused = false
	if playlist != "" and not player.playing:
		_next()


## Already playing this list: carry on with the song that is on.
func _start(list_name: String, tracks: Array) -> void:
	if playlist == list_name and player.playing:
		return
	playlist = list_name
	_tracks = tracks
	current = ""
	_next()


## The next song: the same one again for a one-song list, else a random
## pick that is not the song that just ended.
func _next() -> void:
	if playlist == "" or _tracks.is_empty():
		return
	var pick: String = _tracks[0]
	if _tracks.size() > 1:
		var others := _tracks.filter(func(t): return t != current)
		pick = others[_rng.randi_range(0, others.size() - 1)]
	current = pick
	player.stream = load(DIR + pick)
	player.play()
