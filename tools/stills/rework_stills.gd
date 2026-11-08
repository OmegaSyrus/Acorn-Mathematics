## Stills of the 2026-11-07 rework (Terrence): the answer after the "=",
## the heart stone, block then shield bash, the miniboss's door, the map
## unlocking the next world and the boss fight's dashed aim line.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1024x768 \
##       res://tools/stills/rework_stills.tscn -- --out=/tmp/rework
extends Node2D

const SeededRng := preload("res://logic/core/rng.gd")
const Content := preload("res://logic/core/content.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const AreaFlow := preload("res://logic/path/area_flow.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")
const WorldMapScreen := preload("res://game/world_map_screen.gd")
const InputSetup := preload("res://game/input_setup.gd")

var out_dir := "/tmp"
var stage: Node2D


func _ready() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	stage = Node2D.new()
	add_child(stage)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	Ellwynn.offset = stage.position
	await _crossing()
	await _miss()
	await _fight()
	await _duel_door()
	await _map()
	await _boss()
	get_tree().quit()


## Blorp beaten (one heart lost), the heart stone next: a right answer goes
## green, the dragon jumps, walks on and the heart flies up to the row.
func _crossing() -> void:
	var area := Content.area("lava_scroll")
	var run := ScrollRun.new(area, Content.grades()[1], 2)
	var two: int = run.answers[0] + run.answers[1]
	run.pos = two
	run.target = two
	run.rolls = 2
	run.hearts = 2
	var s := ScrollScreen.new()
	s.setup(run, SaveData.new_profile("stills"), false)
	s.beaten[two] = true
	stage.add_child(s)
	await _frames(20)
	_shot("1-crossing-heart-ahead")
	s.rolled.emit()
	while not s.choice.active:
		await _frames(1)
	await _frames(20)
	s.choice.picked.emit(run.problem["answer_index"])
	await _frames(20)
	_shot("2-crossing-right-green")
	var waited := 0
	while s.heart_fly < 0.3 and waited < 600:
		await _frames(1)
		waited += 1
	_shot("3-crossing-heart-flying")
	await _frames(90)
	_shot("4-crossing-heart-got")
	s.queue_free()
	await _frames(2)


## 3 lives (2026-11-08): a wrong stone, the dragon starts to sink, hops back
## and a heart breaks; then the same guess is rolled again.
func _miss() -> void:
	var run := ScrollRun.new(Content.area("lava_scroll"), Content.grades()[1], 5)
	var s := ScrollScreen.new()
	s.setup(run, SaveData.new_profile("stills"), false)
	stage.add_child(s)
	await _frames(20)
	s.rolled.emit()
	while not s.choice.active:
		await _frames(1)
	await _frames(20)
	s.choice.close()
	s.choice.picked.emit((run.problem["answer_index"] + 1) % run.problem["choices"].size())
	while s.rock_sink < 0.3:
		await _frames(1)
	_shot("4a-miss-sinking")
	while s.heart_break < 0.3:
		await _frames(1)
	_shot("4b-miss-heart-breaks")
	while not s.tray_waiting:
		await _frames(1)
	await _frames(10)
	_shot("4c-miss-roll-again")
	Ellwynn.stop_voice()
	Ellwynn._set_mode("off")
	s.queue_free()
	await _frames(2)


func _fight() -> void:
	var f := FightScreen.new()
	f.setup(SeededRng.new(78), 1, "blorp", false, false, false, 4)
	stage.add_child(f)
	while not f.choice.active:
		await _frames(1)
	await _frames(20)
	_shot("5-fight-block")
	f.choice.close()
	f.choice.picked.emit(f.fight.attack.answer_index)
	await _secs(1.4)
	_shot("6-fight-blocked")
	while not f.choice.active:
		await _frames(1)
	await _frames(20)
	_shot("7-fight-shield-bash")
	var atk = f.fight.attack
	f.choice.close()
	f.choice.picked.emit((atk.answer_index + 1) % atk.choices.size())
	await _secs(1.9)
	_shot("8-fight-bash-missed")
	Ellwynn.stop_voice()
	Ellwynn._set_mode("off")
	f.queue_free()
	await _frames(2)


func _duel_door() -> void:
	var f := FightScreen.new()
	f.setup(SeededRng.new(78), 1, "lava_miniboss", false, true)
	stage.add_child(f)
	while not f.choice.active:
		await _frames(1)
	await _frames(20)
	_shot("9-duel-5-hearts")
	# skip ahead to the last shield bash
	f.fight.phase = f.fight.Phase.BASH
	f.fight.monster_hearts = 1
	f.shown_monster_hearts = 1
	f.choice.close()
	f.choice.picked.emit(f.fight.attack.answer_index)
	var waited := 0
	while f.door_alpha < 1.0 and waited < 1200:
		await _frames(1)
		waited += 1
	await _frames(30)
	_shot("10-duel-door")
	f.queue_free()
	await _frames(2)


func _map() -> void:
	var save := SaveData.new_profile("stills")
	var w := WorldMapScreen.new()
	w.setup(save, Content.worlds())
	stage.add_child(w)
	await _frames(30)
	_shot("11-map-start")
	w.queue_free()
	await _frames(2)
	AreaFlow.enter(save, Content.area("lava_scroll"), 1, AreaFlow.MAP)
	var w2 := WorldMapScreen.new()
	w2.setup(save, Content.worlds(), 1)
	stage.add_child(w2)
	await _secs(0.9)
	_shot("12-map-unlocking")
	await _secs(1.2)
	_shot("13-map-unlocked")
	w2.queue_free()
	await _frames(2)


func _boss() -> void:
	var b := BounceScreen.new()
	b.setup(SeededRng.new(11), 1)
	stage.add_child(b)
	while b.phase != "aiming":
		await _frames(1)
	b.aim = 120
	await _frames(20)
	_shot("14-boss-aim-line")
	b.aim = -260
	await _frames(10)
	_shot("15-boss-aim-line-left")
	b.queue_free()
	await _frames(2)


func _secs(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
