## Stills of the family groundwork (2026-11-16): the main menu's player
## button, "Who is playing?", the PIN pad, the Grown-ups panel with Children
## and PIN, and the Children list. Own roster and save in memory.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/stills/family_stills.tscn -- --out=/tmp/shots
extends Node2D

const SaveData := preload("res://logic/core/save_data.gd")
const Profiles := preload("res://logic/core/profiles.gd")
const Content := preload("res://logic/core/content.gd")
const MapScreen := preload("res://game/map_screen.gd")
const WhoScreen := preload("res://game/who_screen.gd")
const PinScreen := preload("res://game/pin_screen.gd")
const GrownUpsScreen := preload("res://game/grownups_screen.gd")
const ChildrenScreen := preload("res://game/children_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")

var out_dir := "/tmp"
var stage: Node2D


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	stage = Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	Ellwynn.offset = stage.position
	var r := Profiles.new_roster(0)
	Profiles.rename(r, r["active"], "Bear")
	Profiles.rename(r, Profiles.add_child(r, 0)["id"], "Wren")
	Profiles.rename(r, Profiles.add_child(r, 0)["id"], "Sam")
	var save := SaveData.new_profile(r["active"])
	save["ellwynn_intro_seen"] = true
	save["gems"] = 12

	var shown := {}
	for n in range(1, 7):
		shown[n] = {"id": n, "name": "Level %d" % n, "available": true}
	var m := MapScreen.new()
	m.setup(save, shown, "lava_scroll")
	m.player = {"nickname": "Bear", "picture": "fox"}
	stage.add_child(m)
	await _frames(6)
	_shot("family-menu")
	m.queue_free()
	Ellwynn.menu_leave()

	var w := WhoScreen.new()
	w.setup(r, true)
	stage.add_child(w)
	await _frames(4)
	_shot("family-who")
	w.queue_free()

	Profiles.set_pin(r, "1234")
	var p := PinScreen.new()
	p.setup(r, PinScreen.Mode.ENTER)
	stage.add_child(p)
	p.typed = "12"
	await _frames(4)
	_shot("family-pin")
	p._start_forgot()
	p.typed = "1"
	p.queue_redraw()
	await _frames(3)
	_shot("family-pin-forgot")
	p.queue_free()

	var g := GrownUpsScreen.new()
	g.setup(save, Content.worlds())
	g.has_pin = true
	stage.add_child(g)
	await _frames(4)
	_shot("family-grownups")
	g.queue_free()

	var c := ChildrenScreen.new()
	c.setup(r)
	stage.add_child(c)
	c.hold_row = 2
	c.hold_t = 1.8
	c.set_process(false)
	await _frames(4)
	c.queue_redraw()
	await _frames(2)
	_shot("family-children")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
