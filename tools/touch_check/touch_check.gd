## Plays the real game from the map with synthetic touch events only (no
## mouse, no keys) and saves a still after each tap, to check a tablet build.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1024x768 \
##       res://tools/touch_check/touch_check.tscn -- --out=/tmp/touch
extends Node

const MainScene := preload("res://scenes/main.tscn")
const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")

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
	# two steps: a tap selects the rock and shows Go; tapping another rock
	# moves the selection; Go picks
	await _tap(c, c._rect(0).get_center())
	await _frames(5)
	_check(not picked[0] and c.chosen == 0, "tap on a rock selected it without picking")
	_check(c.go_rect().has_area(), "Go button showing")
	if c.rects.size() > 1:
		await _tap(c, c._rect(1).get_center())
		await _frames(5)
		_check(not picked[0] and c.chosen == 1, "tap on another rock moved the selection")
	_shot("4-selected")
	var go_at: Vector2 = c.go_rect().get_center()
	_check(scroll.get_viewport_rect().has_point(get_viewport().get_screen_transform() * c.get_global_transform_with_canvas() * go_at),
			"Go button on screen")
	await _tap(c, go_at)
	await _frames(5)
	_check(picked[0], "tap on Go picked the rock")
	await _frames(60)
	_shot("5-picked")
	_check(Music.playlist == "lava" and Music.player.playing, "lava music playing on the crossing")

	# The menu button beside the gems: opens a paused menu; Play closes it,
	# Main Menu goes back to the map (and its music).
	var menu = main.menu
	_check(menu.visible, "menu button showing on the crossing")
	var btn: Rect2 = menu.button_rect(menu.get_viewport())
	var vis: Rect2 = menu.get_viewport().get_visible_rect()
	var corner: Vector2 = menu.get_global_transform_with_canvas() * btn.end
	_check(vis.has_point(corner - Vector2(1, 1)) and corner.x > vis.end.x - 20.0, "menu button in the top right corner, on screen")
	await _tap(menu, btn.get_center())
	_check(menu.is_open and get_tree().paused, "tap on the menu button opened the menu and paused")
	_shot("6-menu")
	await _tap(menu, menu.PLAY_RECT.get_center())
	_check(not menu.is_open and not get_tree().paused and Engine.time_scale == 1.0, "Play closed the menu")
	await _tap(menu, btn.get_center())
	await _tap(menu, menu.HOME_RECT.get_center())
	await _frames(10)
	_check(not get_tree().paused and main.screen.get_script().resource_path.ends_with("map_screen.gd"), "Main Menu went back to the map")
	_check(not menu.visible, "no menu button on the map")
	_check(Music.playlist == "menu" and Music.current.begins_with("menu-"), "menu music on the map")

	# The exit door on a crossing already cleared: a tap about an inch to the
	# left of the door, outside the door itself, still leaves.
	main.screen.queue_free()
	var run := ScrollRun.new(Content.area("lava_scroll"), Content.grades()[1], 2)
	run.pos = run.length()
	run.phase = ScrollRun.CLEARED
	var done := ScrollScreen.new()
	done.setup(run, main.save.duplicate(true), false)
	main.stage.add_child(done)
	var left := [false]
	done.finished.connect(func(): left[0] = true)
	waited = 0
	while not done.hud_choice.active and waited < 600:
		await _frames(1)
		waited += 1
	_check(done.hud_choice.active, "cleared crossing waits for the door")
	await _frames(20)
	_shot("7-exit")
	var ex: Rect2 = done.exit_rect()
	await _tap(done.hud, Vector2(ex.position.x + 20, ex.get_center().y))
	waited = 0
	while not left[0] and waited < 300:
		await _frames(1)
		waited += 1
	_check(left[0], "tap an inch beside the door left the crossing")

	# Reset on the main menu: No keeps the save, a quick tap on Yes does
	# nothing, holding Yes for 3 seconds wipes gems, purchases and progress.
	done.queue_free()
	main.show_map()
	await _frames(10)
	main.save["gems"] = 7
	main.save["owned"] = ["bolt_red"]
	var m: Node2D = main.screen
	await _tap(m, m.RESET_RECT.get_center())
	_check(m.asking, "Reset asks first")
	_shot("8-reset-question")
	await _tap(m, m.NO_RECT.get_center())
	_check(not m.asking and int(main.save["gems"]) == 7, "No keeps the save")
	await _tap(m, m.RESET_RECT.get_center())
	await _tap(m, m.YES_RECT.get_center())
	_check(m.asking and int(main.save["gems"]) == 7, "a quick tap on Yes does nothing")
	var yes_at: Vector2 = get_viewport().get_screen_transform() * m.get_global_transform_with_canvas() * m.YES_RECT.get_center()
	await _touch(m, m.YES_RECT.get_center(), true)
	await get_tree().create_timer(1.5).timeout
	_check(is_instance_valid(m) and m.asking and int(main.save["gems"]) == 7, "half way through the hold nothing is reset")
	_shot("9-reset-holding")
	await get_tree().create_timer(1.8).timeout
	var lift := InputEventScreenTouch.new()
	lift.position = yes_at
	Input.parse_input_event(lift)
	await _frames(10)
	_check(int(main.save["gems"]) == 0 and main.save["owned"].is_empty() and main.save["run"] == null, "holding Yes reset the save")
	_check(main.screen != m and main.screen.get_script().resource_path.ends_with("map_screen.gd"), "back on a fresh main menu")

	print("TOUCH CHECK %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


## A finger press and lift at a point in `ci`'s local space.
## Waits out the 300 ms choice lockout first, as a child would.
func _tap(ci: CanvasItem, local: Vector2) -> void:
	# real time, so it also runs while the menu has the game stopped
	await get_tree().create_timer(0.5, true, false, true).timeout
	var at := get_viewport().get_screen_transform() * ci.get_global_transform_with_canvas() * local
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = at
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(3)


## One finger press (or lift) at a point in `ci`'s local space.
func _touch(ci: CanvasItem, local: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = get_viewport().get_screen_transform() * ci.get_global_transform_with_canvas() * local
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
