## Stills of each level's crossing (2026-11-08): the dice rolled and the stones
## offered, at the level's view (1x at Lava 1, half size after), and on drag
## levels the view dragged to the far stones.
##   xvfb-run godot --path . --rendering-driver opengl3 res://tools/stills/level_stills.tscn -- --out=/tmp/shots [--only=23]
extends Node2D

const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")

const AREAS := {"lava_caves": "lava_scroll", "crystal_mines": "crystal_scroll", "bog": "bog_scroll", "mushroom_forest": "mushroom_scroll", "space": "space_scroll"}

var out_dir := "/tmp"
var only := -1


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		if arg.begins_with("--only="):
			only = int(arg.substr(7))
	var stage := Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	var levels := Content.levels()
	var ids := levels.keys()
	ids.sort()
	for id in ids:
		if only >= 0 and id != only:
			continue
		var lv: Dictionary = levels[id]
		var run := ScrollRun.new(Content.area(AREAS[lv["world"]]), lv, 5 + id)
		var s := ScrollScreen.new()
		s.setup(run, {"gems": 6}, false)
		stage.add_child(s)
		await _frames(20)
		s.rolled.emit()
		while not s.choice.active:
			await _frames(1)
		await _frames(40)
		_shot("level-%d" % id)
		if s._can_drag():
			s.drag_off = s._drag_max()
			s.dragged = true
			await _frames(40)
			_shot("level-%d-dragged" % id)
		s.queue_free()
		await _frames(2)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
