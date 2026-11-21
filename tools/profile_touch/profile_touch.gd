## Profile touch test (profile plan P6): a fresh install played with synthetic
## finger taps only. Two children are made, swapped, one is edited (name and
## picture) and one is removed, with a still after each step.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1340x800 \
##       res://tools/profile_touch/profile_touch.tscn -- --out=/tmp/ptouch
## Run it with a fresh user data dir (XDG_DATA_HOME=...), as a fresh install.
extends Node

const MainScene := preload("res://scenes/main.tscn")
const Profiles := preload("res://logic/core/profiles.gd")
const PinScreen := preload("res://game/pin_screen.gd")
const ProfileStore := preload("res://game/profile_store.gd")

var out_dir := "/tmp/ptouch"
var main: Node2D
var failures := 0
var shots := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = MainScene.instantiate()
	add_child(main)
	await _frames(30)
	_check(_on("profile_edit_screen.gd"), "fresh install opens the create screen")
	await _shot("create-1-pick")

	# Child 1: pick look 3, name "Ada", Yes.
	await _create("Ada", 3)
	_check(_on("map_screen.gd"), "Yes opened the main menu")
	_check(_names() == ["Ada"], "roster holds Ada: %s" % [_names()])
	await _shot("menu-ada")

	# Player button -> profile page -> Swap -> New (no PIN set yet) -> child 2.
	await _open_profile()
	await _shot("profile-ada")
	await _tap_act(1)  # Swap
	_check(_on("who_screen.gd"), "Swap opened Who is playing?")
	await _shot("who-1")
	await _tap_card("new")
	_check(_on("profile_edit_screen.gd"), "New opened the create screen")
	await _create("Bo", 8)
	_check(_on("map_screen.gd"), "second Yes opened the main menu")
	_check(_names() == ["Ada", "Bo"], "roster holds Ada and Bo: %s" % [_names()])
	_check(_active_name() == "Bo", "Bo is playing")
	await _shot("menu-bo")

	# Swap back to Ada.
	await _open_profile()
	await _tap_act(1)
	await _shot("who-2")
	await _tap_card(_id_of("Ada"))
	_check(_on("map_screen.gd"), "picking Ada opened the main menu")
	_check(_active_name() == "Ada", "Ada is playing after the swap")
	await _shot("menu-ada-again")

	# Edit Ada: set a PIN (first time), rename to "Ada Rose", new picture, Save.
	var ada_id := _id_of("Ada")
	await _open_profile()
	await _tap_act(2)  # Edit
	_check(_on("pin_screen.gd"), "Edit asks for a PIN")
	await _shot("pin-set")
	await _pin("2580")
	await _pin("2580")
	_check(_on("profile_edit_screen.gd"), "PIN set opened the edit screen")
	await _shot("edit-ada")
	var e: Node2D = main.screen
	await _tap_target(e, "tile_11")
	await _tap_target(e, "field")
	await _type("Rose")
	await _shot("edit-ada-typed")
	await _tap_target(e, "save")
	await _frames(20)
	_check(_on("profile_screen.gd"), "Save went back to the profile page")
	var a := Profiles.find(ProfileStore.roster, ada_id)
	_check(str(a.get("picture", "")) == Profiles.PICTURES[11], "Ada's picture changed to %s" % Profiles.PICTURES[11])
	# a tap on the box selects the old name, so typing replaces it
	_check(str(a.get("nickname", "")) == "Rose", "Ada is now called %s" % a.get("nickname", ""))
	await _shot("profile-ada-edited")

	# Remove Ada (the player) from her edit screen: PIN, Remove, hold 3 s.
	await _tap_act(2)
	_check(_on("pin_screen.gd"), "Edit asks for the PIN again")
	await _pin("2580")
	_check(_on("profile_edit_screen.gd"), "PIN opened the edit screen")
	e = main.screen
	await _tap_target(e, "remove")
	await _shot("remove-dialog")
	var r: Rect2 = e.dialog_rects()[1]
	await _touch(e, r.get_center(), true)
	await get_tree().create_timer(1.5, true, false, true).timeout
	await _shot("remove-holding")
	await get_tree().create_timer(2.0, true, false, true).timeout
	await _touch(e, r.get_center(), false)
	await _frames(20)
	_check(_names() == ["Bo"], "Rose removed, roster holds Bo: %s" % [_names()])
	_check(_active_name() == "Bo", "Bo plays on")
	await _shot("after-remove")
	await _back_to_menu()
	await _shot("menu-bo-after-remove")

	# The last child can't be removed.
	await _open_profile()
	await _tap_act(2)
	await _pin("2580")
	e = main.screen
	_check(_on("profile_edit_screen.gd") and not e.can_remove(), "Bo, the last child, has no Remove")
	await _shot("edit-bo-last")

	print("profile touch: %d failures, %d stills in %s" % [failures, shots, out_dir])
	get_tree().quit(1 if failures > 0 else 0)


func _create(name: String, tile: int) -> void:
	var e: Node2D = main.screen
	await _tap_target(e, "tile_%d" % tile)
	await _shot("create-%s-picked" % name)
	await _tap_target(e, "next")
	await _frames(10)
	# step 2: the field starts typing; clear it and type the name
	await _tap_target(e, "field")
	await _key(KEY_A, true)  # ctrl+a selects all
	await _type(name)
	await _shot("create-%s-name" % name)
	await _tap_target(e, "next")
	await _shot("create-%s-yes" % name)
	await _tap_target(e, "next")
	await _frames(20)


func _open_profile() -> void:
	if not _on("map_screen.gd"):
		await _back_to_menu()
	var m: Node2D = main.screen
	await _tap(m, m.PLAYER_RECT.get_center())
	await _frames(20)
	_check(_on("profile_screen.gd"), "player button opened the profile page")


func _back_to_menu() -> void:
	var s: Node2D = main.screen
	if s.has_method("targets") and _on("profile_screen.gd"):
		await _tap_act(0)
		await _frames(20)


func _tap_act(act: int) -> void:
	var s: Node2D = main.screen
	for a in s.acts:
		if int(a["act"]) == act:
			await _tap(s, (a["rect"] as Rect2).get_center())
			await _frames(20)
			return
	_check(false, "profile page has act %d" % act)


func _tap_card(id: String) -> void:
	var w: Node2D = main.screen
	for c in w.cards:
		if str(c["id"]) == id:
			await _tap(w, (c["rect"] as Rect2).get_center())
			await _frames(20)
			return
	_check(false, "Who is playing? has card %s" % id)


func _tap_target(s: Node2D, name: String) -> void:
	for t in s.targets():
		if t["name"] == name:
			await _tap(s, (t["rect"] as Rect2).get_center())
			await _frames(5)
			return
	_check(false, "target %s is on screen" % name)


func _pin(code: String) -> void:
	var p: Node2D = main.screen
	for ch in code:
		await _tap(p, PinScreen.key_rect(PinScreen.KEYS.find(ch)).get_center())
	await _frames(20)  # a full PIN submits itself, no OK


func _type(s: String) -> void:
	for ch in s:
		var e := InputEventKey.new()
		e.pressed = true
		e.unicode = ch.unicode_at(0)
		e.keycode = OS.find_keycode_from_string(ch)
		Input.parse_input_event(e)
		await _frames(2)
		e = e.duplicate()
		e.pressed = false
		Input.parse_input_event(e)
		await _frames(2)


func _key(k: Key, ctrl := false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.pressed = pressed
		e.keycode = k
		e.ctrl_pressed = ctrl
		Input.parse_input_event(e)
		await _frames(2)


func _on(script_end: String) -> bool:
	return main.screen != null and main.screen.get_script().resource_path.ends_with(script_end)


func _names() -> Array:
	var out := []
	for k in Profiles.children(ProfileStore.roster):
		out.append(str(k["nickname"]))
	return out


func _active_name() -> String:
	return str(ProfileStore.active().get("nickname", ""))


func _id_of(name: String) -> String:
	for k in Profiles.children(ProfileStore.roster):
		if str(k["nickname"]) == name:
			return str(k["id"])
	return ""


func _id_of_prefix(name: String) -> String:
	for k in Profiles.children(ProfileStore.roster):
		if str(k["nickname"]).begins_with(name):
			return str(k["id"])
	return ""


func _tap(ci: Variant, local: Vector2) -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	for pressed in [true, false]:
		await _touch(ci, local, pressed)


func _touch(ci: Variant, local: Vector2, pressed: bool) -> void:
	if not is_instance_valid(ci):  # the press already swapped the screen
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.pressed = false
		Input.parse_input_event(up)
		await _frames(3)
		return
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
	shots += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%02d-%s.png" % [out_dir, shots, name])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
