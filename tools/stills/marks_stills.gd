## Stills of the level marks and the Grown-ups panel (2026-11-12): the main
## menu with marks under the difficulty and the Grown-ups button being held,
## the map with marks and stars in every world, and the Grown-ups panel.
## Own save in memory.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/stills/marks_stills.tscn -- --out=/tmp/shots
extends Node2D

const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const MapScreen := preload("res://game/map_screen.gd")
const WorldMapScreen := preload("res://game/world_map_screen.gd")
const GrownUpsScreen := preload("res://game/grownups_screen.gd")
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
	var save := SaveData.new_profile("stills")
	save["ellwynn_intro_seen"] = true
	save["gems"] = 12
	save["difficulty"] = 2
	# lava levels 1-3 beaten (1 and 2 without losing a heart), crystal 1-2,
	# the Bog 2 crossing clean but its boss not yet beaten; a grown-up opened Space
	for p in [["lava_caves", [1, 2, 3], [1, 2]], ["crystal_mines", [1, 2], [2]], ["bog", [], [2]]]:
		for n in p[1]:
			SaveData.add_mark(save, p[0], Content.level_id(p[0], n))
		for n in p[2]:
			SaveData.add_star(save, p[0], Content.level_id(p[0], n))
	SaveData.set_parent_open(save, "space", true)

	var shown := {}
	for n in range(1, 7):
		shown[n] = {"id": n, "name": "Level %d" % n, "available": true}
	var m := MapScreen.new()
	m.setup(save, shown, "lava_scroll")
	stage.add_child(m)
	await _frames(6)
	_shot("marks-menu")
	m.gate_holding = true
	m.gate_t = 2.2
	m.set_process(false)
	m.queue_redraw()
	await _frames(3)
	_shot("marks-menu-holding")
	m.queue_free()
	Ellwynn.menu_leave()

	var w := WorldMapScreen.new()
	w.setup(save, Content.worlds(), -1, 2)
	stage.add_child(w)
	await _frames(6)
	_shot("marks-map")
	w.queue_free()

	var g := GrownUpsScreen.new()
	g.setup(save, Content.worlds())
	stage.add_child(g)
	await _frames(6)
	_shot("marks-grownups")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
