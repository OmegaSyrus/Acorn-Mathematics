## Frames of each world's moving details (2026-11-12): the crossing at full
## size and at half size, a fight, the miniboss duel and the boss's treasure
## room, in every built world. Each case saves a still and a run of frames
## that tools/ambient/make_gifs.py turns into small looping GIFs.
##   xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 20 \
##       res://tools/stills/ambient_stills.tscn -- --out=/tmp/shots [--frames=40] [--off]
## --off draws the same screens with the details turned off (before/after).
extends Node2D

const SeededRng := preload("res://logic/core/rng.gd")
const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")
const Ambient := preload("res://game/ui/ambient.gd")

## name: [area, level id, a monster, the miniboss, world]
const CASES := [
	["lava1", "lava_scroll", 1, "surtling", "lava_miniboss", "lava_caves"],
	["lava", "lava_scroll", 12, "", "", "lava_caves"],
	["crystal", "crystal_scroll", 21, "knocker", "crystal_miniboss", "crystal_mines"],
	["bog", "bog_scroll", 31, "wispling", "bog_miniboss", "bog"],
]

var out_dir := "/tmp"
var frames := 40


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		if arg.begins_with("--frames="):
			frames = int(arg.substr(9))
		if arg == "--off":
			Ambient.enabled = false
	var stage := Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	var levels := Content.levels()
	for c in CASES:
		var run := ScrollRun.new(Content.area(c[1]), levels[c[2]], 5 + c[2])
		var s := ScrollScreen.new()
		s.setup(run, {"gems": 6}, false)
		stage.add_child(s)
		await _frames(10)
		s.rolled.emit()
		while not s.choice.active:
			await _frames(1)
		await _frames(30)
		await _run(c[0] + "-walk")
		s.queue_free()
		await _frames(2)
		if c[3] == "":
			continue
		for id in [c[3], c[4]]:
			var f := FightScreen.new()
			f.setup(SeededRng.new(78), 1, id, false, id.ends_with("miniboss"))
			stage.add_child(f)
			while not f.choice.active:
				await _frames(1)
			await _frames(10)
			await _run(c[0] + ("-duel" if id.ends_with("miniboss") else "-fight"))
			f.queue_free()
			await _frames(2)
		var b := BounceScreen.new()
		b.setup(SeededRng.new(11), 1)
		b.world_id = c[5]
		stage.add_child(b)
		while b.phase != "aiming":
			await _frames(1)
		b.aim = 120
		await _frames(10)
		await _run(c[0] + "-boss")
		b.queue_free()
		await _frames(2)
	get_tree().quit()


func _run(name: String) -> void:
	_shot(name)
	if frames <= 0:
		return
	DirAccess.make_dir_recursive_absolute(out_dir.path_join(name))
	for i in frames:
		await _frames(1)
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(name).path_join("%03d.png" % i))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
