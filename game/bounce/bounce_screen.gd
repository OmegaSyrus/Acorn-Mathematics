## The Match Bounce graybox: one boss fight on one board with placeholder
## shapes. Drives BounceFight (all rules live there) and only animates what
## it returns. Drawn in the 960x540 design space; everything the child
## touches sits inside the 4:3 safe area, x 120..840.
##
## One shot: tap the peg face that matches the boss's number (left column),
## then touch the board and drag to aim; let go to fire. A short stub shows
## the direction only. The flight steps the logic at a fixed 120 Hz.
## Controller: d-pad names, left/right aims, A fires.
extends Node2D

signal done(won: bool)

const BounceFight := preload("res://logic/bounce/bounce_fight.gd")
const BounceSim := preload("res://logic/bounce/bounce_sim.gd")
const ChoiceWidget := preload("res://game/ui/choice_widget.gd")
const DiceDraw := preload("res://game/ui/dice_draw.gd")
const Pointer := preload("res://game/ui/pointer.gd")

## Peg colours by face. Acorn uses 1 to 3; the colour helps the eye, the
## count is the answer.
const FACE_COLORS := {
	1: Color(0.25, 0.55, 0.95),
	2: Color(0.3, 0.8, 0.35),
	3: Color(0.98, 0.6, 0.15),
	4: Color(0.85, 0.3, 0.75),
	5: Color(0.95, 0.85, 0.2),
	6: Color(0.4, 0.85, 0.9),
}
const INK := Color(0.96, 0.94, 0.9)
const WALL := Color(0.55, 0.42, 0.35)
const BUMPER := Color(0.6, 0.25, 0.15)
const MOD := Color(0.55, 0.35, 0.9)
const HEART := Color(0.9, 0.15, 0.2)
const HEART_EMPTY := Color(0.35, 0.25, 0.25)

const CHOICE_X := 172.0
const CHOICE_SIZE := 76.0
const CHOICE_GAP := 96.0
const BOSS_POS := Vector2(840, 150)
const STUB_LENGTH := 70.0
const AIM_KEY_SPEED := 600.0   # tenths of a degree per second
const SLOW_MO := 0.25
const FIRST_FACE_Y := 150.0

var fight
var debug_on := false
var choice: ChoiceWidget

var phase := "naming"   # naming, aiming, flying, won, lost
var aim := 0
var aiming_touch := false
var _acc := 0.0
var slow := false
var _t := 0.0
var bubble := ""
var bubble_t := 0.0
var boss_flash := 0.0
var wobble := {}        # peg index -> seconds left
var pop_rings := []     # [pos, color, age]
var pop_count := 0
var fail_buttons: Array[Rect2] = []


func setup(rng, grade: int, show_debug := false) -> void:
	fight = BounceFight.new(rng, grade)
	debug_on = show_debug


func _ready() -> void:
	choice = ChoiceWidget.new()
	add_child(choice)
	choice.picked.connect(_on_named)
	_start_naming()


func _start_naming() -> void:
	phase = "naming"
	aim = 0
	pop_count = 0
	if fight.refills > 0 and fight.shot_count > 0 and _all_pegs_back():
		_say("New pegs!")
	choice.present(_choice_rects())


func _all_pegs_back() -> bool:
	return not fight.peg_alive.has(false)


func _on_named(index: int) -> void:
	fight.name_peg(index)
	Beeper.count(fight.named_face)
	phase = "aiming"


func _fire() -> void:
	phase = "flying"
	aiming_touch = false
	fight.fire(aim)
	_acc = 0.0
	slow = false
	if not fight.named_right:
		_say("Ha ha!")


func _on_shot_over() -> void:
	var out: Dictionary = fight.end_shot()
	slow = false
	if out["state"] == BounceFight.State.WON:
		phase = "won"
		_say("You win!")
		Beeper.good()
		await get_tree().create_timer(2.5).timeout
		done.emit(true)
		return
	if out["state"] == BounceFight.State.LOST:
		phase = "lost"
		Beeper.bad()
		return
	if out["damage"] == 0 and fight.named_right:
		_say("Oh no!")
	_start_naming()


# --- input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if phase == "lost":
		if Pointer.is_press(event):
			var p := Pointer.local_pos(self, event)
			if fail_buttons.size() == 2 and fail_buttons[0].has_point(p):
				done.emit(false)   # Try: the owner starts the fight again
			elif fail_buttons.size() == 2 and fail_buttons[1].has_point(p):
				done.emit(false)   # Map: no map in this graybox yet
		return
	if phase != "aiming":
		return
	if Pointer.is_press(event):
		var p := Pointer.local_pos(self, event)
		if _board_rect().has_point(p):
			aiming_touch = true
			_aim_at(p)
	elif Pointer.is_drag(event) and aiming_touch:
		_aim_at(Pointer.local_pos(self, event))
	elif Pointer.is_release(event) and aiming_touch:
		_fire()


func _aim_at(p: Vector2) -> void:
	var d := p - BounceSim.launcher(fight.board)
	if d.y < 1.0:
		d.y = 1.0
	aim = BounceSim.clamp_aim(roundi(rad_to_deg(atan2(d.x, d.y)) * 10.0), fight.phys)


func _process(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("debug"):
		debug_on = not debug_on
	boss_flash = maxf(0.0, boss_flash - delta * 3.0)
	bubble_t = maxf(0.0, bubble_t - delta)
	for k in wobble.keys():
		wobble[k] -= delta
		if wobble[k] <= 0.0:
			wobble.erase(k)
	for r in pop_rings:
		r[2] += delta
	pop_rings = pop_rings.filter(func(r): return r[2] < 0.5)
	if phase == "aiming":
		var dir := Input.get_axis("move_left", "move_right")
		if absf(dir) > 0.0:
			aim = BounceSim.clamp_aim(aim - roundi(dir * AIM_KEY_SPEED * delta), fight.phys)
		if Input.is_action_just_pressed("pick"):
			_fire()
	elif phase == "flying":
		_fly(delta)
	queue_redraw()


## Steps the logic at its fixed rate. Real time only decides how many steps
## run this frame, so the flight is the same at any frame rate.
func _fly(delta: float) -> void:
	var dt: float = fight.phys["dt"]
	_acc += delta * (SLOW_MO if slow else 1.0)
	while _acc >= dt and fight.sim.ended == BounceSim.End.NONE:
		_acc -= dt
		for e in fight.sim.step():
			_on_event(e)
	if fight.sim.ended != BounceSim.End.NONE:
		phase = "settling"
		await get_tree().create_timer(0.5).timeout
		_on_shot_over()


func _on_event(e: Dictionary) -> void:
	match e["type"]:
		"pop":
			var p: Dictionary = fight.board["pegs"][e["peg"]]
			pop_rings.append([Vector2(p["x"], p["y"]), FACE_COLORS.get(int(p["face"]), INK), 0.0])
			pop_count += 1
			Beeper.count(pop_count + 2)
			boss_flash = 1.0
			if e["damage"] > 1:
				_say("Combo!")
			if not slow and fight.is_lethal():
				# The last heart: time slows and the pop lands with a fanfare.
				slow = true
		"whiff":
			wobble[e["peg"]] = 0.35
			Beeper.tone(150.0, 0.04, -20.0)
		"mod":
			Beeper.tone(880.0, 0.1)
		"bounce":
			Beeper.tone(300.0, 0.03, -22.0)


func _say(text: String) -> void:
	bubble = text
	bubble_t = 1.4


# --- layout ----------------------------------------------------------------

func _choice_rects() -> Array:
	var out := []
	var n: int = fight.choices.size()
	for i in n:
		var c := Vector2(CHOICE_X, FIRST_FACE_Y + CHOICE_GAP * i)
		out.append(Rect2(c - Vector2(CHOICE_SIZE, CHOICE_SIZE) / 2.0, Vector2(CHOICE_SIZE, CHOICE_SIZE)))
	return out


func _board_rect() -> Rect2:
	return Rect2(230, 40, 500, 500)


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0.1, 0.06, 0.05))
	draw_rect(_board_rect(), Color(0.16, 0.09, 0.07))
	var b: Dictionary = fight.board
	for w in b["walls"]:
		draw_line(Vector2(w[0], w[1]), Vector2(w[2], w[3]), WALL, 6.0)
	for bm in b["bumpers"]:
		draw_circle(Vector2(bm["x"], bm["y"]), bm["r"], BUMPER)
		draw_arc(Vector2(bm["x"], bm["y"]), bm["r"], 0, TAU, 24, Color(1, 0.6, 0.3), 3.0)
	_draw_pegs(font)
	for r in pop_rings:
		var k: float = r[2] / 0.5
		draw_arc(r[0], 20.0 + 30.0 * k, 0, TAU, 24, Color(r[1], 1.0 - k), 5.0)
	_draw_launcher(font)
	_draw_ball()
	_draw_boss(font)
	_draw_balls_left()
	_draw_choices(font)
	if bubble_t > 0.0:
		var br := Rect2(BOSS_POS + Vector2(-150, 150), Vector2(140, 40))
		draw_rect(br, INK)
		draw_string(font, br.position + Vector2(0, 29), bubble, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 24, Color(0.1, 0.1, 0.1))
	if phase == "lost":
		_draw_fail(font)
	if debug_on:
		var line := "target %d ball %d answer %d named %d live %d hearts %d balls %d refills %d aim %d" % [
			fight.target, fight.ball_value, fight.answer_face, fight.named_face, fight.live_count(),
			fight.boss_hearts, fight.balls_left, fight.refills, aim]
		draw_rect(Rect2(124, 4, 712, 20), Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(128, 19), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 1, 0.6))


func _peg_alive(i: int) -> bool:
	if phase in ["flying", "settling"] and fight.sim != null:
		return fight.sim.peg_alive[i]
	return fight.peg_alive[i]


func _draw_pegs(font: Font) -> void:
	var b: Dictionary = fight.board
	var r: float = b["peg_radius"]
	for i in b["pegs"].size():
		if not _peg_alive(i):
			continue
		var p: Dictionary = b["pegs"][i]
		var c := Vector2(p["x"], p["y"])
		if wobble.has(i):
			c.x += sin(wobble[i] * 60.0) * 4.0
		var face := int(p["face"])
		var col: Color = FACE_COLORS.get(face, INK)
		if wobble.has(i):
			col = col.darkened(0.4)
		draw_circle(c, r, col)
		draw_arc(c, r, 0, TAU, 24, Color(0, 0, 0, 0.5), 2.0)
		DiceDraw.draw_face(self, c, r * 1.4, face)
		if debug_on and phase == "naming" and face == fight.answer_face:
			draw_arc(c, r + 5, 0, TAU, 24, Color(0.6, 1, 0.6), 2.0)
	for i in b["mods"].size():
		var m: Dictionary = b["mods"][i]
		var c := Vector2(m["x"], m["y"])
		var used: bool = phase in ["flying", "settling"] and fight.sim != null and fight.sim.mod_used[i]
		draw_circle(c, r, MOD.lightened(0.3) if used else MOD)
		var label := "+%d" % m["add"] if int(m["add"]) > 0 else str(m["add"])
		draw_string(font, c + Vector2(-r, 8), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 22, INK)


func _draw_launcher(font: Font) -> void:
	var l := BounceSim.launcher(fight.board)
	draw_circle(l, 22.0, Color(0.35, 0.3, 0.28))
	if phase == "aiming":
		var dir := BounceSim.aim_dir(aim, fight.phys)
		# The fixed stub: the same length every time, never reaching a peg.
		draw_line(l + dir * 24.0, l + dir * (24.0 + STUB_LENGTH), Color(1, 0.95, 0.6, 0.8), 6.0)


func _draw_ball() -> void:
	var r: float = fight.phys["ball_radius"]
	var at := BounceSim.launcher(fight.board)
	var value: int = fight.ball_value
	if phase in ["flying", "settling"] and fight.sim != null:
		at = fight.sim.pos
		value = fight.sim.ball_value
	if phase in ["naming", "aiming", "flying", "settling"]:
		var col := INK
		if fight.named_face > 0:
			col = FACE_COLORS.get(fight.named_face, INK).lightened(0.3)
		if value > 0:
			# The ball's own die, big enough to read while it flies.
			draw_circle(at, r + 3, col)
			DiceDraw.draw_face(self, at, r * 1.5, value)
		else:
			draw_circle(at, r, col)


func _draw_boss(font: Font) -> void:
	var col := Color(0.55, 0.5, 0.45).lerp(Color.WHITE, boss_flash * 0.7)
	var body := Rect2(BOSS_POS - Vector2(90, 100), Vector2(180, 120))
	draw_rect(body, col)
	draw_rect(body, Color(0.1, 0.05, 0.05), false, 3.0)
	draw_string(font, body.position + Vector2(0, -8), "Skeleton Dragon", HORIZONTAL_ALIGNMENT_CENTER, body.size.x, 16, INK)
	# The target die, spat out of the jaw.
	DiceDraw.draw_value(self, BOSS_POS + Vector2(-50, 64), 64.0, fight.target)
	# Hearts in rows of five, inside the safe area.
	for i in fight.boss_max_hearts:
		var c := Vector2(770 + (i % 5) * 14, 300 + (i / 5) * 16)
		draw_circle(c, 6.0, HEART if i < fight.boss_hearts else HEART_EMPTY)


func _draw_balls_left() -> void:
	var shown: int = fight.balls_left - (1 if phase in ["flying", "settling"] else 0)
	for i in maxi(0, shown):
		draw_circle(Vector2(768 + (i % 4) * 22, 360 + (i / 4) * 22), 8.0, INK)


func _draw_choices(font: Font) -> void:
	var rects := _choice_rects()
	for i in rects.size():
		var rr: Rect2 = rects[i]
		var face: int = fight.choices[i]
		var lit: bool = phase != "naming" and face == fight.named_face
		var col: Color = FACE_COLORS.get(face, INK)
		if phase != "naming" and not lit:
			col = col.darkened(0.6)
		draw_circle(rr.get_center(), CHOICE_SIZE / 2.0, col)
		DiceDraw.draw_face(self, rr.get_center(), CHOICE_SIZE * 0.6, face)
	if phase == "naming":
		draw_string(font, Vector2(124, 100), "Pick", HORIZONTAL_ALIGNMENT_CENTER, 96, 26, INK)


func _draw_fail(font: Font) -> void:
	draw_rect(Rect2(-480, -100, 1920, 740), Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(120, 220), "No more balls", HORIZONTAL_ALIGNMENT_CENTER, 720, 40, INK)
	fail_buttons = [Rect2(300, 280, 160, 90), Rect2(500, 280, 160, 90)]
	var labels := ["Try", "Map"]
	for i in 2:
		draw_rect(fail_buttons[i], Color(0.3, 0.6, 0.3) if i == 0 else Color(0.4, 0.4, 0.5))
		draw_string(font, fail_buttons[i].position + Vector2(0, 58), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 160, 36, INK)
