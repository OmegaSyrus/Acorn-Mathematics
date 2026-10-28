## Plays the game by itself for a recorded demo. It taps with real touch
## events (Input.parse_input_event), so the screens see the same input a
## child's finger makes, and draws a finger dot where it taps.
##   xvfb-run godot --path . --rendering-driver opengl3 --write-movie out.avi \
##       --fixed-fps 30 res://tools/demo/demo.tscn -- --demo=crossing --seed=2
## --demo=crossing plays the 40-space lava crossing at Acorn from the map:
## a right hop, a wrong hop on purpose (sink and restart), then a clean run
## with every chest and fight on the way. --demo=bounce plays one Match
## Bounce boss fight (best aim; above Acorn, one wrong name on purpose).
extends Node2D

const InputSetup := preload("res://game/input_setup.gd")
const SeededRng := preload("res://logic/core/rng.gd")
const BounceScreen := preload("res://game/bounce/bounce_screen.gd")
const BounceSim := preload("res://logic/bounce/bounce_sim.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const MainScene := preload("res://scenes/main.tscn")

const THINK_S := 0.7      # pause before each tap, like a child looking
const GLIDE_S := 0.45     # finger travel time
const WRONG_HOP_TURN := 2 # the crossing turn that picks a wrong rock
const WRONG_NAME_SHOT := 2 # the bounce shot that names a wrong face

var mode := "crossing"
var seed_value := 2
var finger: Node2D
var finger_pos := Vector2(480, 300)
var finger_down := false
var ripple := 0.0
var bounce_over := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo="):
			mode = arg.substr(7)
		elif arg.begins_with("--seed="):
			seed_value = arg.substr(7).to_int()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	finger = Node2D.new()
	layer.add_child(finger)
	finger.draw.connect(_draw_finger)
	seed(seed_value)
	if mode == "bounce":
		_bounce()
	else:
		_crossing()


func _process(delta: float) -> void:
	ripple = maxf(0.0, ripple - delta * 2.5)
	finger.queue_redraw()


func _draw_finger() -> void:
	if ripple > 0.0:
		finger.draw_arc(finger_pos, 22.0 + (1.0 - ripple) * 30.0, 0, TAU, 32, Color(1, 1, 1, ripple), 3.0)
	var r := 13.0 if finger_down else 16.0
	finger.draw_circle(finger_pos, r + 3.0, Color(0, 0, 0, 0.45))
	finger.draw_circle(finger_pos, r, Color(1, 1, 1, 0.85 if finger_down else 0.6))


# --- the lava crossing ------------------------------------------------------

func _crossing() -> void:
	var main := MainScene.instantiate()
	add_child(main)
	move_child(main, 0)
	await _wait(1.2)
	# the map: Acorn is the first grade button
	var map = main.screen
	await _tap_choice(map.choice, 0)
	var turn := 0
	var first_fight = null
	while true:
		await get_tree().process_frame
		var s = main.screen
		if not (s is ScrollScreen):
			# back on the map after the crossing
			await _wait(1.5)
			get_tree().quit()
			return
		var fight := _fight_in(s)
		if fight != null:
			if fight.choice.active:
				await _wait(THINK_S + 0.4)
				if fight.choice.active:
					var pick: int = fight.fight.attack.answer_index
					if first_fight == null:
						# one wrong shield in the first fight, to show a hit
						first_fight = fight
						pick = (pick + 1) % fight.fight.attack.choices.size()
					await _tap_choice(fight.choice, pick)
			continue
		if s.tray_waiting:
			await _wait(THINK_S)
			await _tap_at(s.hud, s.TRAY.get_center() + Vector2(0, 50))
			continue
		if s.choice.active:
			turn += 1
			await _wait(THINK_S + 0.5)
			var pick: int = s.run.problem["answer_index"]
			if turn == WRONG_HOP_TURN:
				# a wrong rock on purpose: the farthest wrong choice
				var n: int = s.run.problem["choices"].size()
				pick = (pick + n - 1) % n if pick > 0 else 1
			await _tap_choice(s.choice, pick)
			continue
		if s.hud_choice.active:
			await _wait(1.2)
			await _tap_choice(s.hud_choice, 0)


func _fight_in(s: Node) -> FightScreen:
	for c in s.get_children():
		if c is FightScreen:
			return c
	return null


# --- Match Bounce -------------------------------------------------------------

func _bounce() -> void:
	InputSetup.register()
	RenderingServer.set_default_clear_color(Color(0.05, 0.03, 0.03))
	var stage := Node2D.new()
	add_child(stage)
	move_child(stage, 0)
	stage.position = ((get_viewport_rect().size - Vector2(960, 540)) / 2.0).round()
	var s := BounceScreen.new()
	s.setup(SeededRng.new(seed_value), 1)
	stage.add_child(s)
	s.done.connect(func(_won): bounce_over = true)
	var shot := 0
	await _wait(1.0)
	while not bounce_over and s.phase != "lost":
		await get_tree().process_frame
		if s.phase == "naming" and s.choice.active:
			shot += 1
			await _wait(THINK_S + 0.3)
			var f = s.fight
			var idx: int = f.choices.find(f.answer_face)
			if shot == WRONG_NAME_SHOT:
				idx = (idx + 1) % f.choices.size()
			await _tap_choice(s.choice, idx)
			await _wait(0.4)
			await _aim_and_fire(s, _best_aim(f))
		elif s.phase == "aiming" and s.fight.auto_name():
			# Acorn: the ball took the boss's roll, so go straight to aiming
			await _wait(THINK_S)
			await _aim_and_fire(s, _best_aim(s.fight))
	await _wait(2.0)
	get_tree().quit()


## Touch the board below the launcher, drag to the aim, let go.
func _aim_and_fire(s, aim: int) -> void:
	var l: Vector2 = BounceSim.launcher(s.fight.board)
	var a := deg_to_rad(aim / 10.0)
	var start := l + Vector2(0, 200)
	var goal := l + Vector2(sin(a), cos(a)) * 200.0
	await _glide(_to_canvas(s, start))
	_touch(true, finger_pos)
	await _wait(0.15)
	var steps := 18
	for i in range(1, steps + 1):
		var p: Vector2 = start.lerp(goal, float(i) / steps)
		_drag(_to_canvas(s, p))
		await get_tree().process_frame
	await _wait(0.4)
	_touch(false, finger_pos)


func _best_aim(fight) -> int:
	var best := 0
	var best_damage := -1
	for a in range(-650, 651, 25):
		var sim = fight.preview_sim(a)
		sim.run()
		if sim.damage > best_damage:
			best_damage = sim.damage
			best = a
	return best


# --- fingers ----------------------------------------------------------------

func _tap_choice(choice, index: int) -> void:
	var r: Rect2 = choice.rects[index]
	await _tap_at(choice, r.get_center())


func _tap_at(ci: CanvasItem, local: Vector2) -> void:
	await _glide(_to_canvas(ci, local))
	_touch(true, finger_pos)
	await _wait(0.12)
	_touch(false, finger_pos)
	await _wait(0.2)


func _to_canvas(ci: CanvasItem, local: Vector2) -> Vector2:
	return ci.get_global_transform_with_canvas() * local


func _glide(to: Vector2) -> void:
	var from := finger_pos
	var tw := create_tween()
	tw.tween_method(func(t: float): finger_pos = from.lerp(to, t), 0.0, 1.0, GLIDE_S) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _window_pos(canvas: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * canvas


func _touch(pressed: bool, at: Vector2) -> void:
	finger_down = pressed
	if pressed:
		ripple = 1.0
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = _window_pos(at)
	Input.parse_input_event(e)


func _drag(at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = _window_pos(at)
	e.relative = _window_pos(at) - _window_pos(finger_pos)
	finger_pos = at
	Input.parse_input_event(e)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
