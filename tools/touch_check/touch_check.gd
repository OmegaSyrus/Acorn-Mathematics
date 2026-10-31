## Plays the real game from the map with synthetic touch events only (no
## mouse, no keys) and saves a still after each tap, to check a tablet build.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1024x768 \
##       res://tools/touch_check/touch_check.tscn -- --out=/tmp/touch
extends Node

const MainScene := preload("res://scenes/main.tscn")

var out_dir := "/tmp"
var main: Node2D
var failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = MainScene.instantiate()
	add_child(main)
	await _frames(30)
	_shot("1-map")

	# The map: tap the first grade box.
	var map: Node2D = main.screen
	_check(map.get_script().resource_path.ends_with("map_screen.gd"), "map is showing")
	await _tap(map, (map.buttons[0]["rect"] as Rect2).get_center())
	await _frames(30)
	var scroll: Node2D = main.screen
	if not scroll.get_script().resource_path.ends_with("scroll_screen.gd"):
		_check(false, "tap on map opened the crossing")
		get_tree().quit(1)
		return
	_check(true, "tap on map opened the crossing")
	_shot("2-crossing")

	# The crossing: wait for the Roll box, tap it.
	var waited := 0
	while not scroll.tray_waiting and waited < 600:
		await _frames(1)
		waited += 1
	_check(scroll.tray_waiting, "Roll box waits for a tap")
	await _tap(scroll, scroll.TRAY.get_center())
	waited = 0
	while not scroll.choice.active and waited < 600:
		await _frames(1)
		waited += 1
	_check(scroll.choice.active, "tap on Roll rolled the dice and offered rocks")
	_shot("3-rolled")

	# Pick a rock by touch.
	var c = scroll.choice
	var before: int = c.rects.size()
	_check(before > 0, "rocks to pick")
	var picked := [false]
	c.picked.connect(func(_i): picked[0] = true)
	await _tap(c, c._rect(0).get_center())
	await _frames(5)
	_check(picked[0], "tap on a rock picked it")
	await _frames(60)
	_shot("4-picked")

	print("TOUCH CHECK %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


## A finger press and lift at a point in `ci`'s local space.
## Waits out the 300 ms choice lockout first, as a child would.
func _tap(ci: CanvasItem, local: Vector2) -> void:
	await get_tree().create_timer(0.5).timeout
	var at := get_viewport().get_screen_transform() * ci.get_global_transform_with_canvas() * local
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = at
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(3)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures += 1


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
