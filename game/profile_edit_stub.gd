## Stand-in for game/profile_edit_screen.gd (profile plan P3) until that
## screen lands: the same setup() and signals, so main.gd's wiring runs.
## Create says yes at once with blanks ("Player N" and the next free
## picture); edit goes straight back. main.gd uses the real screen as soon as
## the file exists.
extends Node2D

signal created(nickname: String, picture: String)
signal saved(profile_id: String, nickname: String, picture: String)
signal removed(profile_id: String)
signal back

enum Mode { CREATE, EDIT }

var mode := Mode.CREATE
var voice := false  # as the real screen: main.gd sets it


func setup(_r: Dictionary, m: int, _profile_id := "", _first_run := false) -> void:
	mode = m as Mode


func _ready() -> void:
	await get_tree().process_frame
	if mode == Mode.CREATE:
		created.emit("", "")
	else:
		back.emit()
