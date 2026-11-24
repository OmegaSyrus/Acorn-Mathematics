## Stills of the half-size crossings (art grid plan 2026-11-24): for level 2
## of each world, the stones offered, then a monster met beside the hero.
## Shows the half-size sprites (game/ui/half_art.gd).
##   godot --headless --path . --import
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1340x800 res://tools/stills/half_stills.tscn -- --out=/tmp/shots
extends Node2D

const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")

const AREAS := {"lava_caves": "lava_scroll", "crystal_mines": "crystal_scroll", "bog": "bog_scroll", "mushroom_forest": "mushroom_scroll", "space": "space_scroll"}
const IDS := [12, 22, 32, 42, 52]

var out_dir := "/tmp"


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	var stage := Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	var levels := Content.levels()
	for id in IDS:
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
		_shot("half-%d" % id)
		s.choice.close()
		var mpos := -1
		for at in range(1, s.run.length()):
			if s.run.space_at(at).get("type") == "monster":
				mpos = at
				break
		if mpos > 0:
			s._place_hero(mpos)
			s.revealed = mpos
			s.reveal = 1.0
			s.bubble = "Fight!"
			s._hide_dice()
			await _frames(30)
			_shot("half-%d-monster" % id)
		s.queue_free()
		await _frames(2)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
