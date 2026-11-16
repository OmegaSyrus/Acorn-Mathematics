## Checks Ellwynn talks on the main menu: taps her with a real touch, logs her
## mouth frame each frame while the line plays, and saves face close-ups.
##   xvfb-run godot --path . --rendering-driver opengl3 res://tools/stills/ellwynn_talk_check.tscn -- --out=/tmp/shots
extends Node2D

var out_dir := "/tmp"
## --frames also saves every frame (for a GIF).
var frames_out := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		if arg == "--frames":
			frames_out = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(20)
	Ellwynn.stop_voice()
	await _frames(5)
	# a finger on her middle, in screen pixels
	var at: Vector2 = get_viewport().get_screen_transform() * Ellwynn._fig.get_global_transform_with_canvas() * (Ellwynn.MENU_POS + Vector2(75, 130))
	var down := InputEventScreenTouch.new()
	down.position = at
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventScreenTouch.new()
	up.position = at
	Input.parse_input_event(up)
	await _frames(2)
	print("talking after tap: ", Ellwynn.is_talking(), " file: ", Ellwynn._cur_file)
	var log := ""
	var shots := {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2200:
		await get_tree().process_frame
		log += Ellwynn._mouth[0]
		if frames_out:
			_shot("frame-%03d" % log.length())
		if not shots.has(Ellwynn._mouth):
			shots[Ellwynn._mouth] = true
			_shot("talk-" + Ellwynn._mouth)
	print("mouth by frame (c closed, h half, o open): ", log)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
