## Taps through the main menu's Debug screen with synthetic touches: opens it,
## turns "Map: all open" on, then jumps to every built world's crossing,
## miniboss and boss at level 4 and checks the right screen comes up.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1340x800 \
##       res://tools/debug_check/debug_check.tscn -- --out=/tmp/debug
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
	var m: Node2D = main.screen
	await _shot("0-menu")
	var stage_names := {"": "scroll_screen.gd", "duel": "fight_screen.gd", "boss": "bounce_screen.gd"}
	var first := true
	for row in 4:  # Lava, Crystal Mines, the Bog, Mushroom Forest
		for st in ["", "duel", "boss"]:
			m = main.screen
			_check(m.get_script().resource_path.ends_with("map_screen.gd"), "main menu showing")
			await _tap(m, m.DEBUG_RECT.get_center())
			await _frames(20)
			var d: Node2D = main.screen
			_check(d.get_script().resource_path.ends_with("debug_screen.gd"), "Debug opened the debug screen")
			if first:
				await _tap(d, d.UNLOCK_RECT.get_center())
				await _frames(5)
				_check(bool(main.save.get("debug_unlock", false)), "Map: all open turned on")
				await _tap(d, Rect2(Vector2(d.LEVEL_X + 3 * (d.LEVEL_SIZE.x + 10), d.LEVEL_Y), d.LEVEL_SIZE).get_center())
				await _frames(5)
				_check(d.level == 4, "level 4 picked")
				await _shot("1-debug")
				first = false
			var s := ["", "duel", "boss"].find(st)
			await _tap(d, Rect2(Vector2(d.STAGE_X[s], d.ROW_Y[row]), d.STAGE_SIZE).get_center())
			await _frames(40)
			var scr: Node2D = main.screen
			var ok: bool = scr.get_script().resource_path.ends_with(stage_names[st])
			_check(ok, "row %d %s opened %s (got %s)" % [row, st, stage_names[st], scr.get_script().resource_path])
			await _frames(60)
			await _shot("2-row%d-%s" % [row, st if st != "" else "walk"])
			main.show_map()
			await _frames(20)
	# the world map with everything open
	main.show_world_map()
	await _frames(30)
	await _shot("3-world-map-all-open")
	print("debug check: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _tap(ci: CanvasItem, local: Vector2) -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	var at := get_viewport().get_screen_transform() * ci.get_global_transform_with_canvas() * local
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = at
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(3)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
