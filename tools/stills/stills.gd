## Saves stills of a tumbling die and of the fight screen per grade, for
## checking looks.
##   xvfb-run godot --path . --rendering-driver opengl3 res://tools/stills/stills.tscn -- --out=/tmp/shots
extends Node2D

const SeededRng := preload("res://logic/core/rng.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")
const DieView := preload("res://game/ui/die_view.gd")

var out_dir := "/tmp"


func _ready() -> void:
	InputSetup.register()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	var stage := Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	var bg := ColorRect.new()
	bg.color = Color(0.3, 0.6, 0.3)
	bg.size = Vector2(960, 540)
	stage.add_child(bg)
	var dice := []
	for i in 2:
		var d := DieView.new()
		d.scale = Vector2(2, 2)
		d.position = Vector2(330 + i * 300, 300)
		stage.add_child(d)
		d.slip = i == 1
		d.roll_to(5 - i)
		dice.append(d)
	for k in 16:
		await _frames(3)
		_shot("die-%02d" % k)
	for d in dice:
		d.queue_free()
	bg.queue_free()
	for g in [1, 2, 3, 4]:
		var f := FightScreen.new()
		f.setup(SeededRng.new(77 + g), g, "blorp" if g % 2 == 1 else "craggy")
		stage.add_child(f)
		await _frames(30)
		_shot("fight-%d-rolling" % g)
		while not f.choice.active:
			await _frames(1)
		await _frames(20)
		_shot("fight-%d-pick" % g)
		f.choice._pick(f.fight.attack.answer_index)
		await _frames(40)
		_shot("fight-%d-answered" % g)
		f.queue_free()
		await _frames(2)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
