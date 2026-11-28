## Probe (2026-11-17): real taps on the dice pips, in a fight and on the
## crossing, and a right pick; logs what Ellwynn plays for each.
##   godot --path . res://tools/voice_check/pip_probe.tscn
extends Node2D

const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const SeededRng := preload("res://logic/core/rng.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")


func _tap(at: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		await get_tree().process_frame


func _tap_pips(dice: Array, label: String) -> void:
	for d in dice:
		if not d.visible:
			continue
		for p in d.pip_points():
			await _tap(get_viewport().get_final_transform() * (d.get_global_transform_with_canvas() * p))
			await get_tree().create_timer(0.15).timeout
			print("%s tap: playing=%s file=%s bubble=%s" % [label, Ellwynn.player.playing, Ellwynn._cur_file.get_file(), Ellwynn.bubble])


func _ready() -> void:
	InputSetup.register()
	var f := FightScreen.new()
	f.setup(SeededRng.new(78), 2, "blorp", false, false)
	add_child(f)
	while not f.choice.active:
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	print("fight dice ", f.fight.attack.dice)
	await _tap_pips(f.dice, "fight")
	print("fight bubble after taps: '", f.bubble, "'")
	var atk = f.fight.attack
	f.choice.picked.emit(atk.answer_index)
	var heard := []
	for i in 60:
		await get_tree().create_timer(0.05).timeout
		var n: String = Ellwynn._cur_file.get_file()
		if Ellwynn.player.playing and (heard.is_empty() or heard[-1] != n):
			heard.append(n)
	print("fight right pick (answer ", atk.answer, "): ", heard)
	f.queue_free()
	Ellwynn.stop_voice()
	var run := ScrollRun.new(Content.area("lava_scroll"), Content.levels()[1], 2)
	var s := ScrollScreen.new()
	s.setup(run, {"gems": 6}, false)
	add_child(s)
	await get_tree().create_timer(0.5).timeout
	s.rolled.emit()
	while not s.choice.active:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await _tap_pips(s.dice, "crossing")
	get_tree().quit()
