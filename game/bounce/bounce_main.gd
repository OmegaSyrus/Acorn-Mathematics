## Standalone root for the Match Bounce graybox until the map links to it:
##   godot --path . res://scenes/bounce.tscn -- --grade=1 --seed=123
## Centers the 960x540 design space like game/main.gd and starts a new
## fight whenever one ends (win, Try or Map).
extends Node2D

const InputSetup := preload("res://game/input_setup.gd")
const SeededRng := preload("res://logic/core/rng.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")

const DESIGN := Vector2(960, 540)

var stage: Node2D
var screen: Node2D
var grade := 1
var seed_value := -1


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	stage = Node2D.new()
	add_child(stage)
	get_viewport().size_changed.connect(_layout)
	_layout()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--grade="):
			grade = clampi(arg.substr(8).to_int(), 1, 4)
		elif arg.begins_with("--seed="):
			seed_value = arg.substr(7).to_int()
	_start()


func _layout() -> void:
	stage.position = ((get_viewport_rect().size - DESIGN) / 2.0).round()


func _start() -> void:
	if screen != null:
		screen.queue_free()
	var s := seed_value
	if s < 0:
		s = (int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec()) & 0xFFFFFFFF
	screen = BounceScreen.new()
	screen.setup(SeededRng.new(s), grade)
	screen.done.connect(func(_won): _start.call_deferred())
	stage.add_child(screen)
