## Saves one still of each play screen (lava walk, combat, boss fight) at
## Acorn, for sharing looks after an art pass.
##   xvfb-run godot --path . --rendering-driver opengl3 res://tools/stills/screens.tscn -- --out=/tmp/shots
extends Node2D

const SeededRng := preload("res://logic/core/rng.gd")
const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")

var out_dir := "/tmp"


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	var stage := Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()

	# The crossing, a few rocks in, with the dice rolled and a dragon revealed.
	var area := Content.area("lava_scroll")
	var run := ScrollRun.new(area, Content.grades()[1], 2)
	var s := ScrollScreen.new()
	s.setup(run, {"gems": 6}, false)
	stage.add_child(s)
	await _frames(20)
	s.rolled.emit()
	while not s.choice.active:
		await _frames(1)
	await _frames(30)
	_shot("lava-walk")
	var mpos := -1
	for sp in area["spaces"]:
		if sp["type"] == "monster":
			mpos = int(sp["at"])
			break
	s._place_hero(mpos)
	s.revealed = mpos
	s.reveal = 1.0
	s.bubble = "Fight!"
	s._hide_dice()
	await _frames(30)
	_shot("lava-enemy")
	s.queue_free()
	await _frames(2)

	var f := FightScreen.new()
	f.setup(SeededRng.new(78), 1, "bolt")
	stage.add_child(f)
	while not f.choice.active:
		await _frames(1)
	await _frames(20)
	_shot("combat")
	f.queue_free()
	await _frames(2)

	var b := BounceScreen.new()
	b.setup(SeededRng.new(11), 1)
	stage.add_child(b)
	while b.phase != "aiming":
		await _frames(1)
	b.aim = 120
	await _frames(20)
	_shot("boss-fight")
	b._fire()
	await _frames(55)
	_shot("boss-fight-shot")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
