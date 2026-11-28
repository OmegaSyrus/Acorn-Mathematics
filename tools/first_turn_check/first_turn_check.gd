## Phase 3: a new child's first turn on Lava 1, with real taps, then the
## same child again (taught: no hand, no T lines), then a first fight.
## Prints each step and fails (exit 1) when the taught steps come out of
## order or a taught child still gets a hand. With --out it saves stills
## of each hint (needs a display: xvfb-run).
##   godot --headless --path . res://tools/first_turn_check/first_turn_check.tscn
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 \
##       res://tools/first_turn_check/first_turn_check.tscn -- --out=/tmp/first_turn
extends Node2D

const Content := preload("res://logic/core/content.gd")
const ScrollRun := preload("res://logic/path/scroll_run.gd")
const ScrollScreen := preload("res://game/scroll_screen.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")
const SeededRng := preload("res://logic/core/rng.gd")
const SaveStore := preload("res://game/save_store.gd")
const InputSetup := preload("res://game/input_setup.gd")

var out_dir := ""
var failures := 0
var save := {"gems": 0}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
			DirAccess.make_dir_recursive_absolute(out_dir)
	InputSetup.register()
	# its own save folder: never a real child's
	SaveStore.dir = "user://first_turn_check/"
	DirAccess.make_dir_recursive_absolute(SaveStore.dir)
	await _new_child_crossing()
	await _taught_child_crossing()
	await _first_fight()
	await _first_duel()
	print("first turn check: %s" % ("ok" if failures == 0 else "%d failed" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _new_child_crossing() -> void:
	var s := _crossing(7)
	await _until(func(): return s.tray_waiting, 10.0)
	await _wait(1.00)
	_check(s.tutor.is_on("T2"), "new child: the Roll step is taught (T2)")
	await _shot("T2-roll")
	await _tap(s, s.TRAY.get_center())
	await _until(func(): return s.choice.active, 10.0)
	await _wait(0.50)
	_check(s.tutor.is_on("T3"), "the die lands: count the dots (T3)")
	_check(Ellwynn.was_taught("T2", save), "T2 marked once Roll was tapped")
	await _shot("T3-die")
	# tap one pip: the count was the step, the stones come next
	var d = s.dice[0]
	await _tap(d, d.pip_points()[0])
	await _wait(0.50)
	_check(s.tutor.is_on("T4"), "after a pip tap: the stones (T4)")
	await _shot("T4-stones")
	var right: int = int(s.run.problem["answer_index"])
	await _tap(s.choice, s.choice._rect(right).get_center())
	await _wait(0.50)
	_check(s.tutor.is_on("T5"), "a stone selected: Go (T5)")
	_check(Ellwynn.was_taught("T15", save), "first pip tap taught (T15)")
	await _shot("T5-go")
	await _tap(s.choice, s.choice.go_rect().get_center())
	await _wait(0.50)
	_check(s.tutor.steps.current == "", "picked: no hint left")
	for id in ["T1", "T3", "T4", "T5"]:
		_check(Ellwynn.was_taught(id, save), "%s marked after the first turn" % id)
	await _until(func(): return s.tray_waiting, 20.0)
	await _wait(1.50)
	_check(Ellwynn.was_taught("T6", save), "first right hop said (T6)")
	_check(not s.tutor.is_on("T2"), "second turn: no Roll hand")
	# a wrong stone: what hearts are, once
	await _tap(s, s.TRAY.get_center())
	await _until(func(): return s.choice.active, 10.0)
	await _wait(0.5)
	var wrong: int = (int(s.run.problem["answer_index"]) + 1) % int(s.choice.rects.size())
	await _tap(s.choice, s.choice._rect(wrong).get_center())
	await _wait(0.25)
	await _tap(s.choice, s.choice.go_rect().get_center())
	await _until(func(): return s.tray_waiting, 20.0)
	await _until(func(): return Ellwynn.was_taught("T7", save), 10.0)
	_check(Ellwynn.was_taught("T7", save), "first wrong stone explained (T7)")
	s.queue_free()
	Ellwynn.stop_voice()
	await _wait(0.25)


func _taught_child_crossing() -> void:
	var s := _crossing(11)
	await _until(func(): return s.tray_waiting, 10.0)
	await _wait(1.00)
	_check(s.tutor.steps.current == "", "taught child: no hand at Roll")
	await _tap(s, s.TRAY.get_center())
	await _until(func(): return s.choice.active, 10.0)
	await _wait(1.00)
	_check(s.tutor.steps.current == "", "taught child: no hand on the die or stones")
	_check(Ellwynn.last_prompt == "P4", "taught child: the question is the prompt (%s)" % Ellwynn.last_prompt)
	s.queue_free()
	Ellwynn.stop_voice()
	await _wait(0.25)


func _first_fight() -> void:
	var f := FightScreen.new()
	f.save = save
	f.setup(SeededRng.new(78), 1, "blorp", false, false)
	add_child(f)
	await _until(func(): return f.choice.active, 15.0)
	await _wait(0.50)
	_check(f.tutor.is_on("T9"), "first fight: pick a shield (T9)")
	await _shot("T9-shields")
	var atk = f.fight.attack
	await _tap(f.choice, f.choice._rect(atk.answer_index).get_center())
	await _wait(0.25)
	await _shot("T9-select")
	await _tap(f.choice, f.choice.go_rect().get_center())
	await _until(func(): return f.choice.active, 25.0)
	await _wait(0.50)
	_check(f.tutor.is_on("T10"), "first shield bash taught (T10)")
	await _shot("T10-bash")
	f.queue_free()
	Ellwynn.stop_voice()


func _first_duel() -> void:
	var f := FightScreen.new()
	f.save = save
	f.setup(SeededRng.new(5), 1, "lava_miniboss", false, true)
	add_child(f)
	await _until(func(): return f.choice.active, 15.0)
	await _wait(0.5)
	_check(f.tutor.is_on("T13"), "first miniboss duel taught (T13)")
	await _shot("T13-duel")
	var atk = f.fight.attack
	await _tap(f.choice, f.choice._rect(atk.answer_index).get_center())
	await _wait(0.25)
	await _tap(f.choice, f.choice.go_rect().get_center())
	await _wait(0.5)
	_check(Ellwynn.was_taught("T13", save) and f.tutor.steps.current == "", "duel: picked, no hint left")
	f.queue_free()
	Ellwynn.stop_voice()


func _crossing(seed_value: int) -> Node2D:
	var run := ScrollRun.new(Content.area("lava_scroll"), Content.levels()[1], seed_value)
	var s := ScrollScreen.new()
	s.setup(run, save, false)
	add_child(s)
	return s


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _tap(ci: CanvasItem, local: Vector2) -> void:
	var at: Vector2 = get_viewport().get_final_transform() * (ci.get_global_transform_with_canvas() * local)
	for down in [true, false]:
		var e := InputEventScreenTouch.new()
		e.pressed = down
		e.position = at
		Input.parse_input_event(e)
		await _wait(0.05)


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _until(cond: Callable, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not cond.call() and Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
