## The path graybox: one area run with placeholder shapes. Drives AreaRun
## (all rules live there) and only animates what it returns. Drawn in the
## 960x540 design space; everything that matters stays inside x 120..840.
extends Node2D

signal finished

const AreaRun := preload("res://logic/path/area_run.gd")
const SaveData := preload("res://logic/core/save_data.gd")
const InputGate := preload("res://logic/core/input_gate.gd")
const JsonUtil := preload("res://logic/core/json_util.gd")
const SaveStore := preload("res://game/save_store.gd")
const DieView := preload("res://game/ui/die_view.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const DiceDraw := preload("res://game/ui/dice_draw.gd")
const Pointer := preload("res://game/ui/pointer.gd")
const FightScreen := preload("res://game/fight/fight_screen.gd")

const START := Vector2(180, 250)
const STEP := 85.0
const ROW2_Y := 380.0
const ROW_LEN := 7
const TRAY := Rect2(232, 430, 384, 106)
const ELF := Rect2(736, 436, 96, 96)
const GATE_X := 477.0
const CHEST_POS := Vector2(645, 125)
const GO_RECT := Rect2(744, 200, 96, 96)
const KEY_SIZE := Vector2(124, 84)
const KEY_Y := 345.0
const DEBUG_CORNER := Rect2(120, 0, 90, 60)
const ROLL_ON_TAP := true  # the plan says flick; a plain tap also rolls for now
const FLICK_PX := 24.0
const HOP_S := 0.28

const LAVA := Color(0.86, 0.32, 0.06)
const ROCK := Color(0.42, 0.36, 0.33)
const ROCK_HI := Color(0.72, 0.66, 0.6)
const INK := Color(0.96, 0.94, 0.9)

var run: AreaRun
var save: Dictionary
var debug_on := false

var dice: Array = []
var choice: ChoiceWidget
var overlay: Node2D
var tray_gate := InputGate.new()
var tray_waiting := false
var _tray_down := false
var _tray_down_at := Vector2.ZERO
var _corner_down_ms := -1

var max_stone := 8
var hero_pos := START
var hero_drop := 0.0
var hero_alpha := 1.0
var choice_stones: Array = []
var crumbled := -1
var crumble := 0.0
var gate := ""  # "", "closed", "open"
var gate_lift := 0.0
var chest := ""  # "", "closed", "open", "shut"
var chest_shake := 0.0
var sticker := ""
var keys: Array = []
var turned_key := -1
var bubble := ""
var question := ""
var elf_hop := 0.0
var fade := 0.0
var cleared_banner := false
var _t := 0.0

signal rolled


func setup(area_run: AreaRun, profile: Dictionary, show_debug: bool) -> void:
	run = area_run
	save = profile
	debug_on = show_debug


func _ready() -> void:
	for i in 2:
		var d := DieView.new()
		d.visible = false
		add_child(d)
		d.pip_tapped.connect(_on_pip_tapped)
		dice.append(d)
	choice = ChoiceWidget.new()
	add_child(choice)
	overlay = Node2D.new()
	overlay.z_index = 10
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)
	_loop()


# --- the task loop ---------------------------------------------------------

func _loop() -> void:
	var first := true
	while true:
		if not first:
			await _fade_to(1.0)
		_layout_task()
		if not first:
			await _fade_to(0.0)
		first = false
		if run.phase == AreaRun.CLEARED:
			await _area_cleared()
			finished.emit()
			return
		if run.phase == AreaRun.AWAIT_FIGHT:
			await _fight(false)
			_save_progress()
			continue
		if run.phase == AreaRun.AWAIT_CHEST:
			_ask("Open?")
			choice.present([Rect2(CHEST_POS - Vector2(50, 40), Vector2(100, 80)), GO_RECT])
			var open_pick: int = await choice.picked
			if run.decide_chest(open_pick == 0)["result"] == "walk_past":
				await _walk_to(_stone_pos(ROW_LEN))
				_save_progress()
				continue
		_ask("Roll!")
		await _wait_for_roll()
		var p := run.roll()
		await _roll_dice(p["dice"])
		_present_choices(p)
		var pick: int = await choice.picked
		var out := run.choose(pick)
		for d in dice:
			if d.visible:
				d.show_numeral()
		_say(str(p["answer"]))
		await _play_outcome(p, pick, out)
		_save_progress()


func _layout_task() -> void:
	var task := run.current_task()
	var kind: String = task.get("type", "")
	hero_pos = START
	hero_drop = 0.0
	hero_alpha = 1.0
	crumbled = -1
	crumble = 0.0
	choice_stones = []
	keys = []
	turned_key = -1
	sticker = ""
	gate = "closed" if kind == "door" else ""
	gate_lift = 0.0
	chest = "closed" if kind == "chest" else ""
	chest_shake = 0.0
	max_stone = run.grade["max_choice"] if kind == "path" else ROW_LEN
	for d in dice:
		d.visible = false
		d.numeral_alpha = 0.0
	bubble = ""


func _wait_for_roll() -> void:
	tray_waiting = true
	tray_gate.present(Time.get_ticks_msec())
	await rolled
	tray_waiting = false
	tray_gate.close()


func _roll_dice(values: Array) -> void:
	Beeper.roll()
	var centers := [Vector2(424, 482)] if values.size() == 1 else [Vector2(344, 482), Vector2(504, 482)]
	for i in values.size():
		var d: DieView = dice[i]
		d.position = centers[i]
		d.roll_to(values[i], 0.12 * i)
	while true:
		await get_tree().process_frame
		var all_on := true
		for i in values.size():
			all_on = all_on and dice[i].face_on
		if all_on:
			break
	for i in values.size():
		dice[i].countable = true


func _present_choices(p: Dictionary) -> void:
	var rects := []
	if p["kind"] == "path":
		choice_stones = p["choices"]
		for d in choice_stones:
			rects.append(Rect2(_stone_pos(d) - Vector2(36, 36), Vector2(72, 72)))
		_ask("Where?")
	else:
		keys = p["choices"]
		for i in keys.size():
			rects.append(_key_rect(i))
		_ask("Key?")
	choice.present(rects)


func _play_outcome(p: Dictionary, pick: int, out: Dictionary) -> void:
	match out["result"]:
		"hop":
			await _hop_to(p["choices"][pick], true)
			_cheer("Yes!")
			await _wait(0.6)
		"fall":
			await _hop_to(p["choices"][pick], false)
			await _fall()
			await _restart()
		"door_open":
			turned_key = pick
			_cheer("Yes!")
			await _tween_prop("gate_lift", 1.0, 0.6)
			await _walk_to(_stone_pos(ROW_LEN))
		"trap":
			turned_key = pick
			await _wait(0.4)
			await _fall()
			await _restart()
		"chest_open":
			chest = "open"
			sticker = out["sticker"]
			SaveData.add_sticker(save, sticker)
			_cheer("Yes!")
			await _wait(1.2)
			await _walk_to(_stone_pos(ROW_LEN))
		"chest_shut":
			chest = "shut"
			Beeper.bad()
			await _tween_prop("chest_shake", 1.0, 0.5)
			await _walk_to(_stone_pos(ROW_LEN))
		"mimic":
			# Right or wrong, the lid snaps open and the fight starts.
			chest = "mimic"
			Beeper.bad()
			await _tween_prop("chest_shake", 1.0, 0.4)
			await _fight(out["first_strike"])


## A fight task or a mimic: the fight screen covers the path until it ends,
## then the run moves on or, on a loss, the area starts again. The fight
## draws from run.rng, so replays stay seeded.
func _fight(first_strike: bool) -> void:
	_ask("")
	var f := FightScreen.new()
	f.setup(run.rng, run.grade["id"], run.current_monster(), first_strike, false, debug_on)
	await _fade_to(1.0)
	add_child(f)
	await _fade_to(0.0)
	var won: bool = await f.done
	debug_on = f.debug_on
	await _fade_to(1.0)
	f.queue_free()
	# A win leaves the screen dark for the loop to fade in the next task.
	if run.resolve_fight(won)["restarted"]:
		await _restart()


func _save_progress() -> void:
	if run.phase == AreaRun.CLEARED:
		SaveData.add_mark(save, run.area["id"], run.grade["id"])
		save["run"] = null
	else:
		save["run"] = run.to_save()
	SaveStore.write(save)


func _area_cleared() -> void:
	cleared_banner = true
	_cheer("Yes!")
	await _wait(0.4)
	_cheer("Yes!")
	_ask("Map")
	choice.present([Rect2(400, 300, 160, 90)])
	await choice.picked


# --- animations ------------------------------------------------------------

## The hero hops stone by stone while each hop is counted. A wrong rock
## crumbles under the last hop.
func _hop_to(dist: int, lands: bool) -> void:
	for i in range(1, dist + 1):
		var a := hero_pos
		var b := _stone_pos(i)
		var arc := func(t: float) -> void:
			hero_pos = a.lerp(b, t) + Vector2(0, -sin(t * PI) * 42.0)
		await create_tween().tween_method(arc, 0.0, 1.0, HOP_S).finished
		hero_pos = b
		Beeper.count(i)
		_say(str(i))
		if i == dist and not lands:
			crumbled = i
			await _tween_prop("crumble", 1.0, 0.3)


func _fall() -> void:
	Beeper.bad()
	_say("Oops!")
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "hero_drop", 110.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "hero_alpha", 0.0, 0.6)
	await tw.finished
	await _wait(0.5)


## The fail rule's restart: back to the first task of the area.
func _restart() -> void:
	await _fade_to(1.0)
	_layout_task()
	_say("Again!")
	await _fade_to(0.0)
	await _wait(0.6)


func _walk_to(target: Vector2) -> void:
	await create_tween().tween_property(self, "hero_pos", target, 0.7).finished


func _fade_to(alpha: float) -> void:
	await _tween_prop("fade", alpha, 0.25)


func _tween_prop(prop: String, to: float, dur: float) -> void:
	await create_tween().tween_property(self, prop, to, dur).finished


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


# --- Elfwynn ---------------------------------------------------------------

func _ask(q: String) -> void:
	question = q
	_say(q)


func _say(text: String) -> void:
	bubble = text


func _cheer(text: String) -> void:
	_say(text)
	Beeper.good()
	elf_hop = 1.0
	create_tween().tween_property(self, "elf_hop", 0.0, 0.6)


## Tap Elfwynn or press Y: she repeats the question, never the answer.
func _repeat_question() -> void:
	if question == "":
		return
	_say(question)
	Beeper.tone(880.0, 0.08)
	elf_hop = 0.5
	create_tween().tween_property(self, "elf_hop", 0.0, 0.4)


func _on_pip_tapped(count: int) -> void:
	Beeper.count(count)
	_say(str(count))


# --- input -----------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if tray_waiting and Input.is_action_just_pressed("pick") and tray_gate.accepts(Time.get_ticks_msec()):
		rolled.emit()
	if Input.is_action_just_pressed("repeat"):
		_repeat_question()
	if Input.is_action_just_pressed("debug"):
		debug_on = not debug_on
	if _corner_down_ms >= 0 and Time.get_ticks_msec() - _corner_down_ms > 1500:
		_corner_down_ms = -1
		debug_on = not debug_on
	queue_redraw()
	overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var press := Pointer.is_press(event)
	var release := Pointer.is_release(event)
	var drag := Pointer.is_drag(event)
	if not (press or release or drag):
		return
	var pos := Pointer.local_pos(self, event)
	if drag:
		if _tray_down and pos.distance_to(_tray_down_at) >= FLICK_PX:
			_tray_down = false
			rolled.emit()
		return
	if press:
		if tray_waiting and TRAY.has_point(pos) and tray_gate.accepts(Time.get_ticks_msec()):
			_tray_down = true
			_tray_down_at = pos
		elif ELF.has_point(pos):
			_repeat_question()
		elif DEBUG_CORNER.has_point(pos):
			_corner_down_ms = Time.get_ticks_msec()
	else:
		if _tray_down and ROLL_ON_TAP and tray_waiting:
			_tray_down = false
			rolled.emit()
		_tray_down = false
		_corner_down_ms = -1


# --- layout helpers --------------------------------------------------------

## Stone i of the path (0 is where the hero stands). Rows of 7 snake back,
## so 14 stones fit with 85 px between 64 px targets.
func _stone_pos(i: int) -> Vector2:
	if i <= ROW_LEN:
		return START + Vector2(STEP * i, 0)
	return Vector2(START.x + STEP * (2 * ROW_LEN + 1 - i), ROW2_Y)


func _key_rect(i: int) -> Rect2:
	var cx := 480.0 + (i - (keys.size() - 1) / 2.0) * 150.0
	return Rect2(Vector2(cx, KEY_Y) - KEY_SIZE / 2.0, KEY_SIZE)


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.13, 0.09, 0.08))
	var glow := 0.06 * sin(_t * 2.0)
	draw_rect(Rect2(-480, 195, 1920, 228), LAVA.lightened(glow))
	draw_rect(Rect2(-480, 0, 1920, 70), Color(0.09, 0.06, 0.05))
	draw_rect(Rect2(90, START.y - 6, 120, 40), ROCK)
	# stones: flat counting stones, raised rocks for the choices
	for i in range(1, max_stone + 1):
		var c := _stone_pos(i)
		if choice_stones.has(i):
			var sink := crumble * 40.0 if i == crumbled else 0.0
			var col := ROCK_HI
			col.a = 1.0 - crumble if i == crumbled else 1.0
			draw_circle(c + Vector2(0, sink), 32.0, col)
			draw_arc(c + Vector2(0, sink), 32.0, 0, TAU, 32, Color(0.2, 0.17, 0.15, col.a), 3.0)
		else:
			draw_circle(c, 15.0, ROCK)
	# the gate across the path
	if gate != "":
		var top := 120.0 - gate_lift * 140.0
		for bx in [-16.0, 0.0, 16.0]:
			draw_rect(Rect2(GATE_X + bx - 4, top, 8, 180), Color(0.3, 0.3, 0.34))
		draw_rect(Rect2(GATE_X - 30, top + 60, 60, 46), Color(0.55, 0.45, 0.2))
		draw_circle(Vector2(GATE_X, top + 78), 7.0, Color(0.1, 0.1, 0.1))
		draw_rect(Rect2(GATE_X - 6, top + 80, 12, 16), Color(0.1, 0.1, 0.1))
	# the chest beside the path
	if chest != "":
		var shake := sin(chest_shake * TAU * 3.0) * 6.0 * (1.0 - chest_shake)
		var cpos := CHEST_POS + Vector2(shake, 0)
		var is_mimic: bool = run.current_task().get("mimic", false)
		draw_rect(Rect2(cpos - Vector2(45, 10), Vector2(90, 45)), Color(0.55, 0.33, 0.12))
		var lid := Rect2(cpos - Vector2(47, 34), Vector2(94, 26))
		if chest == "open":
			lid.position.y -= 26
			draw_string(font, cpos + Vector2(-90, -78), sticker, HORIZONTAL_ALIGNMENT_CENTER, 180, 22, INK)
			draw_circle(cpos + Vector2(0, -2), 14.0, Color(1.0, 0.85, 0.2))
		elif chest == "mimic":
			lid.position.y -= 30
		if is_mimic and chest == "closed":
			# A sharp eye can spot it: the lid twitches now and then.
			lid.position.y -= maxf(0.0, sin(_t * 1.7) - 0.93) * 60.0
		draw_rect(lid, Color(0.65, 0.4, 0.15))
		if is_mimic:
			# a tooth where the latch should be
			draw_colored_polygon(PackedVector2Array([cpos + Vector2(-7, -10), cpos + Vector2(7, -10), cpos + Vector2(0, 6)]),
					Color(1, 1, 0.9))
		else:
			draw_rect(Rect2(cpos - Vector2(7, 14), Vector2(14, 16)), Color(0.85, 0.75, 0.3))
		if run.phase == AreaRun.AWAIT_CHEST:
			draw_rect(GO_RECT, Color(0.25, 0.5, 0.3))
			draw_string(font, GO_RECT.position + Vector2(0, 58), "Go", HORIZONTAL_ALIGNMENT_CENTER, GO_RECT.size.x, 34, INK)
	# keys for doors and chests
	for i in keys.size():
		var r := _key_rect(i)
		var col := Color(0.85, 0.7, 0.25) if i != turned_key else Color(1.0, 0.9, 0.45)
		draw_rect(r, col)
		draw_rect(r, Color(0.35, 0.28, 0.1), false, 3.0)
		DiceDraw.draw_value(self, r.get_center(), 44.0, keys[i])
	# the hero: a simple slime
	_draw_hero(hero_pos + Vector2(0, hero_drop), hero_alpha)
	# dice tray
	draw_rect(TRAY, Color(0.2, 0.15, 0.13))
	if tray_waiting:
		var a := 0.5 + 0.5 * sin(_t * 5.0)
		draw_rect(TRAY.grow(3), Color(1.0, 0.92, 0.3, a), false, 4.0)
		draw_string(font, TRAY.position + Vector2(0, 64), "Roll", HORIZONTAL_ALIGNMENT_CENTER, TRAY.size.x, 36, INK)
	_draw_elfwynn(font)
	# progress: one pip per task
	var n := run.task_count()
	for i in n:
		var c := Vector2(140 + i * 26, 34)
		if i < run.task_index or run.phase == AreaRun.CLEARED:
			draw_circle(c, 9.0, Color(1.0, 0.8, 0.2))
		else:
			draw_arc(c, 9.0, 0, TAU, 20, INK if i == run.task_index else Color(0.5, 0.45, 0.4), 2.0)
	draw_string(font, Vector2(640, 44), run.grade["name"], HORIZONTAL_ALIGNMENT_RIGHT, 200, 26, INK)
	if cleared_banner:
		draw_string(font, Vector2(120, 170), "%s  %s" % [run.area["name"], run.grade["name"]],
				HORIZONTAL_ALIGNMENT_CENTER, 720, 40, Color(1.0, 0.85, 0.3))
		draw_string(font, Vector2(400, 360), "Map", HORIZONTAL_ALIGNMENT_CENTER, 160, 36, INK)


func _draw_hero(base: Vector2, alpha: float) -> void:
	var body := Color(0.35, 0.8, 0.35, alpha)
	var pts := PackedVector2Array()
	for s in 24:
		var a := TAU * s / 24.0
		var p := Vector2(cos(a) * 34.0, sin(a) * 50.0)
		if p.y > 0:
			p.y *= 0.4
		pts.append(base + Vector2(0, -24) + p)
	draw_colored_polygon(pts, body)
	draw_circle(base + Vector2(-11, -44), 7.0, Color(1, 1, 1, alpha))
	draw_circle(base + Vector2(11, -44), 7.0, Color(1, 1, 1, alpha))
	draw_circle(base + Vector2(-10, -43), 3.5, Color(0, 0, 0, alpha))
	draw_circle(base + Vector2(12, -43), 3.5, Color(0, 0, 0, alpha))


func _draw_elfwynn(font: Font) -> void:
	var c := ELF.get_center() + Vector2(0, -elf_hop * 18.0)
	draw_rect(ELF, Color(0.18, 0.28, 0.2))
	draw_circle(c + Vector2(0, -4), 34.0, Color(0.95, 0.85, 0.45))
	draw_circle(c + Vector2(-30, 24), 9.0, Color(0.95, 0.85, 0.45))
	draw_circle(c + Vector2(30, 24), 9.0, Color(0.95, 0.85, 0.45))
	draw_circle(c + Vector2(0, 4), 25.0, Color(1.0, 0.88, 0.78))
	draw_circle(c + Vector2(-9, 0), 4.0, Color(0.2, 0.45, 0.9))
	draw_circle(c + Vector2(9, 0), 4.0, Color(0.2, 0.45, 0.9))
	draw_circle(c + Vector2(-22, -26), 5.0, Color(0.95, 0.5, 0.7))
	if bubble != "":
		# beside Elfwynn, below the path rows and key row so it never covers a choice
		var b := Rect2(Vector2(ELF.position.x - 112, ELF.position.y + 22), Vector2(104, 52))
		draw_rect(b, INK)
		draw_string(font, b.position + Vector2(0, 35), bubble, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 24, Color(0.1, 0.1, 0.1))


func _draw_overlay() -> void:
	if fade > 0.0:
		overlay.draw_rect(Rect2(-480, -100, 1920, 740), Color(0, 0, 0, fade))
	if not debug_on:
		return
	var font := ThemeDB.fallback_font
	overlay.draw_line(Vector2(120, 0), Vector2(120, 540), Color(0, 1, 1, 0.5), 1.0)
	overlay.draw_line(Vector2(840, 0), Vector2(840, 540), Color(0, 1, 1, 0.5), 1.0)
	var lines := [
		"seed %d  attempt %d  task %d/%d %s  phase %s" % [run.run_seed, run.attempt, run.task_index + 1,
				run.task_count(), run.current_task().get("type", "-"), run.phase],
		"rng 0x%08x  grade %s" % [run.rng.get_state(), run.grade["name"]],
	]
	if run.has_problem():
		lines.append("dice %s  answer %d  choices %s" % [str(run.problem["dice"]), run.problem["answer"],
				str(run.problem["choices"])])
	for i in lines.size():
		overlay.draw_rect(Rect2(124, 72 + i * 20, 712, 20), Color(0, 0, 0, 0.7))
		overlay.draw_string(font, Vector2(128, 87 + i * 20), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 1, 0.6))
