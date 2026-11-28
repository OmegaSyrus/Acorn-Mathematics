## Background music (Terrence's songs). Autoloaded as Music.
##
## Each playlist is a folder (Phase 3): audio/music/menu/ for the main menu,
## and audio/music/<world id>/ for each world (ids from content/worlds.json).
## Every song file in the folder plays (any name; .mp3, .ogg or .wav), in a
## random order, never the same song twice in a row. A world whose folder
## has no songs plays the Lava Caves songs. The menu loops. Keeps playing
## while the in-game menu has the game paused. audio/music/README.md.
extends Node

const DIR := "res://audio/music/"
const MENU_LIST := "menu"
const FALLBACK_WORLD := "lava_caves"
const WORLDS := ["lava_caves", "crystal_mines", "bog", "mushroom_forest", "space"]
const AUDIO_EXT := ["mp3", "ogg", "wav"]
## Under the sound effects and Ellwynn's voice.
const VOLUME_DB := -8.0

var player: AudioStreamPlayer
var playlist := ""     # "menu", a world id, or "" when quiet
var current := ""      # the path of the song playing now
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
	_start(MENU_LIST, songs_in(DIR, MENU_LIST))


func play_lava() -> void:
	play_world(FALLBACK_WORLD)


## A world's songs. Two worlds that both fall back to the Lava songs share
## one list, so walking from one to the other doesn't restart the song.
func play_world(world_id: String) -> void:
	_start(list_name_for(DIR, world_id), songs_for(world_id))


## The song paths a world plays: its own folder, or the Lava songs.
static func songs_for(world_id: String) -> Array:
	return world_songs(DIR, world_id)


static func world_songs(root: String, world_id: String) -> Array:
	var songs := songs_in(root, world_id)
	return songs if not songs.is_empty() else songs_in(root, FALLBACK_WORLD)


## Which list a world plays under: its own id, or the Lava list when its
## folder is empty (so fallback worlds share one list).
static func list_name_for(root: String, world_id: String) -> String:
	return world_id if not songs_in(root, world_id).is_empty() else FALLBACK_WORLD


## The song files in root/<list>/, sorted. Lists imported resources, so it
## works in an exported build too.
static func songs_in(root: String, list: String) -> Array:
	var dir := root.path_join(list)
	var out := []
	for n in ResourceLoader.list_directory(dir):
		if not n.ends_with("/") and n.get_extension().to_lower() in AUDIO_EXT:
			out.append(dir.path_join(n))
	out.sort()
	return out


## The next song: the same one again for a one-song list, else a random
## pick that is not the song that just ended.
static func pick_next(tracks: Array, last: String, rng: RandomNumberGenerator) -> String:
	if tracks.is_empty():
		return ""
	if tracks.size() == 1:
		return tracks[0]
	var others := tracks.filter(func(t): return t != last)
	return others[rng.randi_range(0, others.size() - 1)]


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


func _next() -> void:
	if playlist == "" or _tracks.is_empty():
		return
	current = pick_next(_tracks, current, _rng)
	var stream := load(current) as AudioStream
	if stream == null:
		return
	# A one-song menu loops seamlessly in the stream itself; every other
	# list plays each song once and picks the next when it ends. Set every
	# time: the imported default is no loop, and a song may sit in two lists.
	set_loop(stream, playlist == MENU_LIST and _tracks.size() == 1)
	player.stream = stream
	player.play()


static func set_loop(stream: AudioStream, on: bool) -> void:
	# .mp3 and .ogg have a loop switch; a .wav song keeps its own loop
	# points and the finished signal starts it again instead
	if "loop" in stream:
		stream.set("loop", on)
