## Plays one Blorp fight by itself: a wrong shield (the hero blinks red and
## its heart swells and breaks), then right shields until Blorp falls (Blorp
## blinks red and loses a heart each time). Saves a still every 6 frames
## while a heart breaks; also fine to record with --write-movie.
##   xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 \
##       res://tools/stills/heart_stills.tscn -- --out=/tmp/shots
extends Node2D

const SeededRng := preload("res://logic/core/rng.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")

var out_dir := ""
var _n := 0


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	var stage := Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	var f := FightScreen.new()
	f.setup(SeededRng.new(78), 1, "blorp")
	stage.add_child(f)
	var wrong_done := false
	var ended := [false]
	f.done.connect(func(_won: bool) -> void: ended[0] = true)
	while not ended[0]:
		await get_tree().process_frame
		if f.choice.active:
			await _frames(20)
			var atk = f.fight.attack
			var pick: int = atk.answer_index
			if not wrong_done:
				pick = (pick + 1) % atk.choices.size()
				wrong_done = true
			f.choice.close()
			f.choice.picked.emit(pick)
		elif (f.hero_break >= 0.0 or f.monster_break >= 0.0) and _tick() % 6 == 0:
			_shot()
	await _frames(15)
	get_tree().quit()


var _ticks := 0


func _tick() -> int:
	_ticks += 1
	return _ticks


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot() -> void:
	if out_dir == "":
		return
	_n += 1
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("heart-%03d.png" % _n))
