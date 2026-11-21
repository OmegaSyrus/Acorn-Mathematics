## Touch check and stills for the create and edit profile screen (profile
## plan P3). Real screen touches go in through Input, at the window's size
## with the stage centred as main.gd does: CREATE picks a tile, types a name
## too long, goes back and on, and taps Yes; EDIT picks a tile, saves, opens
## Remove and holds it for 3 seconds. Checks the signals and a few pixels.
## Exit code 1 if a check fails.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 res://tools/stills/profile_edit_stills.tscn -- --out=/tmp/shots
##   (and again with --resolution 720x540)
extends Node2D

const M3 := preload("res://game/ui/m3.gd")
const Screen := preload("res://game/profile_edit_screen.gd")
const Profiles := preload("res://logic/core/profiles.gd")
const InputSetup := preload("res://game/input_setup.gd")

var out_dir := "/tmp"
var stage: Node2D
var failed := 0
var tag := ""
var s: Screen


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(1, 0, 1))
	InputSetup.register()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	await _frames(2)
	var shown := get_viewport_rect().size
	tag = "%dx%d" % [shown.x, shown.y]
	stage = Node2D.new()
	add_child(stage)
	stage.position = ((shown - M3.DESIGN) / 2.0).round()
	await _create_flow()
	await _edit_flow()
	print("profile edit stills %s: %s" % [tag, "ok" if failed == 0 else "%d failed" % failed])
	get_tree().quit(1 if failed > 0 else 0)


func _create_flow() -> void:
	var r := Profiles.new_roster(100)
	Profiles.add_child(r, 101, "Wren", "bunny")
	var got := []
	var backs := [0]
	s = Screen.new()
	s.setup(r, Screen.Mode.CREATE)
	s.created.connect(func(n, p): got.append([n, p]))
	s.back.connect(func(): backs[0] += 1)
	stage.add_child(s)
	await _frames(3)
	var img := _shot("create-1-pick")
	_near(img, Vector2(4, 400) - stage.position, M3.SURFACE, "screen edge is the surface")
	await _touch("tile_9")
	_check(s.picture == Profiles.PICTURES[9], "touch on tile 9 picks %s (got %s)" % [Profiles.PICTURES[9], s.picture])
	img = _shot("create-1-picked")
	_near(img, Screen.tile_rect(9, Screen.PICK_TILE_Y).position + Vector2(48, 3), M3.GOLD, "chosen tile ring")
	_near(img, s.next_button_rect().position + Vector2(s.next_button_rect().size.x / 2.0, 6), M3.PRIMARY, "Next is filled")
	await _touch("next")
	_check(s.step == Screen.Step.NAME, "touch on Next opens Name")
	await _frames(3)
	_check(s.line.visible and s.line.has_focus(), "the name box takes typing on the Name step")
	for c in "Bartholomew The Great":
		var k := InputEventKey.new()
		k.pressed = true
		k.unicode = c.unicode_at(0)
		k.keycode = OS.find_keycode_from_string(c) if c != " " else KEY_SPACE
		Input.parse_input_event(k)
		await _frames(1)
		var up := k.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
	await _frames(2)
	_check(s.name_text.length() == 12, "typed name is cut to 12 (%s)" % s.name_text)
	_shot("create-2-name")
	await _touch("nav_back")
	_check(s.step == Screen.Step.PICK, "touch on Back goes back to Pick")
	await _touch("next")
	await _touch("next")
	_check(s.step == Screen.Step.CONFIRM, "Next, Next reaches Yes")
	_shot("create-3-yes")
	await _touch("next")
	_check(got == [["Bartholomew", Profiles.PICTURES[9]]], "touch on Yes emits created (%s)" % [got])
	_check(backs[0] == 0, "no back emitted")
	s.queue_free()
	await _frames(2)


func _edit_flow() -> void:
	var r := Profiles.new_roster(100)
	var kid := Profiles.add_child(r, 101, "Wren", "bunny")
	var saves := []
	var removes := []
	s = Screen.new()
	s.setup(r, Screen.Mode.EDIT, kid["id"])
	s.saved.connect(func(id, n, p): saves.append([id, n, p]))
	s.removed.connect(func(id): removes.append(id))
	stage.add_child(s)
	await _frames(3)
	_shot("edit")
	await _touch("tile_0")
	await _touch("save")
	_check(saves == [[kid["id"], "Wren", "robodragon"]], "touch on Save emits saved (%s)" % [saves])
	await _touch("remove")
	_check(s.dialog_open, "touch on Remove opens the dialog")
	await _frames(2)
	_shot("edit-remove-dialog")
	var rr: Rect2 = s.dialog_rects()[1]
	var at := stage.position + rr.get_center()
	_press(at, true)
	await get_tree().create_timer(1.5).timeout
	_check(removes.is_empty(), "1.5 s hold does not remove")
	_shot("edit-remove-holding")
	await get_tree().create_timer(1.8).timeout
	_press(at, false)
	await _frames(2)
	_check(removes == [kid["id"]], "3 s hold emits removed (%s)" % [removes])
	s.queue_free()
	await _frames(2)


## A real touch, press and release, in the middle of target `name`.
func _touch(name: String) -> void:
	await get_tree().create_timer(0.35).timeout  # ChoiceWidget's input gate
	var rect := Rect2()
	for t in s.targets():
		if t["name"] == name:
			rect = t["rect"]
	_check(rect.has_area(), "target %s is on screen" % name)
	var at := stage.position + rect.get_center()
	_press(at, true)
	await _frames(1)
	_press(at, false)
	await _frames(2)


func _press(at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = at
	e.pressed = down
	Input.parse_input_event(e)


func _near(img: Image, p: Vector2, col: Color, what: String) -> void:
	var at := Vector2i((stage.position + p).round())
	at = at.clamp(Vector2i.ZERO, Vector2i(img.get_width() - 1, img.get_height() - 1))
	var got := img.get_pixelv(at)
	var d := absf(got.r - col.r) + absf(got.g - col.g) + absf(got.b - col.b)
	_check(d < 0.15, "%s at %s: got %s want %s" % [what, at, got.to_html(false), col.to_html(false)])


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failed += 1
		print("FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> Image:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join("profile-%s-%s.png" % [name, tag]))
	return img
