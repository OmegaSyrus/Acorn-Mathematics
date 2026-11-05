## Stills of the top-right menu button and its open menu on the lava crossing.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/stills/menu_stills.tscn -- --out=/tmp/shots
extends Node

var out_dir := "/tmp"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(20)
	_shot("menu-0-map")
	main._on_start(1, false)
	await _frames(90)
	_shot("menu-1-crossing")
	main.screen.menu.open()
	await _frames(30)
	_shot("menu-2-open")
	print("paused=", get_tree().paused, " music=", Music.current_set())
	main.screen.menu.close()
	main.screen.menu.home.emit()
	await _frames(30)
	_shot("menu-3-home")
	print("paused=", get_tree().paused, " music=", Music.current_set())
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
