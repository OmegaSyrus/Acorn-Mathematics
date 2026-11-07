## Stills of Ellwynn in the game: the main menu (first visit, talking), the
## "Yay!" pop-in over a fight, and the boss-win slide-in over the boss fight.
##   xvfb-run godot --path . --rendering-driver opengl3 res://tools/stills/ellwynn_stills.tscn -- --out=/tmp/shots
## Delete the profile save first to see the first visit.
extends Node2D

const SeededRng := preload("res://logic/core/rng.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")

var out_dir := "/tmp"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(40)
	_shot("ellwynn-menu")
	# the pop-in over a fight
	var f := FightScreen.new()
	f.setup(SeededRng.new(3), 1, "blorp", false, false, false)
	main.call("_swap", f)
	await _frames(30)
	Ellwynn._set_mode("pop")
	Ellwynn.say("enemy")
	await _frames(30)
	_shot("ellwynn-pop")
	# the boss win
	var b := BounceScreen.new()
	b.setup(SeededRng.new(5), 1, false)
	main.call("_swap", b)
	await _frames(30)
	Ellwynn._set_mode("boss")
	Ellwynn.say("boss_win")
	await _frames(40)
	_shot("ellwynn-boss")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
