## Stills of the main menu's oak hill: the scene fast-forwarded so birds,
## animals and leaves are out, with Ellwynn in front. Own save in memory.
##   godot --headless --path . --import
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/stills/menu_stills.tscn -- --out=/tmp/shots
## Add --frames to also save a 12 fps run of 10 s (menu-frame-NNN.png) for a video.
extends Node2D

const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const MapScreen := preload("res://game/map_screen.gd")
const MenuScene := preload("res://game/ui/menu_scene.gd")
const InputSetup := preload("res://game/input_setup.gd")

var out_dir := "/tmp"
var video := false


func _ready() -> void:
	InputSetup.register()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		if arg == "--frames":
			video = true
	var stage := Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	Ellwynn.offset = stage.position
	var save := SaveData.new_profile("stills")
	save["ellwynn_intro_seen"] = true
	save["gems"] = 12
	var m := MapScreen.new()
	var shown := {}
	for n in range(1, 7):
		shown[n] = {"id": n, "name": "Level %d" % n, "available": true}
	m.setup(save, shown, "lava_scroll")
	stage.add_child(m)
	Ellwynn.menu_enter(save)
	await _frames(10)
	var scene: MenuScene = null
	for c in m.get_children():
		if c is MenuScene:
			scene = c
	scene.set_process(false)
	scene.rng.seed = 7
	_shot("menu-0-start")
	# fast-forward and grab a few moments
	for i in range(1, 7):
		for k in 120:
			scene.step(1.0 / 30.0)
		scene.queue_redraw()
		await _frames(2)
		_shot("menu-%d" % i)
	if video:
		for f in 120:
			for k in 3:
				scene.step(1.0 / 36.0)
			scene.queue_redraw()
			await _frames(1)
			_shot("menu-frame-%03d" % f)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
