## Headless-ish smoke run of the Match Bounce screen: plays a few shots by
## calling the screen's own handlers (right name, then a wrong one) and saves
## screenshots when a display exists.
##   xvfb-run godot --path . res://tests/bounce/bounce_smoke.tscn -- --grade=1 --out=/tmp/shots
extends Node2D

const SeededRng := preload("res://logic/core/rng.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")

var out_dir := ""
var grade := 1


func _ready() -> void:
	InputSetup.register()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--grade="):
			grade = arg.substr(8).to_int()
		elif arg.begins_with("--out="):
			out_dir = arg.substr(6)
	var stage := Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	var s = BounceScreen.new()
	s.setup(SeededRng.new(4242), grade)
	stage.add_child(s)
	await _frames(10)
	_shot("1-naming")
	for i in 3:
		var f = s.fight
		var idx: int = f.choices.find(f.answer_face)
		if i == 2:
			idx = (idx + 1) % f.choices.size()
		s._on_named(idx)
		s.aim = [-150, 200, 0][i]
		await _frames(5)
		if i == 0:
			_shot("2-aiming")
		s._fire()
		await _frames(40)
		if i == 0:
			_shot("3-flying")
		while s.phase in ["flying", "settling"]:
			await _frames(5)
		print("shot %d: hearts %d balls %d" % [i, f.boss_hearts, f.balls_left])
	_shot("4-after")
	print("smoke ok")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	if out_dir == "":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join("bounce-%d-%s.png" % [grade, name]))
